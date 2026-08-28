# QuickCookies 预览交互与文件导航重构方案

日期：2026-06-09
状态：当前实现已收口为 Finder-driven scoped watcher + direct-path no watcher；视觉效果仍需手动验收
范围：预览窗口交互、Finder 文件发现、上下键导航、窗口几何与贴边行为

说明：

- 本文同时保留重构前问题分析、方案推演与实施约束。
- 涉及“当前实现到底是什么”时，以 `docs/preview-kernel-architecture.md` 和 `docs/preview-interaction-redesign-implementation-plan.md` 为准。
- 如果本文中的历史推演段落与当前代码冲突，以前两份文档和实际代码为准。

## 目标

本阶段不新增压缩包、SQLite 或其他预览格式。

本阶段目标是打磨现有预览链路，而不是新增预览格式。最新方案采用“双路径交互模型”：Finder/热键路径保留 Finder 焦点与选中态，并在窗口可见期间保持 scoped watcher；全局事件只做刷新加速；direct path 路径让 QuickCookies 成为可交互窗口，并使用内部目录导航。

目标体验：

- 热键从 Finder 打开时，Finder 继续保持焦点，上下键和鼠标选择仍作用于 Finder。
- 关闭统一依赖全局热键 toggle，不额外增加 `Esc` 关闭记忆点。
- Services、URL Scheme、内部导航等 direct path 打开时，QuickCookies 可以成为可交互窗口。
- direct path 窗口拖拽不需要先额外点击一次。
- 窗口边界等于实际可见卡片边界，贴边和屏幕顶部自动展开行为按真实窗口尺寸工作。
- Finder 路径不再对所有入口一刀切启动 150ms 常驻轮询，而是仅在 Finder-driven 会话可见期间保留 scoped watcher，并在 Finder 前台发生上下键或鼠标选择事件后做 refresh burst 加速。
- Services、URL Scheme、内部导航等 direct path 入口不启动 Finder selection polling。

## 当前执行状态

截至 2026-06-09：

- 阶段 1：窗口聚焦策略已改为按入口分流。Finder/热键路径保持 Finder 焦点；direct path 路径允许 QuickCookies 成为 key window。
- 阶段 2：`PreviewNavigationContext` 已接入，direct path 预览态 `Up` / `Down` 使用内部当前目录相邻文件导航。
- 阶段 3：Finder selection follow 已收口为 Finder-driven scoped watcher；键盘/鼠标选择事件只负责 refresh burst 加速；旧的 Finder key forwarding 仅作为显式 fallback 代码保留，默认不可达。
- 阶段 4：窗口几何已实施，稳定态窗口尺寸不再包含 40pt 透明外圈，动画 source rect 外扩保留为独立逻辑。

阶段 0 当前证据：

- 记录文件：`docs/visual-baselines/preview-interaction-redesign/README.md`
- 自动截图尝试因当前环境 `AXIsProcessTrusted()` 不满足而进入 Onboarding，未得到真实预览窗口截图。
- 当前环境没有辅助功能权限时应用会进入 Guide/Onboarding，无法通过 URL Scheme 自动获得真实预览截图；阶段 4 的阴影、圆角、毛玻璃、动画和贴边行为需要手动验收。

已跑过的阶段 1-3 自动验证：

- `./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewNavigationContextTests`
- `./scripts/run-focused-xctest.sh QuickCookiesTests/QuickLookOverlayStateTests`
- `./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewLaunchRequestTests`
- `xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath build/xctest-derived/preview-interaction-redesign build-for-testing`

## 重构前实现证据

### 1. 普通预览窗口默认不能成为 key window

重构前 `QuickLookPanel` 是否能成为 key window 由 `canBecomeKeyProvider` 控制：

- `QuickCookies/UI/QuickLookOverlay.swift`
- `QuickLookPanel.canBecomeKey`
- `QuickLookPanel.canBecomeMain`

重构前策略在 `PreviewOverlayKeyWindowPolicy` 中：

```swift
if mode == .edit {
    return true
}

return renderType == .office
```

这意味着普通 Markdown、代码、纯文本、图片、PDF 预览态默认不能成为 key window。这个设计让 Finder 可以保持前台，从而继续吃到上下键，但也让 QuickCookies 窗口自身无法像普通窗口一样交互。

### 2. 打开窗口时刻意不抢焦点

