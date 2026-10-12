WITH mine AS (
    SELECT chain, sum(pricecny) AS self_ttv
    FROM data_ovs.supplier_analysis_order
    WHERE supplierid = {supplier_id}
      AND createtime >= '{start}'
      AND createtime < '{end}'
      AND chain <> 'Independent'
    GROUP BY 1
    ORDER BY self_ttv DESC
    LIMIT 10
),
market AS (
    SELECT o.chain, sum(o.pricecny) AS market_ttv
    FROM data_ovs.supplier_analysis_order o
    JOIN mine m ON m.chain = o.chain
    WHERE o.createtime >= '{start}'
      AND o.createtime < '{end}'
    GROUP BY 1
)
SELECT m.chain,
       round(m.self_ttv) AS self_ttv,
       round(k.market_ttv) AS market_ttv
FROM mine m
JOIN market k ON k.chain = m.chain
ORDER BY m.self_ttv DESC
