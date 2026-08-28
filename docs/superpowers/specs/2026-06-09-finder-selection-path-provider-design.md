# QuickCookies Finder Selection Path Provider Design

Date: 2026-06-09
Status: Draft for review

## Goal

在不改变当前用户体验的前提下，把 Finder 当前选中文件路径的发现能力从预览主链路中收口成独立、可替换、可测试的边界。

本轮目标不是替换 AppleScript，也不是重写 Finder-follow 机制。本轮只处理“谁来提供 Finder 当前路径”这一层。

## Problem Statement

当前 QuickCookies 的 Finder 路径发现能力直接依赖 `FileDetector.getSelectedFilePath()`，并且这个静态入口被多个调用点直接使用：

- `QuickCookies/Core/Preview/PreviewTargetResolver.swift`
- `QuickCookies/Core/FinderMenuIntegration.swift`
- `QuickCookies/UI/QuickLookOverlay.swift`

这带来三个实际问题：

1. 路径发现能力和预览主链路绑死，后续无法低风险替换为更优实现。
2. `FileDetector` 当前是系统耦合实现，难以稳定补自动化测试。
3. 同一个能力在 resolver、menu bar、overlay watcher 中以不同方式被直接调用，边界不清晰。

因此，本轮的真正目标不是“优化 Finder 轮询”，而是先把 Finder 路径发现层从调用方里拔出来。

## Non-Goals

本轮明确不做：

- 不替换 `NSAppleScript` 为 AXObserver、ScriptingBridge 或其他机制
- 不改 `QuickLookOverlay.getSourceRect()` 的 AX 坐标获取逻辑
- 不改 Finder-driven scoped watcher 策略
- 不改窗口焦点、动画、几何或 UI
- 不改变当前 Finder 打开、菜单栏打开、Finder-follow 的外部行为
- 不引入新的预览格式或新的编辑能力

## Recommended Approach

推荐采用“抽象先行、行为不变、调用点逐步迁移”的方案。

### Option A: Discovery Abstraction First (Recommended)

做法：

- 引入统一抽象 `FinderSelectionPathProviding`
- 用 `AppleScriptFinderSelectionPathProvider` 作为默认生产实现
- 调用方改为依赖 provider 注入，而不是依赖 `FileDetector` 静态函数
- `FileDetector.getSelectedFilePath()` 暂时保留为兼容外壳

优点：

- 风险最低
- 不改变当前用户体验
- 能立即提升可测试性
- 为下一轮替换底层机制建立稳定边界

缺点：

- 本轮不会直接消除 AppleScript 依赖
- 用户感知层面不会立刻有变化

### Option B: Abstraction + Dual Implementation

做法：

- 一边抽象边界
- 一边接入第二套候选实现并做 runtime fallback

优点：

- 更快验证替代路线

缺点：

- 会把不确定性直接带进主链路
- 调试范围更大
- 与当前“先打磨现有产品、避免新增不确定性”的方向不一致

### Option C: Direct Replacement

做法：

- 不先抽象，直接把现有发现机制替换为新机制

优点：

- 理论上一步到位

缺点：

- 当前代码边界尚未收口，替换风险高
- 很容易把问题扩散到 overlay、resolver、menu bar 和测试链路

## Decision

采用 Option A。

理由：

- 当前阶段最重要的是收口现有产品，而不是在主链路里继续做机制试验。
- 只有先把路径发现边界抽出来，下一轮评估 AppleScript / observer / hybrid 路线时才有安全落点。

## Architecture

### New Boundary

新增统一抽象：

- `FinderSelectionPathProviding`

职责：

- 只回答一个问题：当前 Finder 语义下应该返回哪个文件路径
- 输出保持为 `Result<String, FileDetector.DetectError>`

这个抽象不负责：

- 预览目标解析
- 窗口展示
- source rect 坐标获取
- Finder-follow 时机控制

### Default Production Implementation

新增默认生产实现：

- `AppleScriptFinderSelectionPathProvider`

职责：

- 继续使用当前 AppleScript 路径发现逻辑
- 保留 Finder 是否运行检查
- 保留“空字符串 = 无选中项”的语义
- 保留当前错误类型与错误文案来源

这意味着：

- 本轮对外行为不变
- 只是把 AppleScript 实现藏到统一边界后面

### Compatibility Layer

保留：

- `FileDetector.getSelectedFilePath()`

新角色：

- 不再作为真正的业务依赖入口
- 降级为兼容外壳，内部转发到默认 live provider

这样做的目的：

- 缩小首轮改动面
- 保留回退路径
- 避免一次性改散所有调用方

## File-Level Design

### `QuickCookies/Core/FileDetector.swift`

本轮首要改造文件。

调整方向：

- 在本文件内先引入 `FinderSelectionPathProviding`
- 在本文件内引入 `AppleScriptFinderSelectionPathProvider`
- `FileDetector.getSelectedFilePath()` 改为调用默认 live provider

这样做的原因：

- 首轮不需要额外拆文件，避免工程改动过大
- 让边界收口先发生，再考虑物理拆文件

### `QuickCookies/Core/Preview/PreviewTargetResolver.swift`

改造方向：

