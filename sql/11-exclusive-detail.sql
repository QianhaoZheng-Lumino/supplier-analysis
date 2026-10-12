WITH hotels AS (
    SELECT didahotelid
    FROM data_ovs.supplier_analysis_order
    WHERE supplierid = {supplier_id}
      AND createtime >= '{start}'
      AND createtime < '{end}'
    GROUP BY 1
),
scored AS (
    SELECT o.didahotelid,
           max(o.didahotelname_en) FILTER (WHERE o.supplierid = {supplier_id}) AS hotel_name,
           max(o.country_code) FILTER (WHERE o.supplierid = {supplier_id}) AS country_code,
           max(o.chain) FILTER (WHERE o.supplierid = {supplier_id}) AS chain,
           max(o.star_rating) FILTER (WHERE o.supplierid = {supplier_id}) AS star_rating,
           count(*) FILTER (WHERE o.supplierid = {supplier_id}) AS bks_self,
           count(DISTINCT o.supplierid) AS suppliers
    FROM data_ovs.supplier_analysis_order o
    JOIN hotels h ON h.didahotelid = o.didahotelid
    WHERE o.createtime >= '{start}'
      AND o.createtime < '{end}'
    GROUP BY o.didahotelid
)
SELECT didahotelid, hotel_name, country_code, chain, star_rating, bks_self
FROM scored
WHERE suppliers = 1
  AND bks_self >= {min_bks}
ORDER BY bks_self DESC
LIMIT 10000
