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
           max(o.suppliername) AS suppliername,
           max(o.didahotelname_en) AS hotel_name,
           max(o.country_code) AS country_code,
           max(o.chain) AS chain,
           max(o.star_rating) AS star_rating,
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
           max(suppliername) FILTER (WHERE rn = 2) AS second_name,
           max(supplierid) FILTER (WHERE rn = 1) AS top1,
           max(hotel_name) AS hotel_name,
           max(country_code) AS country_code,
           max(chain) AS chain,
           max(star_rating) AS star_rating
    FROM ranked
    GROUP BY didahotelid
)
SELECT didahotelid, hotel_name, country_code, chain, star_rating,
       self_bks, second_bks, second_name,
       round(self_bks::numeric / nullif(second_bks, 0), 2) AS multiple
FROM picked
WHERE top1 = {supplier_id}
  AND second_bks > 0
  AND self_bks >= second_bks * (1 + {advantage_ratio})
  AND self_bks >= {min_bks}
ORDER BY self_bks DESC
LIMIT 10000
