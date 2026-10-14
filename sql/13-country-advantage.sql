WITH self_country AS (
    SELECT country_code, sum(pricecny) AS self_ttv
    FROM data_ovs.supplier_analysis_order
    WHERE supplierid = {supplier_id}
      AND createtime >= '{start}'
      AND createtime < '{end}'
      AND country_code IS NOT NULL
      AND country_code <> ''
    GROUP BY 1
    ORDER BY self_ttv DESC, country_code
    LIMIT 10
),
scoped AS (
    SELECT o.country_code, o.chain, o.supplierid, o.suppliername, o.pricecny
    FROM data_ovs.supplier_analysis_order o
    JOIN self_country c ON c.country_code = o.country_code
    WHERE o.createtime >= '{start}'
      AND o.createtime < '{end}'
),
market_country AS (
    SELECT country_code, sum(pricecny) AS market_ttv
    FROM scoped
    GROUP BY 1
),
country_other AS (
    SELECT country_code,
           supplierid,
           max(suppliername) AS suppliername,
           round(sum(pricecny)) AS other_ttv,
           row_number() OVER (
               PARTITION BY country_code
               ORDER BY round(sum(pricecny)) DESC, supplierid
           ) AS rn
    FROM scoped
    WHERE supplierid <> {supplier_id}
    GROUP BY country_code, supplierid
),
self_country_chain AS (
    SELECT country_code,
           chain,
           sum(pricecny) AS self_ttv,
           row_number() OVER (
               PARTITION BY country_code
               ORDER BY sum(pricecny) DESC, chain
           ) AS rn
    FROM scoped
    WHERE supplierid = {supplier_id}
      AND chain <> 'Independent'
    GROUP BY country_code, chain
),
top_country_chain AS (
    SELECT country_code, chain, self_ttv, rn
    FROM self_country_chain
    WHERE rn <= 5
),
market_country_chain AS (
    SELECT s.country_code, s.chain, sum(s.pricecny) AS market_ttv
    FROM scoped s
    JOIN top_country_chain t
      ON t.country_code = s.country_code
     AND t.chain = s.chain
    GROUP BY s.country_code, s.chain
),
country_chain_other AS (
    SELECT s.country_code,
           s.chain,
           s.supplierid,
           max(s.suppliername) AS suppliername,
           round(sum(s.pricecny)) AS other_ttv,
           row_number() OVER (
               PARTITION BY s.country_code, s.chain
               ORDER BY round(sum(s.pricecny)) DESC, s.supplierid
           ) AS rn
    FROM scoped s
    JOIN top_country_chain t
      ON t.country_code = s.country_code
     AND t.chain = s.chain
    WHERE s.supplierid <> {supplier_id}
      AND s.chain <> 'Independent'
    GROUP BY s.country_code, s.chain, s.supplierid
),
assembled AS (
SELECT 'country' AS section,
       c.country_code,
       CAST(NULL AS text) AS chain,
       CAST(NULL AS bigint) AS supplierid,
       CAST(NULL AS text) AS suppliername,
       round(c.self_ttv) AS self_ttv,
       round(k.market_ttv) AS market_ttv,
       CAST(NULL AS numeric) AS other_ttv,
       row_number() OVER (ORDER BY c.self_ttv DESC, c.country_code) AS rn
FROM self_country c
JOIN market_country k ON k.country_code = c.country_code
UNION ALL
SELECT 'country_other',
       o.country_code,
       CAST(NULL AS text),
       o.supplierid,
       o.suppliername,
       CAST(NULL AS numeric),
       round(k.market_ttv),
       o.other_ttv,
       o.rn
FROM country_other o
JOIN market_country k ON k.country_code = o.country_code
WHERE o.rn <= 5
UNION ALL
SELECT 'country_chain',
       t.country_code,
       t.chain,
       CAST(NULL AS bigint),
       CAST(NULL AS text),
       round(t.self_ttv),
       round(k.market_ttv),
       CAST(NULL AS numeric),
       t.rn
FROM top_country_chain t
JOIN market_country_chain k
  ON k.country_code = t.country_code
 AND k.chain = t.chain
UNION ALL
SELECT 'country_chain_other',
       o.country_code,
       o.chain,
       o.supplierid,
       o.suppliername,
       CAST(NULL AS numeric),
       round(k.market_ttv),
       o.other_ttv,
       o.rn
FROM country_chain_other o
JOIN market_country_chain k
  ON k.country_code = o.country_code
 AND k.chain = o.chain
WHERE o.rn <= 5
),
keep_country AS (
    SELECT country_code
    FROM assembled
    WHERE section = 'country'
      AND self_ttv::numeric / nullif(market_ttv, 0) >= {share_threshold}
),
keep_country_chain AS (
    SELECT a.country_code, a.chain
    FROM assembled a
    JOIN keep_country c ON c.country_code = a.country_code
    WHERE a.section = 'country_chain'
      AND a.self_ttv::numeric / nullif(a.market_ttv, 0) >= {share_threshold}
)
SELECT a.*
FROM assembled a
JOIN keep_country c ON c.country_code = a.country_code
WHERE a.section IN ('country', 'country_other')
UNION ALL
SELECT a.*
FROM assembled a
JOIN keep_country_chain k
  ON k.country_code = a.country_code
 AND k.chain = a.chain
WHERE a.section IN ('country_chain', 'country_chain_other')
ORDER BY 1, 2, 3, 9
