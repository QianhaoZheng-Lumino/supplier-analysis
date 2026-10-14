WITH self_chain AS (
    SELECT chain, sum(pricecny) AS self_ttv
    FROM data_ovs.supplier_analysis_order
    WHERE supplierid = {supplier_id}
      AND createtime >= '{start}'
      AND createtime < '{end}'
      AND chain <> 'Independent'
    GROUP BY 1
    ORDER BY self_ttv DESC, chain
    LIMIT 10
),
scoped AS (
    SELECT o.chain, o.supplierid, o.suppliername, o.pricecny
    FROM data_ovs.supplier_analysis_order o
    JOIN self_chain c ON c.chain = o.chain
    WHERE o.createtime >= '{start}'
      AND o.createtime < '{end}'
),
market_chain AS (
    SELECT chain, sum(pricecny) AS market_ttv
    FROM scoped
    GROUP BY 1
),
chain_other AS (
    SELECT chain,
           supplierid,
           max(suppliername) AS suppliername,
           round(sum(pricecny)) AS other_ttv,
           row_number() OVER (
               PARTITION BY chain
               ORDER BY round(sum(pricecny)) DESC, supplierid
           ) AS rn
    FROM scoped
    WHERE supplierid <> {supplier_id}
    GROUP BY chain, supplierid
),
assembled AS (
SELECT 'chain' AS section,
       c.chain,
       CAST(NULL AS bigint) AS supplierid,
       CAST(NULL AS text) AS suppliername,
       round(c.self_ttv) AS self_ttv,
       round(k.market_ttv) AS market_ttv,
       CAST(NULL AS numeric) AS other_ttv,
       row_number() OVER (ORDER BY c.self_ttv DESC, c.chain) AS rn
FROM self_chain c
JOIN market_chain k ON k.chain = c.chain
UNION ALL
SELECT 'chain_other',
       o.chain,
       o.supplierid,
       o.suppliername,
       CAST(NULL AS numeric),
       round(k.market_ttv),
       o.other_ttv,
       o.rn
FROM chain_other o
JOIN market_chain k ON k.chain = o.chain
WHERE o.rn <= 5
),
keep_chain AS (
    SELECT chain
    FROM assembled
    WHERE section = 'chain'
      AND self_ttv::numeric / nullif(market_ttv, 0) >= {share_threshold}
)
SELECT a.*
FROM assembled a
JOIN keep_chain k ON k.chain = a.chain
ORDER BY 1, 2, 8
