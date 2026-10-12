SELECT star_rating,
       count(DISTINCT didahotelid) AS hotels,
       count(*) AS bks,
       round(sum(pricecny)) AS ttv_cny,
       round(sum(pricecny) / nullif(count(*), 0)) AS adr_cny
FROM data_ovs.supplier_analysis_order
WHERE supplierid = {supplier_id}
  AND createtime >= '{start}'
  AND createtime < '{end}'
GROUP BY 1
ORDER BY CASE star_rating
           WHEN '5' THEN 1 WHEN '4' THEN 2 WHEN '3' THEN 3
           WHEN '2' THEN 4 WHEN '1' THEN 5 ELSE 6 END
