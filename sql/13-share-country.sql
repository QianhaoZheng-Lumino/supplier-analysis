WITH mine AS (
    SELECT country_code, sum(pricecny) AS self_ttv
    FROM data_ovs.supplier_analysis_order
    WHERE supplierid = {supplier_id}
      AND createtime >= '{start}'
      AND createtime < '{end}'
      AND country_code IS NOT NULL
      AND country_code <> ''
    GROUP BY 1
    ORDER BY self_ttv DESC
    LIMIT 10
),
market AS (
    SELECT o.country_code, sum(o.pricecny) AS market_ttv
    FROM data_ovs.supplier_analysis_order o
    JOIN mine m ON m.country_code = o.country_code
    WHERE o.createtime >= '{start}'
      AND o.createtime < '{end}'
    GROUP BY 1
)
SELECT m.country_code,
       round(m.self_ttv) AS self_ttv,
       round(k.market_ttv) AS market_ttv
FROM mine m
JOIN market k ON k.country_code = m.country_code
ORDER BY m.self_ttv DESC
