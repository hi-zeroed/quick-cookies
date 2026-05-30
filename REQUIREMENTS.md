# 需求文档 (REQUIREMENTS.md)

以下为 QuickPeek 项目的核心需求清单及当前开发状态。

| 需求 ID | 功能模块 | 需求描述 | 状态 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| REQ-001 | 全局热键监听 | 默认使用 `Cmd + Shift + Space` 触发预览，且支持在设置中自定义配置。 | 需测试 | 核心触发逻辑已在 `HotkeyManager` 实现 |
| REQ-002 | Finder 文件检测 | 使用 AppleScript 自动获取当前 Finder 中选中的文件路径。 | 需测试 | 已在 `FileDetector` 实现，使用 Finder url 属性提取以彻底解决 `-1700` 转换错误与物理校验阻断 |
| REQ-003 | 文件分类与过滤 | 自动过滤不支持的文件，将文件分类为 Markdown、代码、纯文本三类。 | 需测试 | 已在 `FileTypeClassifier` 与 `Constants` 实现 |
| REQ-004 | Markdown 渲染 | 支持将 Markdown 文件渲染为 HTML 并在 WebView 中美观地显示。 | 需测试 | 已在 `MarkdownRenderer` 与 `MarkdownView` 实现 |
| REQ-005 | 代码语法高亮 | 支持常见代码文件（Swift, JS, Python 等）的语法高亮展示。 | 需测试 | 已在 `SyntaxHighlighter` 与 `CodeView` 实现 |
| REQ-006 | 浮动预览窗口 | 使用 `NSPanel` 创建一个无边框、支持半透明磨砂效果、始终置顶的浮动窗口。 | 需测试 | 已实现，无边框且支持背景空白拖动，基于 AXUIElement 定位（引入 CFBoolean 安全读取与 AXMainWindow 活跃窗口过滤，彻底解决坐标卡死与中心点退化问题），并彻底消除两段式闪现 Bug |
| REQ-007 | 编辑模式与行号 | 预览窗口支持快捷键（如 `Cmd + E`）进入编辑模式，支持保存修改并显示行号。 | 需测试 | 已在 `EditorView` 实现 |
| REQ-008 | 设置界面 | 提供设置窗口，用于配置触发快捷键、代码/文本字体大小，管理辅助功能权限。 | 需测试 | 已在 `SettingsWindow` 实现 |
| REQ-009 | 权限请求与引导 | 应用运行需要 Accessibility（辅助功能）权限，未授权时需要引导用户授权。 | 需测试 | 已在 `AppDelegate` 及 `HotkeyManager` 实现 |
