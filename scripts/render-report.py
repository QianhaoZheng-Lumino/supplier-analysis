# -*- coding: utf-8 -*-
"""把报告数据稿渲染成 HTML。版式只来自 templates/report.css 和本文件的章节骨架。"""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSS_PATH = ROOT / "templates" / "report.css"

EXCLUSIVE_HEADERS = ["排名", "酒店 ID", "酒店", "国家", "集团", "星级", "BKS"]
ADVANTAGE_HEADERS = ["排名", "酒店 ID", "酒店", "国家", "集团", "星级", "BKS", "第二名", "第二名 BKS", "倍数"]
DIM_HEADERS = ["名称", "酒店数", "BKS", "TTV (CNY)", "ADR", "TTV 占比"]
MEAL_HEADERS = ["餐型", "BKS", "TTV (CNY)", "ADR", "TTV 占比"]
SPAN_HEADERS = ["区间", "BKS", "TTV (CNY)", "BKS 占比", "TTV 占比"]
CLIENT_HEADERS = ["名称", "有产酒店", "BKS", "TTV (CNY)", "ADR", "BKS 占比", "TTV 占比"]


def esc(value) -> str:
    return html.escape("" if value is None else str(value), quote=True)


def num(value) -> str:
    if value is None or value == "":
        return "—"
    return f"{int(round(float(value))):,}"


def plain_int(value) -> str:
    return str(int(value))


def pct(value) -> str:
    return f"{float(value) * 100:.1f}%"


def ttv_kpi(value) -> str:
    amount = float(value)
    if amount >= 1_000_000:
        return f"¥{amount / 1_000_000:.1f}M"
    return "¥" + num(amount)


def require(data: dict, key: str):
    if key not in data:
        raise SystemExit(f"数据稿缺少 {key}")
    return data[key]


def reject_merged(label: str, where: str) -> None:
    text = "" if label is None else str(label)
    if "其余" in text or " / " in text:
        raise SystemExit(f"{where} 不能合并行：{text}")


def bar(share, top: float) -> str:
    share_n = float(share or 0)
    width = 0
    if top > 0 and share_n > 0:
        width = max(1, round(150 * share_n / top))
    return f'<span class="bar" style="width:{width}px"></span><span class="num pct">{pct(share_n)}</span>'


def cells(values: list[str]) -> str:
    return "".join(f"<td{cls}>{body}</td>" for cls, body in values)


def td_text(text: str, nowrap: bool = False) -> tuple[str, str]:
    return (' class="nowrap"' if nowrap else "", esc(text))


def td_num(text: str, extra: str = "") -> tuple[str, str]:
    klass = "num" + ((" " + extra) if extra else "")
    return (f' class="{klass}"', text)


def table(headers: list[str], body: str, caption: str = "") -> str:
    head = "".join(f"<th>{esc(h)}</th>" for h in headers)
    cap = f"\n    <caption>{esc(caption)}</caption>" if caption else ""
    return (
        "  <table>\n"
        f"    <thead><tr>{head}</tr></thead>\n"
        f"    <tbody>\n{body}\n    </tbody>{cap}\n"
        "  </table>"
    )


def missing_row(width: int) -> str:
    return f'      <tr><td colspan="{width}">未取得</td></tr>'


def dim_table(rows: list[dict], headers: list[str], adr_base: float, where: str, limit: int | None, caption: str = "", separate: bool = False) -> str:
    if limit is not None and len(rows) > limit:
        raise SystemExit(f"{where} 最多 {limit} 行，当前 {len(rows)} 行")
    if separate:
        for row in rows:
            reject_merged(row.get("name"), where)
    if not rows:
        return table(headers, missing_row(len(headers)), caption)
    top = max(float(row.get("ttv_share") or 0) for row in rows)
    lines = []
    for row in rows:
        adr = row.get("adr")
        hot = "hot" if adr is not None and adr_base and float(adr) >= adr_base * 3 else ""
        lines.append(
            "      <tr>"
            + cells([
                td_text(row.get("name")),
                td_num(num(row.get("hotels"))),
                td_num(num(row.get("bks"))),
                td_num(num(row.get("ttv"))),
                td_num(num(adr), hot),
                ("", bar(row.get("ttv_share"), top)),
            ])
            + "</tr>"
        )
    return table(headers, "\n".join(lines), caption)


