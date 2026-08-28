# QuickCookies 预览交互收口实施记录

日期：2026-06-09
状态：代码已实施并完成自动验证；视觉与 Finder 系统行为仍需手动验收
对应方案：`docs/preview-interaction-redesign.md`

## 目标

本阶段只打磨现有预览链路，不新增压缩包、SQLite 或其他预览格式。

当前采用“双路径交互模型”：

- Finder/热键路径：Finder 保持焦点和蓝色选中态，QuickCookies 不抢焦点；overlay 可见期间启动 scoped selection watcher；Finder 上下键或鼠标选择事件触发 refresh burst 加速跟随。
- direct path 路径：Services、URL Scheme、内部导航等已知路径入口允许 QuickCookies 成为可交互窗口。
- 所有路径：不再对所有入口无差别启动 150ms Finder selection 轮询；只有 Finder-driven source 会在窗口可见期间启动 scoped watcher。
- 关闭路径：预览态关闭统一依赖全局热键 toggle 或窗口内显式关闭控件，不新增 `Esc` 关闭记忆点。

## 已实施内容

- `PreviewOverlayKeyWindowPolicy` 按 source 分流：
  - `.hotkey`、`.finderSync`、`.menuBar` 不成为 key window。
  - `.service`、`.urlScheme`、`.internalNavigation` 可成为 key window。
  - 编辑模式仍可成为 key window。
- `PreviewOverlayFocusActivationPolicy` 按 source 分流：
  - Finder-driven source 不激活 QuickCookies。
  - direct path source 可激活 QuickCookies。
- `PreviewNavigationContext` 已接入：
  - direct path 预览态支持当前目录内 `Up` / `Down` 内部导航。
  - 编辑模式中 `Up` / `Down` 仍留给编辑器。
- Finder scoped watcher 已接入：
  - `PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(...)` 对 `.hotkey`、`.finderSync`、`.menuBar` 返回 `true`，对 direct path source 返回 `false`。
  - `showOverlay(session:)` 会为 Finder-driven source 启动 `finderSelectionPollingController.start(...)`。
  - watcher 启动时传入 `allowsUnknownFrontmost: true` 与当前 QuickCookies bundle identifier fallback，避免 AppKit 在过渡时误报前台应用导致漏刷新。
  - polling controller 的 stop/reset 清理能力继续保留。
- Finder 事件触发刷新已接入：
  - Finder 前台 plain `Up` / `Down` 后触发一次 refresh burst。
  - Finder 前台 `leftMouseUp` 后触发一次 refresh burst。
  - 这是加速路径，不替代 scoped watcher。
  - `Esc`、编辑模式、非 Finder 前台、带 Command/Option/Control 的按键不会触发刷新。
- 窗口几何已收口：
  - 稳定态窗口尺寸不再包含 40pt 透明外圈。
  - 打开/关闭动画继续使用独立 `animationOutset` 保留视觉起跳/飞回效果。
  - `ContentView(cardOuterPadding:)` 在 overlay 稳定态传入 `0`。
- 快速切换内容一致性已收口：
  - 文本首段加载、增量分段、编辑准备、代码高亮异步回写均绑定当前请求身份。
  - 内容渲染需满足 active path 与 loaded content path 一致。

## 关键文件

- `QuickCookies/UI/QuickLookOverlay.swift`
- `QuickCookies/UI/ContentView.swift`
- `QuickCookies/UI/CodeView.swift`
- `QuickCookies/Core/Preview/PreviewContentLoadCoordinator.swift`
- `QuickCookies/Core/Preview/PreviewLaunchRequest.swift`
- `QuickCookies/Core/Preview/PreviewNavigationContext.swift`
- `QuickCookiesTests/QuickLookOverlayStateTests.swift`
- `QuickCookiesTests/PreviewNavigationContextTests.swift`
- `QuickCookiesTests/PreviewContentLoadCoordinatorTests.swift`

## 自动验证

重点命令：

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/QuickLookOverlayStateTests
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewNavigationContextTests
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewLaunchRequestTests
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewContentLoadCoordinatorTests
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath build/xctest-derived/preview-interaction-redesign-full
```

已覆盖的纯逻辑行为：

- Finder-driven source 不成为 key window。
- direct path source 可成为 key window。
- Finder-driven source 启动 scoped polling；direct path source 不启动 polling。
- Finder 前台上下键和鼠标选择事件触发 refresh burst。
- direct path 内部导航生成 `.internalNavigation` direct path 请求。
- 窗口稳定尺寸不包含透明外圈。
- 展开/收起尺寸变化有动画，切换文件不做错误的 resize 动画。
- 旧异步文本/高亮/增量结果不能回写到新文件。

## 手动验收重点

- Finder 中热键打开文件后，Finder 保持蓝色选中态。
- Finder 中上下键切换文件后，QuickCookies 刷新到新文件。
- Finder 中鼠标点选另一个文件后，QuickCookies 刷新到新文件。
- 快速切换时，状态栏文件名、窗口标题、正文内容一致。
- 再次触发全局热键可以关闭窗口。
- Services / URL Scheme 打开 direct path 时，QuickCookies 可交互。
- direct path 打开后，`Up` / `Down` 可在当前目录内切换相邻文件。
- 编辑模式中 `Up` / `Down` 不切换文件。
- 窗口贴边以可见卡片为准。
- 顶部自动展开不再因为透明外圈小一圈。
- 毛玻璃、圆角、阴影、内容边距、展开动画没有 UI 退化。

## 明确不做

- 不新增压缩包或 SQLite 预览。
- 不复刻 Finder 当前排序、分组、展开树状态。
- 不引入项目级文件管理器。
- 不把 Finder-follow 做成默认持续轮询。
- 不把 `Esc` 重新作为预览关闭主路径。
- 不为了几何正确牺牲已定稿 HUD 视觉。

## 后续风险

- 当前 Finder 跟随仍是 timer-based scoped watcher 加事件加速，不是 AXObserver 级别的 Finder selection 订阅。
- 自动测试无法判断真实毛玻璃、阴影、圆角和 macOS 贴边/顶部展开观感，这部分必须手测。
- direct path 内部导航使用当前目录文件名排序，不等同 Finder 当前视图排序。
