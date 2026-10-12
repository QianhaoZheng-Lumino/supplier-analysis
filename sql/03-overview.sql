SELECT count(*) AS bks,
       count(DISTINCT didahotelid) AS hotels,
       round(sum(pricecny)) AS ttv_cny,
       round(sum(pricecny) / nullif(count(*), 0)) AS adr_cny
FROM data_ovs.supplier_analysis_order
WHERE supplierid = {supplier_id}
  AND createtime >= '{start}'
  AND createtime < '{end}'