def exclusive_table(rows: list[dict], queried: bool = False) -> str:
    if len(rows) > 10:
        raise SystemExit(f"独家酒店 Top 10 最多 10 行，当前 {len(rows)} 行")
    if not rows:
        label = "没有达到标准的酒店" if queried else "未取得"
        return table(EXCLUSIVE_HEADERS, f'      <tr><td colspan="{len(EXCLUSIVE_HEADERS)}">{label}</td></tr>')
    lines = []
    for index, row in enumerate(rows, 1):
        lines.append(
            "      <tr>"
            + cells([
                td_num(str(index)),
                td_num(plain_int(row["hotel_id"])),
                td_text(row.get("name")),
                td_text(row.get("country"), nowrap=True),
                td_text(row.get("chain"), nowrap=True),
                td_num(esc(row.get("star"))),
                td_num(num(row.get("bks"))),
            ])
            + "</tr>"
        )
    return table(EXCLUSIVE_HEADERS, "\n".join(lines))


def advantage_table(rows: list[dict], caption: str) -> str:
    if len(rows) > 10:
        raise SystemExit(f"优势酒店 Top 10 最多 10 行，当前 {len(rows)} 行")
    if not rows:
        return table(ADVANTAGE_HEADERS, missing_row(len(ADVANTAGE_HEADERS)), caption)
    lines = []
    for index, row in enumerate(rows, 1):
        multiple = float(row["multiple"])
        hot = "hot" if multiple >= 2 else ""
        lines.append(
            "      <tr>"
            + cells([
                td_num(str(index)),
                td_num(plain_int(row["hotel_id"])),
                td_text(row.get("name")),
                td_text(row.get("country"), nowrap=True),
                td_text(row.get("chain"), nowrap=True),
                td_num(esc(row.get("star"))),
                td_num(num(row.get("bks"))),
                td_text(row.get("second_name"), nowrap=True),
                td_num(num(row.get("second_bks"))),
                td_num(f"{multiple:.2f}", hot),
            ])
            + "</tr>"
        )
    return table(ADVANTAGE_HEADERS, "\n".join(lines), caption)


def reject_independent(name, where: str) -> None:
    if str(name or "").strip().lower() == "independent":
        raise SystemExit(f"{where} 不把 Independent 当作集团：{name}")


def share_threshold(data: dict) -> float:
    return float(data.get("share_threshold", 0.10))


def format_threshold(threshold: float) -> str:
    text = f"{round(threshold * 100, 1):.1f}"
    if text.endswith(".0"):
        text = text[:-2]
    return text + "%"


def others_cell(rows, where: str) -> str:
    if not rows:
        return "无"
    if len(rows) > 5:
        raise SystemExit(f"{where} 其他供应商最多 5 个，当前 {len(rows)} 个")
    parts = []
    for row in rows:
        name = str(row.get("name") or "").strip()
        if not name:
            raise SystemExit(f"{where} 其他供应商缺少名称")
        parts.append(f"{name} ({pct(row.get('share'))})")
    return "，".join(parts)


def ensure_share(share, threshold: float, where: str, label: str) -> None:
    if float(share or 0) + 1e-9 < threshold:
        raise SystemExit(f"{where} 未达阈值仍写入：{label}")


def share_resource_label(row: dict, kind: str, where: str) -> str:
    if kind == "country_chain":
        country = str(row.get("country") or "").strip()
        chain = str(row.get("chain") or "").strip()
        reject_merged(country, where)
        reject_merged(chain, where)
        reject_independent(chain, where)
        if not country or not chain:
            raise SystemExit(f"{where} 缺少国家或集团")
        return f"{country} · {chain}"
    label = str(row.get("name") or "").strip()
    reject_merged(label, where)
    if kind == "chain":
        reject_independent(label, where)
    if not label:
        raise SystemExit(f"{where} 缺少资源名称")
    return label


def advantage_share_table(hotel: dict, threshold: float) -> str:
    where = "资源优势方"
    headers = ["类型", "资源", "本供应商 TTV 占比", "其他供应商占比"]
    groups = [
        ("国家优势资源", "country", hotel.get("share_countries") or [], 10),
        ("品牌优势资源", "chain", hotel.get("share_chains") or [], 10),
        ("国家内品牌优势资源", "country_chain", hotel.get("share_country_chains") or [], 50),
    ]
    lines = []
    for type_name, kind, rows, limit in groups:
        if not rows:
            continue
        if len(rows) > limit:
            raise SystemExit(f"{type_name} 最多 {limit} 行，当前 {len(rows)} 行")
        ranked = sorted(rows, key=lambda row: float(row.get("self_share") or 0), reverse=True)
        for row in ranked:
            label = share_resource_label(row, kind, where)
            ensure_share(row.get("self_share"), threshold, where, label)
            lines.append(
                "      <tr>"
                + cells([
                    td_text(type_name, nowrap=True),
                    td_text(label, nowrap=True),
                    td_num(pct(row.get("self_share"))),
                    td_text(others_cell(row.get("others") or [], where)),
                ])
                + "</tr>"
            )
    if not lines:
        return "<p class=\"note\">没有资源达到阈值。</p>"
    return table(headers, "\n".join(lines))


