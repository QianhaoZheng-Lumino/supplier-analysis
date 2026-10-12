SELECT supplierid,
       max(suppliername) AS suppliername,
       round(sum(pricecny)) AS ttv_cny
FROM data_ovs.supplier_analysis_order
WHERE createtime >= '{start}'
  AND createtime < '{end}'
  AND chain = '{chain}'
  AND chain <> 'Independent'
  AND supplierid <> {supplier_id}
GROUP BY 1
ORDER BY ttv_cny DESC
LIMIT 5
