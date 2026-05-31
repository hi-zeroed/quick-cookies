# 需求文档 (REQUIREMENTS.md)

以下为 Quick Cookies 项目的核心需求清单及当前开发状态。

| 需求 ID | 功能模块 | 需求描述 | 状态 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| REQ-001 | 全局热键监听 | 默认使用 `Cmd + Shift + Space` 触发预览，且支持在设置中自定义配置。 | 需测试 | 核心触发逻辑已在 `HotkeyManager` 实现 |
| REQ-002 | Finder 文件检测 | 使用 AppleScript 自动获取当前 Finder 中选中的文件路径。 | 需测试 | 已在 `FileDetector` 实现，使用 Finder url 属性提取以彻底解决 `-1700` 转换错误与物理校验阻断 |
| REQ-003 | 文件分类与过滤 | 自动过滤不支持的文件，将文件分类为 Markdown、代码、纯文本三类。 | 已完成 | 智能放行与拦截，对不支持或读取失败的文件改呈矮高度原生 Quick Look 风格卡片预览，加载系统级图标及元数据，且支持一键用默认应用打开 |
| REQ-004 | Markdown 渲染 | 支持将 Markdown 文件以原生样式精美渲染（以 GitHub 主题为蓝本），且背景色彻底透明，字号与字体动态响应设置。 | 已完成 | 已基于 swift-markdown-ui 视图完成透明背景与热联动，集成 HTML 过滤并支持表格圆角与相对图片 Base URL 解析 |
| REQ-005 | 代码语法高亮 | 支持常见代码文件（Swift, JS, Python 等）的语法高亮展示。 | 需测试 | 已在 `SyntaxHighlighter` 与 `CodeView` 实现 |
| REQ-006 | 浮动预览窗口 | 使用 `NSPanel` 创建一个无边框、支持半透明磨砂效果、始终置顶的浮动窗口。 | 需测试 | 已实现，无边框且支持背景空白拖动，基于 AXUIElement 定位（引入 CFBoolean 安全读取与 AXMainWindow 活跃窗口过滤，彻底解决坐标卡死与中心点退化问题），保留左上角 macOS 原生红绿灯且实现一体化 Header 文件名居中对齐，彻底消除两段式闪现 Bug |
| REQ-007 | 编辑模式与行号 | 预览窗口支持快捷键（如 `Cmd + E`）进入编辑模式，支持保存修改并显示行号。 | 需测试 | 已在 `EditorView` 实现，并集成 GCD DispatchSource File Watcher，实时监测并防止外部编辑器覆盖冲突。 |
| REQ-008 | 设置界面 | 提供设置窗口，用于配置触发快捷键、自定义字体/字号，自启动与系统语言切换等选项。 | 已完成 | 重构为卡片化 UI，打包并内置注册了 JetBrains Mono 字体且完成 PS 名字转换映射，彻底打通字体字号的动态渲染与 SMAppService 自启动注册。 |
| REQ-009 | 权限请求与引导 | 应用运行需要 Accessibility（辅助功能）权限，未授权时需要引导用户授权。 | 已完成 | 已升级为新版高颜值双轨渐进式引导（Finder Sync 零权限与辅助功能高级动画），支持 Confetti 动效与平滑淡出退场。 |
| REQ-010 | 多语言适配 | 支持 English 与简体中文两套语言，提供自适应跟随系统及应用内热切换功能，瞬间刷新全案文案。 | 需测试 | 已在 Settings、SettingsWindow、ContentView、QuickLookOverlay、FinderMenuIntegration 和 AppDelegate 中完整实现。 |
| REQ-011 | 图标与品牌资源 | 设计并配置符合 macOS 规范的 App 像素级图标与自适应 Template 状态栏图标。 | 需测试 | 已完成 AppIcon 的 sips 批量生成、所有自定义状态栏、菜单项及工具栏 SVG 图标的导入与代码替换，支持 Template 自适应变色；成功添加独立的 QuickCookiesFinderSync App Extension，完美无感集成 Finder 右键菜单预览。 |
| REQ-012 | 连续键盘切换与焦点回归 | 支持在预览窗处于 Key 激活状态时按键盘上下键在 Finder 后台平滑切换选中文件，并在预览窗关闭后自动将焦点归还给 Finder，保证键盘操作的连续性。 | 已完成 | 已在 `QuickLookOverlay` 中注册键盘监听，利用 `CGEvent.postToPid` 投递上下键并轮询原子刷新，并在关闭时主动归还焦点给 Finder；已完美解决连续切换时“大窗口变小窗口能正常缩回，而由小变大功能失效”的 Bug，实现 0ms 完美双向大小自适应。 |
