---
name: supplier-analysis
description: >-
  供应商优势资源分析（Overseas API）。用户要看某个供应商、出供应商分析报告、
  分析优势资源、独家酒店、优势酒店、资源优势方、客户结构、预订模式、
  有价率、准确率、失败率或 L2L 配置时使用。
  触发词：供应商分析、供应商报告、优势资源、独家酒店、资源优势方、supplier analysis。
  执行顺序以 SKILL.md 正文为准，禁止只凭本 description 出报告。
---

# 供应商分析

一次运行产出**一个供应商、一个时间范围**的分析报告：一份 HTML，一份 Excel。视觉和章节骨架以 [templates/report.css](templates/report.css) 与 [scripts/render-report.py](scripts/render-report.py) 为准，口径以 [docs/report.md](docs/report.md) 为准，数据稿格式以 [docs/report-data.md](docs/report-data.md) 为准。SQL 只从 [sql/](sql/) 读原文、替换占位符，不手写、不合并、不改过滤。HTML 只由渲染脚本生成，不手写。

## 输入

缺供应商或时间范围就问，问完再查。三个阈值用户没提就用默认，不要为了确认默认值打断。

| 参数 | 必填 | 默认 | 说明 |
|---|---|---|---|
| 供应商 | 是 | | SupplierID、名称或 OP。先解析成一个整数 `supplier_id` |
| 时间范围 | 是 | | 用户说的结束日含当天。SQL 里 `{end}` 写成结束日的下一天 |
| 资源优势方阈值 | | 0.10 | 该资源上本供应商 TTV / 全体供应商 TTV |
| 优势酒店阈值 | | 0.30 | 本供应商 BKS ≥ 第二名 BKS × 1.30 |
| 独家最低订单量 | | 10 | 全市场只有本供应商出单，且 BKS ≥ 该值 |

名称或 OP 命中多家：列出 `supplier_id / sid / 名称` 让用户选，选定前不查产量。用户原文含单引号：停，改要 SupplierID。

## 执行顺序

一次运行要自己跑完下面 6 步，直到 HTML 和 Excel 都交出来。每一波 `execute_sql` 最多 5 条，这一波的结果返回后立刻发下一波，不要停下来等用户说「继续」，也不要交半成品。Read 不计入这 5 条。开跑不探活。固定 13 次查询：`01` 或 `02`、`03-breakdowns`、`13-country-advantage`、`14-chain-advantage`、`17`、`18`、`19`、`20`、`21`、`22`、`23`、`11`、`12`。12 失败时再加一次 `12b`。次数不随达标国家或集团增加。只有 data MCP 探活失败，才停下告诉用户。

```
进度:
- [ ] 1. 01 或 02，锁定一个 supplier_id
- [ ] 2. 03-breakdowns、17、18、19、20
- [ ] 3. 13-country-advantage、14-chain-advantage、21
- [ ] 4. 22、23、11、12。12 失败时，下一轮先跑 12b
- [ ] 5. 本地算占比、ADR、CR5/CR10、走量走利、L2L 摘要。13、14 返回的行都已达到 `{share_threshold}`
- [ ] 6. 按 docs/report-data.md 写数据稿 JSON，运行 scripts/render-report.py 生成 HTML，再写同名 Excel
```

`11`、`12`、`12b` 不和 `03-breakdowns`、`13-country-advantage`、`14-chain-advantage`、`17`–`21` 放在同一轮。`23` 和 `22`、`11`、`12` 同一轮发出，不要等 22 返回。22 里没有任何一级是 `CHECK_ACCOUNT_RULES` 时，23 的结果不写进报告。23 失败只让这一级的规则摘要写「未取得」，独家和优势保持已返回的结果。客户四条（17–20）返回 500：整章省略，报告写「当前账号看不到客户数据」。不要换成别的表，不要留空表。

不要跑已被替代的旧文件：`03` 到 `10`、`13-share-country`、`14-share-chain`、`15`、`16-others-country`、`16-others-chain`、`16-others-country-chain`。

`03-breakdowns` 用 `section` 拆开。`overview` 一行是四个 KPI。`chain` 最多 200 行，`country` 最多 100 行，`city` 最多 500 行，`rn` 是该段内部名次。主报告的集团、国家、城市仍只展示 Top 10、Top 10、Top 15，全量进 Excel。`meal` 的酒店数为空。`los` 和 `lt` 的酒店数、ADR 为空。

`13-country-advantage` 和 `14-chain-advantage` 已经按 `{share_threshold}` 去掉未达标的国家、集团和国家×集团。返回的 `country`、`country_chain`、`chain` 全部写入资源优势方，不要再删，也不要补未返回的行。`country_other` 挂在对应国家下，`chain_other` 挂在对应集团下，`country_chain_other` 挂在对应的国家×集团下。占比用该行的 `self_ttv / market_ttv` 或 `other_ttv / market_ttv`。金额相同时，供应商取 ID 较小的一家，国家、集团、城市取名称字母序靠前的一个。Independent 不进集团。

