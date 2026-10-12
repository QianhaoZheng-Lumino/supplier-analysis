SELECT a.supplieraccountid,
       a.level,
       d.order_id,
       d.is_allow_sell,
       d.margin,
       d.remark,
       d.range_json::text AS range_json,
       s.rule_name,
       s.stay_night_list,
       s.stay_date_window_from,
       s.stay_date_window_to
FROM configuration.mask_l2l_supplier_level_rule_config a
LEFT JOIN configuration.mask_l2l_rule_config_detail d
  ON d.config_detail_group_id = a.configdetailgroupid
LEFT JOIN configuration.mask_l2l_rule_settings s
  ON s.rule_id = d.rule_id
WHERE a.supplierid = {supplier_id}
  AND a.level IN (1, 2, 3, 4)
ORDER BY a.supplieraccountid, a.level, d.order_id DESC
LIMIT 500
