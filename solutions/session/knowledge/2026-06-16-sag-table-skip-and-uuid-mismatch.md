---
title: "SAG重构中表跳过与UUID不匹配"
module: "ticketpilot/sag"
tags: [SAG重构, SQL JOIN, 数据不一致, eval-alignment]
problem_type: "knowledge"
severity: "medium"
root_cause: "文档平均长度过小(111-141 chars)导致跳过sag_events表；评估数据中golden UUID是占位符(11111111-...)与DB真实UUID不匹配"
solution: "分析文档长度决定跳过事件表直接用chunk做event；构建SQL JOIN并行检索管道；用内容相似度匹配重映射eval UUID"
created: "2026-06-16"
last_updated: "2026-06-16"
occurrence_count: 1
status: active
---

# SAG重构中表跳过与UUID不匹配

## 问题现象
SAG重构计划设计了3张表(events, entities, chunk_entities)，但文档平均只有111-141字符，event提取后跟chunk内容完全相同。同时golden_expectations.csv中的doc UUID是占位符，与DB真实UUID不匹配，导致A/B对比recall恒为0%。

## 根本原因
1. 没有先检查数据维度就设计表结构
2. golden CSV在seed数据之前生成，UUID是假的

## 解决方案
1. 砍掉sag_events表，直接用chunk做event角色
2. 用difflib.SequenceMatcher内容相似度匹配重新映射UUID
3. **教训：先查数据维度再设计架构**

## 验证方法
- SAG模块72测试全通过
- golden重映射后match rate应>50%

## 可复用模式
- 短文档(<200 chars)场景：event=chunk，不需要独立事件表
- 评估数据UUID必须在seed之后生成，不能用占位符