本轮第一条 `execute_sql` 返回 500：先跑 `SELECT 1 LIMIT 1`。探活也失败，这一轮停下，告诉用户 data MCP 不稳定。探活成功，只把失败的那一条用原文再跑一次。仍然失败，该块写「未取得」，数字留空。同轮已经有成功结果时不再探活，只重试失败的那一条。禁止写成 0，禁止用样例报告或上一次结果填，禁止改 SQL 后再试。查询只传 `sql`、`timeout_seconds`、`original_question`，不传 `tables`。[sql/README.md](sql/README.md) 里的「用到的表」只说明文件打哪张表。`timeout_seconds`：`11`、`12`、`12b` 用 300，`03-breakdowns`、`13-country-advantage`、`14-chain-advantage` 用 180，其余 120。`original_question` 原样传入用户本轮提问。

## 查询

一次 `execute_sql` 等于一个 `sql/` 文件。发查询的同一轮先 Read 这个文件。`sql` 参数只能把这次 Read 到的原文里的占位符换成值，其余字符与文件一致。占位符只有 `{supplier_id}`、`{start}`、`{end}`、`{min_bks}`、`{advantage_ratio}`、`{share_threshold}`、`{q}`、`{country_code}`、`{chain}`。`{share_threshold}` 用资源优势方阈值，用户没提就写 `0.10`，不加引号。语句里不能出现 `--` 或 `#`。

下面这些都不算在执行文件：凭记忆重写、把文件逻辑换一种写法、加 `left()`、改 `LIMIT`、增删列或过滤、把多个文件拼进一次调用、开跑先查 `SELECT 1`、查 `information_schema`。本轮第一条查询返回 500 时的 `SELECT 1 LIMIT 1` 是唯一例外。`12-advantage-detail.sql` 必须读文件再替换，不能另写一条「等价」语句。`23-l2l-rules.sql` 的 `range_json` 按文件原样返回；放不进摘要就写「规则原文过长，未逐条展开」，不能自行截断。同一轮最多 5 条 `execute_sql`。

不是从当次 Read 原文替换来的结果，不能写入报告。

## 口径（不可改）

- 产量视图 `data_ovs.supplier_analysis_order` 已经是：Overseas API、创建时间、渠道和供应商状态都在 (2, 3)、`rebook_sequence = 1`、含当天取消、离店日期从 2024-01-01 起。报告里不另加这些过滤。开始日早于 2024-01-01 时，口径条注明「2024 年以前的创建订单不在视图里」。
- 金额只用 `pricecny` / `channel_price_cny`，报告写 CNY。不用 USD。
- 客户来自 `dwd.dwd_hotel_order_channel_supplier_booking_mf`，过滤创建日、状态 (2, 3)、`client_group_id = 3`、`supplier_rebook_sequence = 1`。该表没有名为 `rebook_sequence` 的列，rebook 序列列是 `supplier_rebook_sequence`，必须等于 1。产量视图 `data_ovs.supplier_analysis_order` 的粒度已经是 `rebook_sequence = 1`，视图不暴露这一列，产量查询不再加这个条件。客户表受权限隔离，金额是 `channel_price_cny`，可以和产量视图的 `pricecny` 对不上，报告不解释成口径错误。
- 技术指标来自 `data_ovs.supplier_analysis_tech_index_30d`，固定近 30 天（实际 T-29 到 T-1），全业务线，不随报告时间范围变。只有有价率、准确率、失败率。没有缺陷率，没有响应时长。
- 失败率 = 失败供应商订单 / 供应商订单，按每次向供应商下单计，不是 ORD_0112。
- L2L 是查询当时的普通配置，不是历史，不含客户特殊配置。
- `chain` 是下单时集团，不是酒店主数据的最新集团。
- 餐型空值单独一行「（餐型为空）」，不并进仅客房。

## 判定

- **资源优势方**：三类，都是本供应商 TTV / 该资源全体供应商 TTV ≥ 阈值。国家优势看本供应商 TTV 最高的 10 个国家。品牌优势看本供应商 TTV 最高的 10 个集团，`chain = 'Independent'` 先排除，它是独立酒店，不是集团。国家内品牌优势只在达标国家里看该供应商 TTV 最高的 5 个集团，同样排除 Independent。达标资源才进同一张表，列是类型、资源、本供应商 TTV 占比、其他供应商占比。某一类没有达标资源就不出现。其他供应商最多 5 个，没有就写「无」。这是资源内的市场份额，不是该资源占本供应商自己 TTV 的比例。
- **独家**：统计期内该酒店只有本供应商有单，且 BKS ≥ 最低订单量。必须用全体供应商的单核对，不能只看本供应商。
- **优势**：本供应商是该酒店 BKS 第一，存在第二名，本供应商 BKS ≥ 第二名 × (1 + 阈值)，且本供应商 BKS ≥ 最低订单量。倍数 = 本供应商 BKS / 第二名 BKS。
- **走量型**：父客户 BKS 占比 − TTV 占比 ≥ 5 个百分点。**走利型**：TTV 占比 − BKS 占比 ≥ 3 个百分点。只在 Parent Top 15 里标。
- CR5 / CR10 的分母是父客户 TTV 合计（20 的总数），不是 Top 15 的合计。