`showOverlay(session:)` 中通过 `orderFrontRegardless()` 展示窗口，并有注释说明保持 Finder 在前台：

```swift
// 先让预览窗口以完全透明状态挂载，置顶显示但不抢占焦点（保持 Finder 在前台）
previewPanel.orderFrontRegardless()
```

这解释了重构前为什么普通预览窗口打开后不是 key window。

### 3. Esc 与上下键依赖 event monitor 和 Finder 转发

重构前关闭和导航行为由 local/global event monitor 承担：

- local monitor 处理窗口成为 key 时的 `Esc`
- global monitor 在 Finder 前台时捕获 `Esc`
- 上下键通过 `forwardFinderNavigationIfNeeded(for:)` 转发给 Finder
- `sendKeyToFinder(keyCode:)` 使用 `CGEvent.postToPid` 把上下键发回 Finder

这套机制的核心假设是 Finder 继续拥有键盘焦点。它可以支持 Finder 选择变化，但代价是 QuickCookies 自己不像一个正常聚焦窗口。

### 4. Finder selection 依赖 150ms 轮询

重构前 `FinderSelectionPollingController.start(interval:)` 默认间隔是 `0.15` 秒：

```swift
func start(interval: TimeInterval = 0.15)
```

重构前 `showOverlay(session:)` 中无条件启动：

```swift
finderSelectionPollingController.start()
```

轮询内部会在 Finder 前台时调用：

- `FileDetector.getSelectedFilePath()`
- `QuickLookOverlay.getSourceRect()`

路径发现使用 `NSAppleScript` 获取 Finder selection；动画源位置使用 `AXUIElement` 查询 Finder 选中项位置。

### 5. direct path 入口也会进入窗口后的 polling 生命周期

项目已经区分入口 source：

- `.hotkey`
- `.service`
- `.urlScheme`
- `.menuBar`
- `.finderSync`

也区分路径意图：

- `.finderSelection`
- `.direct(path:)`

Finder Sync 菜单已经能直接拿到 `selectedItemURLs()` 并通过 URL Scheme 打开主 App。Services 与 URL Scheme 也属于 direct path 入口。

但是重构前窗口展示后仍会无条件启动 polling。对于 `.service` 和 `.urlScheme`，后续请求会被 `PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for:)` 丢弃，但 polling 本身已经启动，属于无效成本。

### 6. 重构前真实窗口尺寸包含 40pt 外围透明边距

重构前 `QuickLookOverlay` 几何实现有：

```swift
private let windowPadding: CGFloat = 40
```

窗口内容尺寸计算中会加入 `windowPadding * 2`：

```swift
width: targetContentWidth(for: screenVisibleFrame) + windowPadding * 2
height: screenVisibleFrame.height * 0.88 + windowPadding * 2
```

同时 `ContentView` 根视图还有：

```swift
.padding(40)
.background(Color.clear)
```

所以 AppKit 认知里的窗口边界大于用户看到的卡片边界。拖到屏幕边缘或顶部触发系统窗口行为时，系统按透明外圈计算，用户看到的卡片就会永远小一圈。

## 根因判断

当前问题不是单个实现 bug，而是交互模型本身的取舍导致的。

旧模型：

```text
Finder 保持焦点
QuickCookies 非 key 浮层展示
上下键发给 Finder
轮询 Finder selection
QuickCookies 根据 Finder selection 切换文件
```

这个模型服务于“Finder 上下键切换文件，预览跟随变化”，但它带来以下代价：

- QuickCookies 预览态无法成为正常 key window。
- `Esc` 关闭依赖全局监听，不是窗口自然行为。
- 拖拽需要先完成激活或命中处理，体感需要多一次点击。
- 上下键导航依赖 Finder、AppleScript、AX、CGEvent 多个系统耦合点。
- direct path 入口也被卷入 Finder polling 生命周期。
- 透明 padding 被放进真实窗口尺寸，破坏贴边和系统窗口行为。

因此，仅仅降低 polling 频率不能解决根因。更优方案应该改变主交互模型，并把 Finder-follow 收口成只对 Finder-driven 会话生效的 scoped watcher。

## 新方案：双路径交互模型

当前采用的新模型：