def meal_table(rows: list[dict], adr_base: float) -> str:
    if not rows:
        return table(MEAL_HEADERS, missing_row(len(MEAL_HEADERS)))
    top = max(float(row.get("ttv_share") or 0) for row in rows)
    lines = []
    for row in rows:
        adr = row.get("adr")
        hot = "hot" if adr is not None and adr_base and float(adr) >= adr_base * 3 else ""
        lines.append(
            "      <tr>"
            + cells([
                td_text(row.get("name")),
                td_num(num(row.get("bks"))),
                td_num(num(row.get("ttv"))),
                td_num(num(adr), hot),
                ("", bar(row.get("ttv_share"), top)),
            ])
            + "</tr>"
        )
    return table(MEAL_HEADERS, "\n".join(lines))


def span_table(rows: list[dict]) -> str:
    if not rows:
        return table(SPAN_HEADERS, missing_row(len(SPAN_HEADERS)))
    top = max(float(row.get("ttv_share") or 0) for row in rows)
    lines = []
    for row in rows:
        lines.append(
            "      <tr>"
            + cells([
                td_text(row.get("name")),
                td_num(num(row.get("bks"))),
                td_num(num(row.get("ttv"))),
                td_num(pct(row.get("bks_share"))),
                ("", bar(row.get("ttv_share"), top)),
            ])
            + "</tr>"
        )
    return table(SPAN_HEADERS, "\n".join(lines))


def client_table(rows: list[dict], adr_base: float, caption: str) -> str:
    if len(rows) > 15:
        raise SystemExit(f"客户表最多 15 行，当前 {len(rows)} 行")
    if not rows:
        return table(CLIENT_HEADERS, missing_row(len(CLIENT_HEADERS)), caption)
    lines = []
    for row in rows:
        adr = row.get("adr")
        hot = "hot" if adr is not None and adr_base and float(adr) >= adr_base * 3 else ""
        down = "down" if row.get("volume") else ""
        lines.append(
            "      <tr>"
            + cells([
                td_text(row.get("name")),
                td_num(num(row.get("hotels"))),
                td_num(num(row.get("bks"))),
                td_num(num(row.get("ttv"))),
                td_num(num(adr), hot),
                td_num(pct(row.get("bks_share")), down),
                td_num(pct(row.get("ttv_share"))),
            ])
            + "</tr>"
        )
    return table(CLIENT_HEADERS, "\n".join(lines), caption)


def tech_table(rows: list[dict], caption: str) -> str:
    headers = ["指标", "分子", "分母", "比率"]
    if not rows:
        return table(headers, missing_row(4), caption)
    lines = []
    for row in rows:
        den = row.get("den")
        rate = "—" if not den else pct(float(row["num"]) / float(den))
        lines.append(
            "      <tr>"
            + cells([
                td_text(row.get("name")),
                td_num(num(row.get("num"))),
                td_num(num(den)),
                td_num(rate),
            ])
            + "</tr>"
        )
    return table(headers, "\n".join(lines), caption)


def l2l_table(rows: list[dict], caption: str) -> str:
    headers = ["等级", "配置摘要"]
    if not rows:
        return table(headers, missing_row(2), caption)
    lines = []
    for row in rows:
        lines.append(
            "      <tr>"
            + f'<td class="num">{esc(row.get("level"))}</td>'
            + f'<td style="text-align:left">{esc(row.get("text"))}</td>'
            + "</tr>"
        )
    return table(headers, "\n".join(lines), caption)