独家和优势的规则是 v1，报告注明所用阈值。

## 报告

先写数据稿，再渲染。不要改 CSS，不要改脚本里的章节和列名，不要把样例 HTML 当正文来源。`examples/1943-etstur-2026.html` 是早期占位稿，其中资源优势方用的是占本供应商自身 TTV 的比例，判定以上面的市场份额为准。

```text
python scripts/render-report.py 数据稿.json -o supplier-analysis-reports/{supplier_id}-{start}-{结束日}.html
```

脚本固定这些块：介绍三张卡片、资源质量、L2L、四个 KPI、`.lead`、独家 Top 10、优势 Top 10、资源优势方（一张表，只列达标的国家、品牌、国家内品牌）、集团 Top 10、星级、国家、城市 Top 15、客户、预订模式。HTML 不放数据附件，左侧导轨也不留这个入口。独家列是排名、酒店 ID、酒店、国家、集团、星级、BKS。优势列在此之外还有第二名、第二名 BKS、倍数。集团一个集团一行，最多 10 行。国家一国一行，最多 10 行。城市一城一行，最多 15 行。这三张表不写「其余」，也不把多个集团、国家或城市并进一个格子。

不写供应商背景，不写资源限制，不写「由数据自动生成」，不写客户下钻。主报告的集团只到 Top 10，城市、客户只到 Top 15，全量进 Excel。

交出时，HTML 是页面。对话里再写一遍整体结论，内容和页面上的四个 KPI、`.lead`、至多两句结论相同，不另写一版。Excel 路径写在同一条对话里，不写进 HTML。

数字由脚本格式化：BKS、酒店数、TTV、ADR 千分位整数；百分比 1 位小数。星级按 5、4、3、2、1、Unrated。其余表按 TTV 降序。占比条按该列最大占比缩放到 150px。ADR 高于整体 3 倍标绿。优势倍数 ≥ 2 标绿。走量型父客户的 BKS 占比标红，数据稿里该行写 `"volume": true`。

Excel 与 HTML 同名，sheet：集团、星级、国家、城市、餐型、入住晚数、提前天数、独家酒店、优势酒店、客户、父客户、技术指标。客户 sheet 在 Client ID 右边加 Parent Client ID。父客户 sheet 不加这一列。文件交给用户时放在对话里。

输出到当前工作区 `supplier-analysis-reports/{supplier_id}-{start}-{结束日}.html`。

## 不要做什么

- 手写 SQL，凭记忆重写文件，把多个文件并进一次 `execute_sql`，或同一轮发出超过 5 条
- 开跑先探活。只有本轮第一条 `execute_sql` 返回 500 时才跑 `SELECT 1 LIMIT 1`
- 改文件里的列、过滤、`LIMIT`，或给 `range_json` 加 `left()`
- 手写 HTML，或改 templates/report.css、scripts/render-report.py 的章节和列
- 独家或优势只留一句汇总、不出 Top 10 表
- 集团、国家或城市表写「其余」，或把多个集团、国家、城市并进同一格
- 用 USD、补缺陷率、补响应时长、把技术指标按报告时间重算
- 查询失败写成 0，或用样例里的 1943 数字填别的供应商
- 资源优势方用「占本供应商自身 TTV」代替「占该资源全体 TTV」
- 把 Independent 写成品牌优势、国家内品牌优势，或写进介绍的品牌卡和整体结论第一句
- 把餐型空值并进仅客房；把 L2L 写成某个客户的最终可售
- 介绍里写供应商背景、资源限制，或「三块内容全部由数据自动生成」
- 主报告里做客户下钻
- 把 data MCP 的密钥、`mcp.json` 或本机凭证写进技能、报告，或提交到 GitHub
- 因为一波已经有 5 条查询就结束任务、交出半成品，或等用户说「继续」
- 再跑 `03` 到 `10`、`13-share-country`、`14-share-chain`、`15`、`16-others-country`、`16-others-chain`、`16-others-country-chain`
- 等 22 返回之后才发 23；或在没有 `CHECK_ACCOUNT_RULES` 的等级写入 23 的规则