```text
Finder/Hotkey:
  一次性解析 Finder selection
  QuickCookies 非 key 浮层展示
  Finder 继续保持焦点
  overlay 可见期间启动 scoped Finder selection watcher
  Finder 上下键/鼠标选择事件触发 refresh burst 加速

Direct path:
  直接打开已知路径
  QuickCookies 窗口可成为 key window
  Up/Down 使用内部目录导航
  不启动 Finder selection polling

所有路径:
  不再对所有入口无差别启动 Finder selection polling
  关闭统一依赖热键 toggle 或窗口内显式关闭按钮
```

核心变化：

- Finder/热键路径保留 Finder 的蓝色选中态，用户能清楚看到当前选中的文件。
- QuickCookies 不再为了所有入口无差别地跟随 Finder selection 启动持续轮询；只有 Finder-driven 会话会在窗口可见期间保留 scoped watcher。
- 鼠标点选 Finder 中另一个文件、或 Finder 中上下键切换文件后，QuickCookies 会先通过事件触发 refresh burst 加速，再由 scoped watcher 兜底收敛。
- direct path 路径不依赖 Finder selection，内部导航使用 `.internalNavigation` 和 direct path request。
- `Esc` 不作为本阶段关闭入口；关闭统一靠热键 toggle，减少记忆点。

## PreviewNavigationContext

新增一个纯逻辑导航上下文，负责当前目录内的文件切换。

建议职责：

- 接收当前文件路径。
- 读取当前文件所在目录的直接子项。
- 过滤目录和明显不适合预览的文件。
- 按稳定规则排序。
- 找到当前文件 index。
- 提供 previous 和 next 文件路径。

首版排序策略：

- 使用文件名本地化标准排序。
- 不尝试复刻 Finder 当前视图排序。
- 不递归目录。
- 不读取文件内容。

首版过滤策略：

- 排除目录。
- 排除隐藏文件可作为后续选项，首版可以先保留隐藏文件，避免与用户真实目录不一致。
- 不在导航阶段做昂贵二进制读取。
- 是否可预览仍交给现有 `PreviewTargetResolver` 和 `FileTypeClassifier`。

这样可以保持导航逻辑轻量，并复用现有分类与错误兜底。

## 键盘行为

新默认行为：

- Finder/热键路径：
  - `Up` / `Down`：由 Finder 消费，Finder selection 变化后 QuickCookies 单次刷新。
  - 鼠标点选 Finder 文件：Finder selection 变化后 QuickCookies 单次刷新。
  - 关闭：再次触发全局热键。
- direct path 路径：
  - `Up`：切换到当前目录上一个文件。
  - `Down`：切换到当前目录下一个文件。
  - 关闭：热键 toggle 或窗口内显式关闭按钮。
- 编辑模式中：
  - 上下键留给文本编辑器，不切换文件。
- Office 或未来需要自身键盘交互的重型预览：
  - 可以按 render capability 决定是否禁用上下键文件导航。

不再默认执行：

- 默认把上下键通过 `CGEvent.postToPid` 发给 Finder。
- 默认对所有入口启动 Finder selection polling 定时器。
- 把 `Esc` 当作预览关闭主路径。

## 窗口聚焦策略

新默认策略：

- Finder/热键路径保持 non-key 浮层模型，让 Finder 继续显示蓝色选中态并接收上下键。
- Services、URL Scheme、内部导航等 direct path 路径允许成为 key window。
- 编辑模式允许成为 key window。
- 预览窗口是否聚焦由 `PreviewOverlayKeyWindowPolicy` 和 `PreviewOverlayFocusActivationPolicy` 按 source 决定。

当前已接入：

- `PreviewOverlayKeyWindowPolicy.canBecomeKey` 对 Finder-driven source 返回 false，对 direct path source 返回 true。
- `PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation` 对 Finder-driven source 返回 false，对 direct path source 返回 true。
- 全局 Esc 监听不再作为普通预览关闭主路径。
- Finder 前台时的全局上下键转发不再作为主路径，默认仅在事件后刷新 selection。

## 文件发现策略

### 保留 direct path 入口

以下入口已经或应该直接传入路径：

- Services
- URL Scheme
- Finder Sync contextual menu
- 未来 Finder Sync toolbar item

这些入口不应启动 Finder selection polling。

### Hotkey / MenuBar 初始文件发现

对于全局热键和菜单栏“打开选中文件”，仍然需要一次性解析 Finder selection。

