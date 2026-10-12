WITH params AS (
    SELECT {supplier_id}::integer AS supplier_filter
),
levels AS (
    SELECT 1 AS level UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
),
ranked_limits AS (
    SELECT c.*,
           dense_rank() OVER (
               PARTITION BY c.supplier_id, c.level
               ORDER BY c.update_date DESC NULLS LAST
           ) AS recency_rank
    FROM configuration.mask_l2l_supplier_limit_config c
    JOIN params p ON p.supplier_filter = c.supplier_id
),
latest_limits AS (
    SELECT r.*, count(*) OVER (PARTITION BY supplier_id, level) AS latest_row_count
    FROM ranked_limits r
    WHERE recency_rank = 1
)
SELECT p.supplier_filter AS supplier_id,
       l.level,
       c.is_limit,
       CASE
         WHEN c.latest_row_count > 1 THEN 'REVIEW_DUPLICATE_LATEST'
         WHEN c.supplier_id IS NULL AND EXISTS (
             SELECT 1 FROM configuration.mask_l2l_supplier_limit_config x
             WHERE x.supplier_id = p.supplier_filter
         ) THEN 'BLOCK_MISSING_LEVEL'
         WHEN c.supplier_id IS NULL THEN 'ALLOW_NO_SUPPLIER_CONFIG'
         WHEN c.is_limit = 0 THEN 'ALLOW_ALL'
         WHEN c.is_limit = 1 THEN 'CHECK_ACCOUNT_RULES'
         ELSE 'REVIEW_UNKNOWN_SWITCH'
       END AS supplier_status
FROM params p
CROSS JOIN levels l
LEFT JOIN latest_limits c
  ON c.supplier_id = p.supplier_filter AND c.level = l.level
ORDER BY l.level
