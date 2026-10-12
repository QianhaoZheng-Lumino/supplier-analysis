# supplier-analysis

酒店 Overseas API 供应商分析（Agent Skill，多 runtime）。  
仓库：<https://github.com/QianhaoZheng-Lumino/supplier-analysis>

**前提：** 你已有查数 MCP（`user-data-mcp`）和自己的 `agent_user_key`。本仓库不发 key、不开通权限。

## 给同事 Agent 的安装提示词（复制即用）

把下面整段发给你的 skills-aware agent（Cursor / Claude Code / Codex 等均可）：

```text
请把公开 GitHub 仓库 https://github.com/QianhaoZheng-Lumino/supplier-analysis 安装为 supplier-analysis Skill（Public，无需登录即可 clone）。
按当前 runtime 的 skills 目录克隆，根下必须直接有 SKILL.md（不要多套一层文件夹）：
- Cursor：$HOME/.cursor/skills/supplier-analysis/（Windows 为 %USERPROFILE%\.cursor\skills\supplier-analysis）
- Claude Code：$HOME/.claude/skills/supplier-analysis/
- Codex：$HOME/.agents/skills/supplier-analysis/
我已配置 user-data-mcp（自己的 key）。安装后用于酒店 Overseas API 供应商分析；先读 README.md「使用前注意事项」，再按 SKILL.md 执行。
```

当前 runtime 没有 skills 目录时：把本仓库 `SKILL.md` 作为参考资料贴进对话即可（MCP 仍要自备）。

也可自己执行（Cursor / Windows）。**不要**用 Customize → From GitHub Repository / Remote Rule：本仓没有 `.cursor-plugin/marketplace.json`，`SKILL.md` 在仓库根，UI 导入不会当成 Skill。

Git 常常不在 PATH。目录已存在时用 `pull`，不要再 `clone`。ZIP 解压不要多一层 `supplier-analysis-main`（最终必须是 `...\supplier-analysis\SKILL.md`）。

```powershell
$git = "C:\Program Files\Git\cmd\git.exe"
if (-not (Test-Path $git)) { $git = "git" }
$dest = "$env:USERPROFILE\.cursor\skills\supplier-analysis"
if (Test-Path (Join-Path $dest "SKILL.md")) {
  & $git -C $dest pull --ff-only
} else {
  & $git clone https://github.com/QianhaoZheng-Lumino/supplier-analysis.git $dest
}
```

MCP：Cursor Settings → MCP，或自己的 `~/.cursor/mcp.json`。URL / `agent_user_key` 向数据平台要；本仓不发 key。

装完请**新开一轮对话**（必要时重启 Cursor）。不要把本仓库当普通项目打开就指望自动生效。

## 使用前注意事项

1. MCP 必须已连上，且工具含 `execute_sql`。不可用或未认证就停，禁止手写 SQL。
2. 用自己的 `agent_user_key`。不要把 `mcp.json` 或 key 写进本仓库、报告，或提交到 GitHub。
3. 缺供应商或时间范围先问再查。三个阈值没提就用默认：资源优势方 10%，优势酒店 1.30 倍，独家 BKS ≥ 10。
4. 一次 `execute_sql` 等于一个 `sql/` 文件。先 Read 原文，只替换占位符。查询只传 `sql`、`timeout_seconds`、`original_question`，不传 `tables`。`original_question` 原样传入用户本轮提问。
5. 每一波最多 5 条 `execute_sql`，返回后自己接着跑下一波，直到 HTML 和 Excel 都生成。不要因为满 5 条就停下来等用户。`11`、`12`、`12b` 的超时用 300 秒，其余 120 秒。
6. HTML 只由 `python scripts/render-report.py` 生成。需要本机 Python 3。Excel 与 HTML 同名，在对话里给路径，不写进 HTML。
7. 口径以 `SKILL.md` 为准，章节以 `docs/report.md` 为准，数据稿以 `docs/report-data.md` 为准。

报告写到当前工作区 `supplier-analysis-reports/`。这些报告含真实产量，不要提交到本仓库。
