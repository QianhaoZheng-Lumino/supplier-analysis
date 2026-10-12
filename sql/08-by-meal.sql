SELECT coalesce(mealtype, '(空)') AS mealtype,
       count(*) AS bks,
       round(sum(pricecny)) AS ttv_cny,
       round(sum(pricecny) / nullif(count(*), 0)) AS adr_cny
FROM data_ovs.supplier_analysis_order
WHERE supplierid = {supplier_id}
  AND createtime >= '{start}'
  AND createtime < '{end}'
GROUP BY 1
ORDER BY ttv_cny DESC