首版继续复用：

- `FileDetector.getSelectedFilePath()`

初始打开只做一次解析。窗口打开后，Finder-driven 会话会启动 scoped watcher；direct path 会话不启动 polling。Finder 前台的键盘/鼠标选择事件会触发 refresh burst 作为加速路径。

### Finder-follow 的当前实现

当前不做 AXObserver 完整事件订阅。Finder-driven 会话仍保留 150ms scoped watcher，并叠加轻量的全局事件监听作为加速路径：

- Finder 前台 `Up` / `Down` keyDown 后，延迟一次刷新 Finder selection。
- Finder 前台 leftMouseUp 后，延迟一次刷新 Finder selection。
- scoped watcher 启动时允许 Finder、`nil`、以及当前 QuickCookies bundle identifier 作为 frontmost fallback，避免 AppKit 在过渡时把 overlay 自己或未知进程误报成前台导致漏刷新。
- `Esc`、带 Command/Option/Control 的按键、非 Finder 前台事件不会触发刷新。

这样保留 Finder 高亮与选择体验，同时避免 direct path 被卷入 Finder polling 生命周期。

### 未来 Finder-follow 增强

如果未来仍想支持更完整的“Finder 选中什么，预览自动跟随什么”，应作为独立模式评估。

候选机制：

- AXObserver 监听 Finder selection/focus 变化。
- 在 observer 不稳定时再保留 scoped polling fallback。

但它不应阻塞当前交互模型修复，也不应继续作为默认主路径。

## 窗口几何与边距方案

新原则：

AppKit 窗口尺寸必须等于用户看到的可见卡片尺寸。

但窗口几何不能盲目重构。当前外圈透明留白不是偶然实现，而是有明确 UI 意图：

- `ContentView` 根视图的 `.padding(40)` 注释说明其用于支撑弹簧过冲回弹的防裁剪与阴影扩散。
- `QuickLookOverlay` 的 `windowPadding` 参与打开和关闭动画的 source rect 扩展，用于保持仿射变换中心与起跳大小对齐。
- `README-cn.md` 与 `README.md` 将毛玻璃 HUD、黄金阅读比例、空间轨迹弹簧动效、Finder 图标飞回视为产品体验的一部分。

因此，本阶段不是简单删除 padding，而是要把“可见卡片边界正确”和“现有视觉质感不变形”同时作为约束。

阶段 4 实施记录：

- `windowPadding` 已拆成稳定态外圈和动画外扩两个概念。
- 稳定态窗口尺寸由 `PreviewOverlaySizingPolicy.stableContentSize(...)` 计算，不再加入透明外圈。
- `ContentView` 根视图的外圈 padding 改为 `cardOuterPadding` 参数，overlay 稳定态传入 `0`。
- 打开/关闭动画继续通过 `PreviewOverlaySizingPolicy.animationSourceRect(..., outset: animationOutset)` 保留 source rect 外扩。
- `QuickLookOverlay` 对 preview panel 开启 `hasShadow`，用于补偿去掉稳定态透明外圈后的窗口外部投影。

已调整：

- `targetContentRect` 不再加入 `windowPadding * 2`。
- `ContentView` 根视图不再在 overlay 稳定态使用 `.padding(40)` 作为真实内容外圈。
- 透明留白不再参与真实窗口边界。
- 打开/关闭动画不再直接依赖旧 `windowPadding`，而是依赖独立 `animationOutset`。

自动测试只能覆盖尺寸策略、导航策略和构建正确性。当前环境无法自动捕获真实预览视觉基线，因此视觉效果必须按手测清单确认。

如果阴影和弹簧过冲需要空间：

- 优先尝试把动画所需留白从真实窗口尺寸中拆出来，而不是直接牺牲视觉。
- 可以考虑动画期间使用独立 animation container 或临时扩大动画层，但稳定态窗口 frame 仍等于可见卡片。
- 可以对弹簧参数轻微调参，但不得让窗口打开/关闭出现明显僵硬、闪烁或裁切。
- 阴影、圆角、毛玻璃、内容区边框需要做视觉回归对比，不能重构后 UI 变形。

本阶段优先级：

```text
窗口行为正确
UI 稳定态不变形
动画质感尽量保持
```

如果某个几何改动会导致 UI 明显退化，应停下来重新设计，而不是继续推进。

## 当前实施阶段

