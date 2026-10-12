WITH hotels AS (
    SELECT didahotelid
    FROM data_ovs.supplier_analysis_order
    WHERE supplierid = {supplier_id}
      AND createtime >= '{start}'
      AND createtime < '{end}'
    GROUP BY 1
),
ranked AS (
    SELECT o.didahotelid,
           o.supplierid,
           count(*) AS bks,
           row_number() OVER (
               PARTITION BY o.didahotelid
               ORDER BY count(*) DESC, o.supplierid
           ) AS rn
    FROM data_ovs.supplier_analysis_order o
    JOIN hotels h ON h.didahotelid = o.didahotelid
    WHERE o.createtime >= '{start}'
      AND o.createtime < '{end}'
    GROUP BY o.didahotelid, o.supplierid
),
picked AS (
    SELECT didahotelid,
           max(bks) FILTER (WHERE supplierid = {supplier_id}) AS self_bks,
           max(bks) FILTER (WHERE rn = 2) AS second_bks,
           max(supplierid) FILTER (WHERE rn = 1) AS top1
    FROM ranked
    GROUP BY didahotelid
)
SELECT count(*) AS advantage_hotels
FROM picked
WHERE top1 = {supplier_id}
  AND second_bks > 0
  AND self_bks >= second_bks * (1 + {advantage_ratio})
  AND self_bks >= {min_bks}
