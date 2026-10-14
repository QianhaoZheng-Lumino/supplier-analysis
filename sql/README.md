# SQL

每份文件一次 `execute_sql`。每一波最多 5 条，返回后立刻开下一波，直到 HTML 和 Excel 都生成，不要停下来等用户。先 Read 该文件，再只替换下面列出的占位符。除占位符外，送出的语句与文件原文一致。不增删列、过滤或 `LIMIT`，不加 `left()`，不把两份文件拼进同一次调用。凭记忆重写的语句，即使结果看起来一样，也不能写入报告。开跑不探活；本轮第一条查询返回 500 时，才允许一次 `SELECT 1 LIMIT 1`。

`{start}`、`{end}` 是 `YYYY-MM-DD`，`{end}` 是用户结束日的下一天。`{supplier_id}`、`{min_bks}` 是整数。`{advantage_ratio}` 默认 `0.30`。`{share_threshold}` 默认 `0.10`，不加引号。`{q}`、`{country_code}`、`{chain}` 来自查询结果或用户原文；含单引号就停，改要 SupplierID。`timeout_seconds`：`11`、`12`、`12b` 用 300，`03-breakdowns`、`13-country-advantage`、`14-chain-advantage` 用 180，其余 120。

「用到的表」只说明文件打哪张表，不是 `execute_sql` 的参数。查询只传 `sql`、`timeout_seconds`、`original_question`。

执行时只跑下面这些。`03` 到 `10`、`13-share-country`、`14-share-chain`、`15`、三份 `16-others-*` 已被新文件替代，不要跑。

| 文件 | 何时跑 | 用到的表 |
|---|---|---|
| 01-resolve-by-id.sql | 用户给了整数 ID | public.ovs_supplier_info_v |
| 02-resolve-by-text.sql | 用户给了名称或 OP | public.ovs_supplier_info_v |
| 03-breakdowns.sql | 锁定 ID 后。一次返回 overview、chain、star、country、city、meal、los、lt | data_ovs.supplier_analysis_order |
| 11-exclusive-detail.sql | 与 22、23、12 同一轮。全量在 1 万行内 | data_ovs.supplier_analysis_order |
| 12-advantage-detail.sql | 与 11 同一轮；500 再跑 12b | data_ovs.supplier_analysis_order |
| 12b-advantage-count.sql | 仅 12 失败时 | data_ovs.supplier_analysis_order |
| 13-country-advantage.sql | 与 14、21 同一轮。前 10 个国家，以及这些国家里的集团和其他供应商 | data_ovs.supplier_analysis_order |
| 14-chain-advantage.sql | 与 13 同一轮。已排除 Independent | data_ovs.supplier_analysis_order |
| 17-client.sql | 与 03-breakdowns 同一轮；必须含 `supplier_rebook_sequence = 1`；按 client_id、parent_client_id 分组；500 则整章省略 | dwd.dwd_hotel_order_channel_supplier_booking_mf |
| 18-client-total.sql | 同上，含 `supplier_rebook_sequence = 1` | dwd.dwd_hotel_order_channel_supplier_booking_mf |
| 19-parent.sql | 同上，含 `supplier_rebook_sequence = 1` | dwd.dwd_hotel_order_channel_supplier_booking_mf |
| 20-parent-total.sql | 同上，含 `supplier_rebook_sequence = 1`。CR5/CR10 的分母 | dwd.dwd_hotel_order_channel_supplier_booking_mf |
| 21-tech-account.sql | 与 13、14 同一轮 | data_ovs.supplier_analysis_tech_index_30d, content.domain_supplier_account |
| 22-l2l-levels.sql | 与 23、11、12 同一轮 | configuration.mask_l2l_supplier_limit_config |
| 23-l2l-rules.sql | 与 22 同一轮就发。没有任何一级是 CHECK_ACCOUNT_RULES 时不写入报告 | configuration.mask_l2l_supplier_level_rule_config, configuration.mask_l2l_rule_config_detail, configuration.mask_l2l_rule_settings |
