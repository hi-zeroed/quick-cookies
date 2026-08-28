# Docs Index

本目录只保留当前仍有长期维护价值的文档。

## 当前优先阅读

1. [preview-kernel-architecture.md](/Users/jiangwei/Git/QuickCookies/docs/preview-kernel-architecture.md:1)
   当前预览链路的工程维护基线。涉及入口、会话、窗口壳、状态所有权时，优先参考这份。

2. [design.md](/Users/jiangwei/Git/QuickCookies/docs/design.md:1)
   产品级概览，说明 QuickCookies 是什么、解决什么问题、体验边界是什么。

3. [preview-manual-test-checklist.md](/Users/jiangwei/Git/QuickCookies/docs/preview-manual-test-checklist.md:1)
   预览链路相关改动后的手工回归清单。

4. [preview-interaction-redesign-implementation-plan.md](/Users/jiangwei/Git/QuickCookies/docs/preview-interaction-redesign-implementation-plan.md:1)
   最近一轮预览交互收口的实施记录。若与历史方案稿冲突，以这份和 `preview-kernel-architecture.md` 为准。

5. [preview-icon-assets.md](/Users/jiangwei/Git/QuickCookies/docs/preview-icon-assets.md:1)
   文件预览链路的文件类型图标资产清单与接入规则。

## 测试相关参考

1. [xctest-feasibility.md](/Users/jiangwei/Git/QuickCookies/docs/xctest-feasibility.md:1)
   XCTest 接入范围与可测试性分层说明。

2. [2026-06-06-xctest-bootstrap.md](/Users/jiangwei/Git/QuickCookies/docs/superpowers/plans/2026-06-06-xctest-bootstrap.md:1)
   XCTest 初始落地过程记录，主要用于测试体系历史背景参考。

## 其它文件

- `setting.html`
  独立静态文件，不作为预览架构或产品设计基线文档。

- [preview-interaction-redesign.md](/Users/jiangwei/Git/QuickCookies/docs/preview-interaction-redesign.md:1)
  保留重构前问题分析与阶段性方案推演，主要用于理解为什么要做这轮收口；不要把它当作当前实现的唯一真值文档。

## 维护规则

1. 如果文档描述的是“当前实现应该遵守什么”，优先更新 `preview-kernel-architecture.md`。
2. 如果文档描述的是“本轮预览交互已经怎么落地”，优先更新 `preview-interaction-redesign-implementation-plan.md`。
3. 如果文档描述的是“产品定位与体验边界”，优先更新 `design.md`。
4. 不要把一次性重构计划、已完成迁移过程、历史讨论稿重新堆回本目录顶层。