- 持有 `finderSelectionPathProvider`
- 默认注入 `AppleScriptFinderSelectionPathProvider()`
- `.finderSelection` 分支改为向 provider 要路径

兼容策略：

- provider 层错误仍折叠为 `PreviewTargetError.noFinderSelection`
- 不改变当前 session / overlay 的业务语义

### `QuickCookies/Core/FinderMenuIntegration.swift`

改造方向：

- 持有 `finderSelectionPathProvider`
- 菜单栏打开逻辑通过 provider 获取路径

兼容策略：

- 保留当前针对 Finder 未运行、无选中文件、脚本执行失败的用户可见错误提示
- 不把 menu bar 的错误策略强行改成 resolver 的业务折叠策略

### `QuickCookies/App/AppDelegate.swift`

改造方向：

- 创建一个共享 live provider
- 注入给 `PreviewTargetResolver`
- 注入给 `FinderMenuIntegration`

这样能保证：

- 所有长期主链路共用同一个默认实现
- 后续替换时只需要在注入点切换，而不是全局搜静态调用

### `QuickCookies/UI/QuickLookOverlay.swift`

改造方向：

- `finderSelectionPollingController` 使用 provider 作为 `detectSelectionPath` 来源

不变部分：

- scoped watcher 生命周期
- refresh burst
- frontmost fallback
- `getSourceRect()` 的 AX 实现

本轮重点是：

- 改路径来源
- 不改跟随策略

## Error Handling

本轮保留现有错误分层：

- provider 层保留 `FileDetector.DetectError`
- resolver 层继续把 `.finderSelection` 失败折叠为 `PreviewTargetError.noFinderSelection`
- menu bar 层继续使用用户可见错误提示

原因：

- 这轮目标是边界收口，不是统一所有错误语义
- 如果现在连错误模型一起重构，会扩大风险面

## Testing Strategy

### New Tests

新增：

- `QuickCookiesTests/FinderSelectionPathProviderTests.swift`

目标：

- 让原本系统耦合很强的 `FileDetector` 路径发现逻辑变成可注入、可验证的纯逻辑分支

建议覆盖：

- Finder 未运行时返回 `.finderNotRunning`
- script 初始化失败时返回 `.scriptingBridgeError`
- script 执行失败时返回 `.scriptingBridgeError`
- script 返回空字符串时返回 `.noFileSelected`
- script 返回路径时成功

### Supporting Injection

为实现稳定测试，provider 内部需要具备最小可注入点，例如：

- `isFinderRunning`
- `selectionScriptFactory`
- `executeScript`

这些注入点只服务测试，不改变生产调用方式。

### Existing Tests To Update

需要补或调整的现有测试：

- `QuickCookiesTests/PreviewCoordinatorTests.swift`
- `QuickCookiesTests/PreviewLaunchRequestTests.swift`
- 视改动范围补充 menu integration 相关测试

原则：

- 优先补纯逻辑、可注入测试
- 不新增依赖真实 Finder 当前状态的脆弱测试

## Implementation Phases

### Phase 1: Introduce Abstraction Without Behavioral Change

内容：

- 新增 provider 协议
- 新增 AppleScript live provider
- 保留 `FileDetector` 兼容外壳

完成标准：

- 不改任何上层调用方时，现有行为保持不变

### Phase 2: Migrate Resolver and Menu Bar Call Sites

内容：

- `PreviewTargetResolver` 改为依赖 provider
- `FinderMenuIntegration` 改为依赖 provider
- `AppDelegate` 统一注入 live provider

完成标准：

- hotkey / menu bar / URL scheme 行为不变
- 菜单栏错误提示不变

### Phase 3: Migrate Overlay Polling Path Source

内容：

- `QuickLookOverlay` / `FinderSelectionPollingController` 改为通过 provider 获取 Finder path

完成标准：

- Finder-driven 跟随不退化
- direct-path 不误启 polling
- 快速切换文件不退化

### Phase 4: Add Tests and Docs

内容：

- 新增 provider 层测试
- 更新现有可行性/维护文档

完成标准：

- 至少一层稳定自动化测试覆盖 Finder 路径发现错误分支

## Acceptance Criteria

这一阶段完成时，必须满足：

1. 现有用户体验不变。
2. Finder 文件发现能力有统一抽象入口。
3. 默认生产实现仍然是 AppleScript。
4. 预览主链路、菜单栏链路、Finder-follow 链路不再直接依赖 `FileDetector` 静态函数。
5. provider 层关键错误分支具备稳定自动化测试。
6. 文档明确说明本轮是发现层收口，而不是底层机制替换。

## Stop Conditions

实施中如果出现以下情况，应停止并重新评估：

- Finder-driven 跟随体验退化
- 菜单栏打开选中文件行为变化
- 现有错误提示文案被意外改变
- overlay 焦点、动画、窗口几何被连带影响
- 为了抽象而把代码拆得更散、更难维护

## Why This Matters

本轮完成后，我们仍然没有替换 AppleScript。

但我们会第一次拥有：

- 一个统一的 Finder 路径发现边界
- 一个可替换的默认生产实现入口
- 一层稳定可测的发现能力单元

这使得下一轮评估更优方案时，工作会发生在稳定边界上，而不是继续侵入预览主链路。