def render(data: dict) -> str:
    css = CSS_PATH.read_text(encoding="utf-8")
    supplier_id = require(data, "supplier_id")
    supplier_name = require(data, "supplier_name")
    overview = require(data, "overview")
    adr_base = float(overview.get("adr") or 0)
    intro = require(data, "intro")
    hotel = require(data, "hotel")
    pattern = require(data, "pattern")
    client = data.get("client")

    nav = [
        ("#intro", "介绍"),
        ("#conclusion", "整体结论"),
        ("#hotel", "酒店资源"),
    ]
    if client:
        nav.append(("#client", "客户维度"))
    nav.append(("#pattern", "预订模式"))
    nav_html = "\n".join(f'  <a href="{href}">{esc(label)}</a>' for href, label in nav)

    verdict_bits = [f'    <p class="lead">{esc(require(data, "lead"))}</p>']
    for sentence in data.get("verdict") or []:
        verdict_bits.append(f"    <p>{esc(sentence)}</p>")

    country_headers = ["国家", *DIM_HEADERS[1:]]
    city_headers = ["城市", *DIM_HEADERS[1:]]
    chain_headers = ["集团", *DIM_HEADERS[1:]]
    star_headers = ["星级", *DIM_HEADERS[1:]]

    if "share_resources" in hotel:
        raise SystemExit("资源优势方改用 share_countries、share_chains、share_country_chains")
    threshold = share_threshold(data)
    threshold_label = str(data.get("share_threshold_label") or format_threshold(threshold))
    share_html = advantage_share_table(hotel, threshold)

    client_html = ""
    if client:
        client_html = f"""
<section id="client">
  <h2>客户维度分析</h2>
  <p class="subhead">{esc(client.get("subhead") or "来自客户维度表，只含当前账号能看到的客户。主报告不含客户下钻。")}</p>
  <h3>Client ID（Top 15）</h3>
  <p class="oneline">{esc(client.get("client_oneline") or "")}</p>
  {client_table(client.get("clients") or [], adr_base, client.get("client_caption") or "")}
  <h3>Parent ID（Top 15）</h3>
  <p class="oneline">{esc(client.get("parent_oneline") or "")}</p>
  {client_table(client.get("parents") or [], adr_base, client.get("parent_caption") or "")}
  <div class="summary">{esc(client.get("summary") or "").replace(chr(10), "<br>")}</div>
</section>
"""

    chains = hotel.get("chains") or []
    countries = hotel.get("countries") or []
    cities = hotel.get("cities") or []
    exclusive_rows = (hotel.get("exclusive") or {}).get("rows") or []
    advantage = hotel.get("advantage") or {}

    body = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(supplier_id)} {esc(supplier_name)} 供应商分析报告</title>
<style>
{css}
</style>
</head>
<body>
<nav class="rail">
  <div class="brand">SUPPLIER REPORT</div>
{nav_html}
</nav>
<header class="top">
  <h1><span class="num">{esc(supplier_id)}</span> {esc(supplier_name)} 供应商分析报告</h1>
  <div class="scope">
    数据范围 {esc(data.get("start"))} ~ {esc(data.get("end_inclusive"))} · 创建时间口径 · Confirm + Cancel（含当天取消）· Rebook = 1 · Overseas API<br>
    报告生成于 {esc(data.get("generated_on"))} · 金额为 CNY
  </div>
</header>
<main>
<section id="intro">
  <h2>介绍</h2>
  <h3>资源优势</h3>
  <p class="oneline">{esc(intro.get("advantage_oneline") or "")}</p>
  <div class="cards">
    <div class="card"><h4>市场</h4><p>{esc(intro.get("market") or "")}</p></div>
    <div class="card"><h4>品牌</h4><p>{esc(intro.get("brand") or "")}</p></div>
    <div class="card"><h4>壁垒</h4><p>{esc(intro.get("barrier") or "")}</p></div>
  </div>
  <h3>资源质量 <span class="tag">近 30 天参考值 · 全业务线 · 不随报告时间变化</span></h3>
  <p class="oneline">{esc(intro.get("tech_oneline") or "")}</p>
  {tech_table(intro.get("tech_rows") or [], intro.get("tech_caption") or "")}
  <h3>L2L 资源包配置 <span class="tag">截至 {esc(intro.get("l2l_date") or data.get("generated_on"))} 的当前普通配置 · 不含客户特殊配置</span></h3>
  <p class="oneline">{esc(intro.get("l2l_oneline") or "")}</p>
  {l2l_table(intro.get("l2l_rows") or [], intro.get("l2l_caption") or "")}
