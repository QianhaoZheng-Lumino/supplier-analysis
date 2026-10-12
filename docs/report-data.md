# 报告数据稿

HTML 只由 `scripts/render-report.py` 生成。运行时把本文件描述的 JSON 写到输出目录，再渲染。不要手写 HTML，不要改 `templates/report.css`。

```text
python scripts/render-report.py 数据稿.json -o 报告.html
```

句子字段写结论。数字字段写原始数：金额、订单、酒店数用整数，占比用 0 到 1 的小数。千分位、百分比、占比条、ADR 标绿、优势倍数标绿由脚本生成。

## 必填

| 字段 | 含义 |
|---|---|
| supplier_id / supplier_name | 标题 |
| start / end_inclusive / generated_on | 口径条。end_inclusive 是用户说的结束日 |
| overview.ttv / bks / hotels / adr | 四个 KPI。TTV 满 100 万由脚本写成 `¥45.5M` |
| lead | 整体结论第一句。自身产量最高的国家，加上资源优势方里市场份额最高的集团。不写 Independent。没有达标集团时只写国家 |
| verdict | 字符串数组，最多两句：客户、预订模式 |
| intro | 见下 |
| hotel | 见下 |
| pattern | 见下 |
| footnote | 页脚。HTML 不渲染数据附件 |
| excel_name | 只给写报告的人用，对话里报这个文件名。脚本不把它写进 HTML |

`client` 缺数据时写成 `null`，整章和左侧入口都不出现。

## intro

`advantage_oneline`、`market`、`brand`、`barrier`、`tech_oneline`、`tech_caption`、`l2l_oneline`、`l2l_caption`、`l2l_date`。

`tech_rows`：`{name, num, den}`。比率由脚本用分子 / 分母计算。

`l2l_rows`：`{level, text}`。

## hotel

`exclusive.oneline`、`exclusive.note`、`exclusive.rows`。行最多 10，字段：`hotel_id`、`name`、`country`、`chain`、`star`、`bks`。脚本固定列：排名、酒店 ID、酒店、国家、集团、星级、BKS。查询成功但一家都没有时，`queried` 设为 true，空表写「没有达到标准的酒店」。查询失败不要设 `queried`，空表仍写「未取得」。

`advantage.oneline`、`advantage.caption`、`advantage.rows`。行最多 10，在上面的字段外加 `second_name`、`second_bks`、`multiple`。倍数 ≥ 2 标绿。

`share_oneline`。三组数据只放占比 ≥ `share_threshold`（默认 0.10）的资源，没有就给空数组。脚本合成一张表，空数组对应的类型不出现。

`share_countries`：`name`、`self_share`、`others`。`share_chains` 字段相同，`name` 不能是 Independent。`share_country_chains`：`country`、`chain`、`self_share`、`others`，`chain` 不能是 Independent。`others` 是其他供应商数组，每项 `name`、`share`，最多 5 个；没有其他供应商就给空数组，脚本写成「无」。`self_share` 和 `others.share` 都是该资源全体供应商 TTV 的占比。

`chains`、`stars`、`countries`、`cities` 的行：`name`、`hotels`、`bks`、`ttv`、`adr`、`ttv_share`。对应的一句结论是 `chain_oneline`、`star_oneline`、`country_oneline`、`city_oneline`，表注是 `chain_caption`、`star_caption`、`country_caption`、`city_caption`。`summary` 是章末总结。

集团最多 10 行，国家最多 10 行，城市最多 15 行。这三张表的名称里不能出现「其余」或「 / 」。集团超出 10 个时，主报告只留 TTV 最高的 10 个，全量进 Excel。

## pattern 与 client

餐型行：`name`、`bks`、`ttv`、`adr`、`ttv_share`。入住晚数和提前天数行：`name`、`bks`、`ttv`、`bks_share`、`ttv_share`。

客户和父客户行：`name`、`hotels`、`bks`、`ttv`、`adr`、`bks_share`、`ttv_share`。客户行再加 `parent`，来自 `17-client.sql` 的 `parent_client_id`，空值写成「（父客户为空）」。父客户行不加 `parent`。走量型的父客户行加 `"volume": true`，脚本把 BKS 占比标红。各最多 15 行。
