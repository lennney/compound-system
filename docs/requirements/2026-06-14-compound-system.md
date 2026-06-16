# Compound System — Requirements

> **状态**: Draft | **日期**: 2026-06-14 | **作者**: Hermes Agent

## 背景

AI 编码 Agent（Hermes、Claude Code、Codex）是无状态的——每次会话从零开始，不学习历史错误和决策。Compound Engineering Plugin（18k+ star）证明了"任务后反思"的价值，但存在成本高、缺分级、存储单一等问题。

我们需要一个**跨平台、低成本、结构化**的错误学习和知识积累系统。

## 核心需求

### R1: 任务后自动反思（Post-Task Reflection）
- 任务完成后自动检测是否需要反思
- 三级成本过滤：Rule Gate → Quick Reflect → Deep Reflect
- 记录**排查过程**（不只是结果）

### R2: 结构化存储（Structured Storage）
- Markdown + YAML frontmatter 文件格式
- 双轨制：Bug Track + Knowledge Track
- 目录结构：`solutions/bugs/` + `solutions/knowledge/` + `solutions/patterns/`

### R3: 智能检索（Smart Retrieval）
- Grep 预过滤 frontmatter（零成本）
- 语义搜索兜底
- 自动去重（overlap 检测）

### R4: 跨平台兼容（Cross-Platform）
- 纯文件系统 + Shell 脚本，无 Python 依赖
- 支持 Hermes / Claude Code / Codex / Cursor
- 每个平台有对应的 Skill/Plugin 入口

### R5: 生命周期管理（Lifecycle）
- 文档过时检测
- 自动合并重复文档
- 频次统计 + 信任评分

## 不做的（明确排除）

- ❌ 不做 Web UI（纯 CLI + 文件）
- ❌ 不做数据库依赖（纯文件系统）
- ❌ 不做实时同步（各平台独立，文件可 git 共享）
- ❌ 不做 LLM fine-tuning（只做 prompt 级别的学习）

## 验收标准

1. 任务完成后，系统自动判断是否需要反思（Level 0 规则过滤准确率 > 80%）
2. 反思结果写入 `solutions/` 目录，格式为 Markdown + YAML frontmatter
3. 遇到类似错误时，grep 预过滤能在 <10ms 内找到相关文档
4. 在 Claude Code 中安装后，`/ce-compound` 等效命令可用
5. 在 Hermes 中，error-learning skill 自动调用 compound system
6. 文档数量 > 20 时，生命周期管理能识别过时文档

## 技术约束

- **零依赖**：只用 bash + grep + sed + yaml（Python 可选）
- **文件格式**：Markdown + YAML frontmatter（所有编辑器可读）
- **存储位置**：项目根目录 `solutions/` 或 `~/.hermes/solutions/`
- **模型调用**：可选（Level 1/2 需要 LLM，Level 0 纯规则）