</section>
<section id="conclusion">
  <h2>整体结论</h2>
  <div class="kpis">
    <div class="kpi"><div class="v num">{ttv_kpi(overview.get("ttv"))}</div><div class="l">总 TTV（CNY）</div></div>
    <div class="kpi"><div class="v num">{num(overview.get("bks"))}</div><div class="l">总 BKS</div></div>
    <div class="kpi"><div class="v num">{num(overview.get("hotels"))}</div><div class="l">有产酒店</div></div>
    <div class="kpi"><div class="v num">¥{num(overview.get("adr"))}</div><div class="l">整体 ADR</div></div>
  </div>
  <div class="verdict">
{chr(10).join(verdict_bits)}
  </div>
</section>
<section id="hotel">
  <h2>酒店资源维度分析</h2>
  <h3>独家资源</h3>
  <p class="oneline">{esc((hotel.get("exclusive") or {}).get("oneline") or "")}</p>
  <p class="note">{esc((hotel.get("exclusive") or {}).get("note") or "")}</p>
  {exclusive_table(exclusive_rows, bool((hotel.get("exclusive") or {}).get("queried")))}
  <h3>优势资源</h3>
  <p class="oneline">{esc(advantage.get("oneline") or "")}</p>
  {advantage_table(advantage.get("rows") or [], advantage.get("caption") or "")}
  <h3>资源优势方 <span class="tag">阈值：占该资源全体供应商 TTV ≥ {esc(threshold_label)}</span></h3>
  <p class="oneline">{esc(hotel.get("share_oneline") or "")}</p>
  {share_html}
  <h3>Chain 集团（Top 10）</h3>
  <p class="oneline">{esc(hotel.get("chain_oneline") or "")}</p>
  {dim_table(chains, chain_headers, adr_base, "集团", 10, hotel.get("chain_caption") or "", separate=True)}
  <h3>Star Rating 星级</h3>
  <p class="oneline">{esc(hotel.get("star_oneline") or "")}</p>
  {dim_table(hotel.get("stars") or [], star_headers, adr_base, "星级", None, hotel.get("star_caption") or "")}
  <h3>Country 国家</h3>
  <p class="oneline">{esc(hotel.get("country_oneline") or "")}</p>
  {dim_table(countries, country_headers, adr_base, "国家", 10, hotel.get("country_caption") or "", separate=True)}
  <h3>City 城市（Top 15）</h3>
  <p class="oneline">{esc(hotel.get("city_oneline") or "")}</p>
  {dim_table(cities, city_headers, adr_base, "城市", 15, hotel.get("city_caption") or "", separate=True)}
  <div class="summary">{esc(hotel.get("summary") or "")}</div>
</section>
{client_html}
<section id="pattern">
  <h2>预订模式分析</h2>
  <h3>MealType 餐型</h3>
  <p class="oneline">{esc(pattern.get("meal_oneline") or "")}</p>
  {meal_table(pattern.get("meals") or [], adr_base)}
  <h3>LOS 入住晚数</h3>
  <p class="oneline">{esc(pattern.get("los_oneline") or "")}</p>
  {span_table(pattern.get("los") or [])}
  <h3>LeadTime 提前预订天数</h3>
  <p class="oneline">{esc(pattern.get("lt_oneline") or "")}</p>
  {span_table(pattern.get("lt") or [])}
  <div class="summary">{esc(pattern.get("summary") or "")}</div>
</section>
<p class="footnote">{esc(data.get("footnote") or "").replace(chr(10), "<br>")}</p>
</main>
<script>
  const links = [...document.querySelectorAll('nav.rail a')];
  const sections = links.map(a => document.querySelector(a.getAttribute('href')));
  const mark = () => {{
    const y = window.scrollY + 120;
    let current = 0;
    sections.forEach((s, i) => {{ if (s && s.offsetTop <= y) current = i; }});
    links.forEach((a, i) => a.classList.toggle('active', i === current));
  }};
  document.addEventListener('scroll', mark, {{ passive: true }});
  mark();
</script>
</body>
</html>
"""
    return body


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("data_json")
    parser.add_argument("-o", "--output", required=True)
    args = parser.parse_args()
    data = json.loads(Path(args.data_json).read_text(encoding="utf-8"))
    html_text = render(data)
    for header in EXCLUSIVE_HEADERS + ADVANTAGE_HEADERS:
        if header not in html_text:
            raise SystemExit(f"渲染结果缺少固定列：{header}")
    if "font-family: \"Segoe UI\", \"Microsoft YaHei\", sans-serif;" not in html_text:
        raise SystemExit("渲染结果没有使用当前版字体")
    if "数据附件" in html_text:
        raise SystemExit("HTML 不再包含数据附件")
    Path(args.output).write_text(html_text, encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
