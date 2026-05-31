# 需求文档 (REQUIREMENTS.md)

以下为 QuickPeek 项目的核心需求清单及当前开发状态。

| 需求 ID | 功能模块 | 需求描述 | 状态 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| REQ-001 | 全局热键监听 | 默认使用 `Cmd + Shift + Space` 触发预览，且支持在设置中自定义配置。 | 需测试 | 核心触发逻辑已在 `HotkeyManager` 实现 |
| REQ-002 | Finder 文件检测 | 使用 AppleScript 自动获取当前 Finder 中选中的文件路径。 | 需测试 | 已在 `FileDetector` 实现，使用 Finder url 属性提取以彻底解决 `-1700` 转换错误与物理校验阻断 |
| REQ-003 | 文件分类与过滤 | 自动过滤不支持的文件，将文件分类为 Markdown、代码、纯文本三类。 | 需测试 | 已在 `FileTypeClassifier` 与 `Constants` 实现 |
| REQ-004 | Markdown 渲染 | 支持将 Markdown 文件渲染为 HTML 并在 WebView 中美观地显示。 | 需测试 | 已在 `MarkdownRenderer` 与 `MarkdownView` 实现 |
| REQ-005 | 代码语法高亮 | 支持常见代码文件（Swift, JS, Python 等）的语法高亮展示。 | 需测试 | 已在 `SyntaxHighlighter` 与 `CodeView` 实现 |
| REQ-006 | 浮动预览窗口 | 使用 `NSPanel` 创建一个无边框、支持半透明磨砂效果、始终置顶的浮动窗口。 | 需测试 | 已实现，无边框且支持背景空白拖动，基于 AXUIElement 定位（引入 CFBoolean 安全读取与 AXMainWindow 活跃窗口过滤，彻底解决坐标卡死与中心点退化问题），保留左上角 macOS 原生红绿灯且实现一体化 Header 文件名居中对齐，彻底消除两段式闪现 Bug |
| REQ-007 | 编辑模式与行号 | 预览窗口支持快捷键（如 `Cmd + E`）进入编辑模式，支持保存修改并显示行号。 | 需测试 | 已在 `EditorView` 实现 |
| REQ-008 | 设置界面 | 提供设置窗口，用于配置触发快捷键、代码/文本字体大小，管理辅助功能权限。 | 需测试 | 已在 SettingsWindow 实现并重构为卡片化高颜值 UI，且已打通“编辑器字体”在预览/编辑界面的动态渲染以及基于 SMAppService 的“开机自启动”自备系统注册逻辑，确保配置项完全真实可用。 |
| REQ-009 | 权限请求与引导 | 应用运行需要 Accessibility（辅助功能）权限，未授权时需要引导用户授权。 | 需测试 | 已在 `AppDelegate` 及 `HotkeyManager` 实现 |
| REQ-010 | 多语言适配 | 支持 English 与简体中文两套语言，提供自适应跟随系统及应用内热切换功能，瞬间刷新全案文案。 | 需测试 | 已在 Settings、SettingsWindow、ContentView、QuickLookOverlay、FinderMenuIntegration 和 AppDelegate 中完整实现。 |
| REQ-011 | 图标与品牌资源 | 设计并配置符合 macOS 规范的 App 像素级图标与自适应 Template 状态栏图标。 | 需测试 | 已完成 AppIcon 各种规格的 xcassets 编译构建及 MenuBarExtra 对 magnifyingglass 系统图标的自适应替换。 |