### 阶段 1：窗口聚焦分流

目标：

- Finder/热键路径保持 Finder 焦点，保留 Finder 蓝色选中态和上下键选择体验。
- direct path 路径允许 QuickCookies 成为 key window，确保 Services、URL Scheme、内部导航打开后可交互。
- 编辑模式继续允许 QuickCookies 聚焦。
- 不把 `Esc` 作为预览关闭主路径。

改动点：

- `PreviewOverlayKeyWindowPolicy`
- `PreviewOverlayFocusActivationPolicy`
- `showOverlay(session:)` 的展示方式
- local/global event monitor 中与 Finder 前台选择事件相关的逻辑

测试：

- Finder-driven source 不成为 key window。
- direct path source 可以成为 key window。
- 编辑模式可以成为 key window。
- Finder-driven source 展示时不激活 QuickCookies。
- direct path source 展示时可以激活 QuickCookies。

### 阶段 2：direct path 内部文件导航上下文

目标：

- direct path 路径下，上下键在 QuickCookies 内部切换当前目录相邻文件。
- Finder/热键路径下，上下键继续由 Finder 消费，QuickCookies 只在选择事件后刷新。
- 不复刻 Finder 当前排序。

新增：

- `PreviewNavigationContext`
- `PreviewNavigationContextTests`

测试：

- 当前文件能定位 index。
- 上下边界处理明确。
- 目录被排除。
- 排序稳定。
- 缺失文件或目录不可读时有明确 fallback。

### 阶段 3：收口 Finder selection follow

目标：

- direct path 入口不启动 polling。
- Finder/热键入口在窗口可见期间启动 scoped polling，而不是对所有入口无差别启动。
- Finder/热键路径通过键盘/鼠标选择事件触发 refresh burst 加速。
- polling 代码保留为 Finder-driven correctness path，不再是全局默认主路径。

改动点：

- `showOverlay(session:)`
- `PreviewOverlayFinderFollowPolicy`
- `PreviewOverlayFinderSelectionEventRefreshPolicy`
- `FinderSelectionPollingController` 生命周期

测试：

- `.service` / `.urlScheme` 不启动 polling。
- `.hotkey` / `.finderSync` / `.menuBar` 会启动 scoped polling。
- timer tick 允许 `nil` 与当前 QuickCookies bundle identifier 作为 frontmost fallback。
- Finder 前台 `Up` / `Down` 和 `leftMouseUp` 会触发 refresh burst。
- `Esc`、编辑模式、非 Finder 前台事件不会触发 refresh。
- 关闭窗口仍会 stop polling，保持清理逻辑安全。

### 阶段 4：窗口几何修正

目标：

- 可见卡片边界等于 AppKit 窗口边界。
- 拖拽贴边、顶部自动展开按真实窗口尺寸工作。
- 保持现有 HUD 卡片、阴影、圆角、毛玻璃和弹簧动画的视觉一致性。

实施调查结论：

- 旧 `windowPadding` 同时影响稳定态真实窗口尺寸和动画 source rect 外扩，是贴边小一圈的核心原因。
- 旧 `ContentView.padding(40)` 会让可见 HUD 卡片小于 AppKit 认知窗口边界。
- 动画外扩仍有价值，因此保留为独立 `animationOutset`，不再混入稳定态窗口尺寸。
- 当前环境因辅助功能权限 gate 进入 Guide/Onboarding，无法自动截图；视觉部分需要人工确认。

已改动：

- `QuickLookOverlay.stableCardOuterPadding = 0`
- `QuickLookOverlay.animationOutset = 40`
- `PreviewOverlaySizingPolicy.stableContentSize(...)`
- `PreviewOverlaySizingPolicy.animationSourceRect(...)`
- `ContentView(cardOuterPadding:)`

当前状态：

- 已实施。
- 自动逻辑测试已覆盖 stable sizing 不再包含透明外圈，以及 animation outset 与 stable sizing 分离。
- 视觉、贴边和顶部展开需要人工验收。

实施约束：

- 不允许只为贴边正确而直接丢掉阴影或毛玻璃质感。
- 不允许让内容区域相对工具栏、圆角、边框产生明显错位。
- 不允许让打开/关闭动画出现首帧闪烁、突然裁切或明显尺寸跳变。
- 如果需要改变视觉参数，必须在文档或提交说明中解释原因和取舍。

