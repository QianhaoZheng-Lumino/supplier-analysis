WITH base AS (
    SELECT chain,
           star_rating,
           country_code,
           destinationname_en,
           coalesce(mealtype, '(空)') AS mealtype,
           los_range,
           lt_range,
           didahotelid,
           pricecny
    FROM data_ovs.supplier_analysis_order
    WHERE supplierid = {supplier_id}
      AND createtime >= '{start}'
      AND createtime < '{end}'
),
chain_rows AS (
    SELECT chain AS dim,
           count(DISTINCT didahotelid) AS hotels,
           count(*) AS bks,
           round(sum(pricecny)) AS ttv_cny,
           round(sum(pricecny) / nullif(count(*), 0)) AS adr_cny,
           row_number() OVER (ORDER BY round(sum(pricecny)) DESC, chain) AS rn
    FROM base
    GROUP BY chain
),
star_rows AS (
    SELECT star_rating::text AS dim,
           count(DISTINCT didahotelid) AS hotels,
           count(*) AS bks,
           round(sum(pricecny)) AS ttv_cny,
           round(sum(pricecny) / nullif(count(*), 0)) AS adr_cny,
           row_number() OVER (
               ORDER BY CASE star_rating
                          WHEN '5' THEN 1 WHEN '4' THEN 2 WHEN '3' THEN 3
                          WHEN '2' THEN 4 WHEN '1' THEN 5 ELSE 6 END,
                        star_rating
           ) AS rn
    FROM base
    GROUP BY star_rating
),
country_rows AS (
    SELECT country_code AS dim,
           count(DISTINCT didahotelid) AS hotels,
           count(*) AS bks,
           round(sum(pricecny)) AS ttv_cny,
           round(sum(pricecny) / nullif(count(*), 0)) AS adr_cny,
           row_number() OVER (ORDER BY round(sum(pricecny)) DESC, country_code) AS rn
    FROM base
    GROUP BY country_code
),
city_rows AS (
    SELECT destinationname_en AS dim,
           count(DISTINCT didahotelid) AS hotels,
           count(*) AS bks,
           round(sum(pricecny)) AS ttv_cny,
           round(sum(pricecny) / nullif(count(*), 0)) AS adr_cny,
           row_number() OVER (ORDER BY round(sum(pricecny)) DESC, destinationname_en) AS rn
    FROM base
    GROUP BY destinationname_en
),
meal_rows AS (
    SELECT mealtype AS dim,
           count(*) AS bks,
           round(sum(pricecny)) AS ttv_cny,
           round(sum(pricecny) / nullif(count(*), 0)) AS adr_cny,
           row_number() OVER (ORDER BY round(sum(pricecny)) DESC, mealtype) AS rn
    FROM base
    GROUP BY mealtype
),
los_rows AS (
    SELECT los_range AS dim,
           count(*) AS bks,
           round(sum(pricecny)) AS ttv_cny,
           row_number() OVER (ORDER BY round(sum(pricecny)) DESC, los_range) AS rn
    FROM base
    GROUP BY los_range
),
lt_rows AS (
    SELECT lt_range AS dim,
           count(*) AS bks,
           round(sum(pricecny)) AS ttv_cny,
           row_number() OVER (ORDER BY round(sum(pricecny)) DESC, lt_range) AS rn
    FROM base
    GROUP BY lt_range
)
SELECT 'overview' AS section,
       1 AS rn,
       CAST(NULL AS text) AS dim,
       count(DISTINCT didahotelid) AS hotels,
       count(*) AS bks,
       round(sum(pricecny)) AS ttv_cny,
       round(sum(pricecny) / nullif(count(*), 0)) AS adr_cny
FROM base
UNION ALL
SELECT 'chain', rn, dim, hotels, bks, ttv_cny, adr_cny
FROM chain_rows
WHERE rn <= 200
UNION ALL
SELECT 'star', rn, dim, hotels, bks, ttv_cny, adr_cny
FROM star_rows
UNION ALL
SELECT 'country', rn, dim, hotels, bks, ttv_cny, adr_cny
FROM country_rows
WHERE rn <= 100
UNION ALL
SELECT 'city', rn, dim, hotels, bks, ttv_cny, adr_cny
FROM city_rows
WHERE rn <= 500
UNION ALL
SELECT 'meal', rn, dim, CAST(NULL AS bigint), bks, ttv_cny, adr_cny
FROM meal_rows
UNION ALL
SELECT 'los', rn, dim, CAST(NULL AS bigint), bks, ttv_cny, CAST(NULL AS numeric)
FROM los_rows
UNION ALL
SELECT 'lt', rn, dim, CAST(NULL AS bigint), bks, ttv_cny, CAST(NULL AS numeric)
FROM lt_rows
ORDER BY 1, 2
