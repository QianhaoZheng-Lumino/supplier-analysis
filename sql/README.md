# SQL

每份文件一次 `execute_sql`。同一轮最多 5 条。先 Read 该文件，再只替换下面列出的占位符。除占位符外，送出的语句与文件原文一致。不增删列、过滤或 `LIMIT`，不加 `left()`，不把两份文件拼进同一次调用。凭记忆重写的语句，即使结果看起来一样，也不能写入报告。开跑不探活；本轮第一条查询返回 500 时，才允许一次 `SELECT 1 LIMIT 1`。

`{start}`、`{end}` 是 `YYYY-MM-DD`，`{end}` 是用户结束日的下一天。`{supplier_id}`、`{min_bks}` 是整数。`{advantage_ratio}` 默认 `0.30`。`{q}`、`{country_code}`、`{chain}` 来自查询结果或用户原文；含单引号就停，改要 SupplierID。

「用到的表」只说明文件打哪张表，不是 `execute_sql` 的参数。查询只传 `sql`、`timeout_seconds`、`original_question`。

| 文件 | 何时跑 | 用到的表 |
|---|---|---|
| 01-resolve-by-id.sql | 用户给了整数 ID | public.ovs_supplier_info_v |
| 02-resolve-by-text.sql | 用户给了名称或 OP | public.ovs_supplier_info_v |
| 03-overview.sql | 锁定 ID 后 | data_ovs.supplier_analysis_order |
| 04-by-chain.sql | 同上 | data_ovs.supplier_analysis_order |
| 05-by-star.sql | 同上 | data_ovs.supplier_analysis_order |
| 06-by-country.sql | 同上 | data_ovs.supplier_analysis_order |
| 07-by-city.sql | 同上 | data_ovs.supplier_analysis_order |
| 08-by-meal.sql | 同上 | data_ovs.supplier_analysis_order |
| 09-by-los.sql | 同上 | data_ovs.supplier_analysis_order |
| 10-by-lt.sql | 同上 | data_ovs.supplier_analysis_order |
| 11-exclusive-detail.sql | 同上，全量在 1 万行内 | data_ovs.supplier_analysis_order |
| 12-advantage-detail.sql | 同上；500 再跑 12b | data_ovs.supplier_analysis_order |
| 12b-advantage-count.sql | 仅 12 失败时 | data_ovs.supplier_analysis_order |
| 13-share-country.sql | 同上 | data_ovs.supplier_analysis_order |
| 14-share-chain.sql | 同上。已排除 Independent | data_ovs.supplier_analysis_order |
| 15-share-country-chain.sql | 只对 13 里占比 ≥ 阈值的国家，每个国家一次。已排除 Independent | data_ovs.supplier_analysis_order |
| 16-others-country.sql | 只对达标国家 | data_ovs.supplier_analysis_order |
| 16-others-chain.sql | 只对达标集团。Independent 不跑 | data_ovs.supplier_analysis_order |
| 16-others-country-chain.sql | 只对达标的国家 × 集团。Independent 不跑 | data_ovs.supplier_analysis_order |
| 17-client.sql | 同上；必须含 `supplier_rebook_sequence = 1`；500 则整章省略 | dwd.dwd_hotel_order_channel_supplier_booking_mf |
| 18-client-total.sql | 同上，含 `supplier_rebook_sequence = 1` | dwd.dwd_hotel_order_channel_supplier_booking_mf |
| 19-parent.sql | 同上，含 `supplier_rebook_sequence = 1` | dwd.dwd_hotel_order_channel_supplier_booking_mf |
| 20-parent-total.sql | 同上，含 `supplier_rebook_sequence = 1`。CR5/CR10 的分母 | dwd.dwd_hotel_order_channel_supplier_booking_mf |
| 21-tech-account.sql | 同上 | data_ovs.supplier_analysis_tech_index_30d, content.domain_supplier_account |
| 22-l2l-levels.sql | 同上 | configuration.mask_l2l_supplier_limit_config, configuration.mask_l2l_supplier_level_rule_config |
| 23-l2l-rules.sql | 22 的状态是 CHECK_ACCOUNT_RULES 时 | configuration.mask_l2l_supplier_limit_config, configuration.mask_l2l_supplier_level_rule_config, configuration.mask_l2l_rule_config_detail, configuration.mask_l2l_rule_settings |