测试：

- `PreviewOverlaySizingPolicy` 不再包含外圈 padding。
- compact / regular / office 宽度策略仍正确。
- 手测贴边和顶部自动展开。
- 手测视觉回归：重点检查阴影、圆角、毛玻璃、内容边距和动画观感。

## 明确不做

本阶段不做：

- 压缩包预览。
- SQLite 预览。
- AXObserver 级别的完整 Finder-follow 替换。
- 复刻 Finder 当前排序和视图布局。
- 多窗口工作区。
- 项目级文件管理。

## 风险与取舍

### 取舍 1：不同入口采用不同焦点模型

Finder/热键路径保留 Finder 焦点，换取 Finder 蓝色选中态、列表展开目录时的原生导航行为，以及更少的窗口抢焦点摩擦。

direct path 路径让 QuickCookies 聚焦，换取 Services、URL Scheme、内部导航场景里的直接交互能力。

判断：

这是当前最贴近用户测试反馈的折中。它没有强行把所有入口收敛到一种焦点模型，而是让 Finder 驱动和 direct path 驱动分别保持各自最自然的交互。

### 取舍 2：direct path 内部导航排序不完全等于 Finder 当前排序

首版用稳定文件名排序，不复刻 Finder 当前视图排序。

判断：

这是合理的第一版边界。复刻 Finder 排序需要读取 Finder UI 状态或目录视图设置，复杂度高，不适合当前阶段。

### 取舍 3：动画外圈可能需要重新调

去掉真实窗口 padding 后，现有弹簧动画和阴影可能需要重新调参。

判断：

窗口交互正确性优先级高，但不能以 UI 明显变形为代价。几何改动必须先调查原设计意图，再用视觉回归确认重构后仍保持 QuickCookies 现有 HUD 卡片质感。

## 验收清单

自动测试：

- Finder-driven 预览态不成为 key window。
- direct path 预览态可以成为 key window。
- direct path 预览态展示时可以聚焦 QuickCookies。
- `PreviewNavigationContext` 能稳定返回 previous / next。
- 不再默认 forward Finder navigation key。
- 只有 Finder-driven 入口启动 scoped Finder polling，direct-path 入口不启动。
- Finder 前台上下键和鼠标选择事件会触发 refresh burst。
- 阶段 4 完成后：sizing policy 不再把透明 padding 算入真实窗口尺寸。

手动测试：

- Finder 中选择 Markdown，热键打开后 Finder 保持蓝色选中态。
- Finder 中按上下键，Finder 选中态变化，QuickCookies 随后刷新到新文件。
- Finder 中鼠标点选另一个文件，QuickCookies 随后刷新到新文件。
- 再次触发全局热键，窗口关闭。
- Services / URL Scheme 打开后，direct path 窗口可以正常交互。
- direct path 打开后按上下键，QuickCookies 内部切换当前目录相邻文件。
- 打开后拖到屏幕左/右边缘，贴边以可见卡片为准。
- 拖到屏幕顶部，系统自动展开行为以可见卡片为准。
- 对比重构前后截图，确认毛玻璃、圆角、阴影、内容内边距、工具栏高度没有明显变形。
- 对比重构前后打开/关闭动画，确认没有明显闪烁、裁切、跳变或生硬感。
- Services 打开文件，不启动 Finder polling。
- URL Scheme 打开文件，不依赖当前 Finder selection。
- 编辑模式输入、保存、返回预览仍正常。
- PDF、图片、Office 打开后焦点行为可预测，不影响内容交互。

## 推荐结论

推荐采用“双路径交互模型 + Finder 事件触发刷新”的替代方案。

这不是对当前 polling 的小优化，而是替换掉旧模型中最核心的错误取舍：

```text
为了 Finder 上下键跟随，让 QuickCookies 放弃正常窗口交互
```

新方案把 Finder 驱动场景和 direct path 场景分开处理：Finder 场景保留 Finder 的选中反馈和导航习惯，并把 selection follow 收口成 scoped watcher + 事件加速；direct path 场景提供 QuickCookies 自身交互能力。它更符合当前阶段“打磨现有产品”的目标，也能同时避免 direct path 被卷入 Finder polling 成本，并收口文件名/内容一致性、窗口贴边、动画和 UI 稳定性这些已经暴露出的体验问题。
