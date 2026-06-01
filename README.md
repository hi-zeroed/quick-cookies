<p align="center">
  <img src="QuickCookies/Resources/AppIcon_transparent.png" width="128" height="128" alt="Quick Cookies Logo">
</p>

<h1 align="center">Quick Cookies</h1>

<p align="center">
  <strong>极速无感、卡片式 macOS 文件预览与编辑神器</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue?style=flat-square&logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/Language-Swift%205.9-orange?style=flat-square&logo=swift" alt="Language">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="#-核心特性">核心特性</a> •
  <a href="#-快速开始">快速开始</a> •
  <a href="#-使用指南">使用指南</a> •
  <a href="#-开发与构建">开发与构建</a> •
  <a href="#-常见问题-faq">常见问题 (FAQ)</a>
</p>

---

**Quick Cookies** 是一款专为 macOS 设计的极轻量、卡片式文件预览与快捷编辑工具。它旨在打破传统繁琐的打开文件步骤，通过全局热键实现文件的 0ms 瞬间预览，并支持在预览中直接编辑、保存修改。界面采用高级的卡片化磨砂视感与黄金阅读比例，与 macOS 系统深度集成，为您带来畅快无感的极速工作流。

---

## ✨ 核心特性

* 🚀 **0ms 闪电级响应弹出**
  在按下快捷键的瞬间，窗口立即以鼠标位置为起点 0ms 淡入淡出弹出，内容于后台线程异步解码与语法高亮渲染。体验行云流水，绝不挂起主线程，完全消除了 Finder 文件加载与定位造成的视觉卡顿。
* 📐 **黄金书籍阅读比例**
  窗口宽高比经过多轮美学调优（宽度 `38%` : 高度 `88%`），呈现优雅、拔挺的单栏高级书籍质感，完美契合长文本段落、Markdown 文档以及复杂代码的审阅与阅读。
* 🎨 **卡片化现代美学设计**
  无边框磨砂玻璃面板（Visual Effect）背景，支持按住窗口任意背景空白处进行拖动。深度适配 macOS 的亮色、暗色主题以及系统自适应模式，保证任何主题下均拥有舒适高对比度的排版版面。
* 📝 **无缝代码预览与快捷编辑**
  集成公用行号标尺，支持自动折行对齐。在预览状态下一键进入编辑模式，实时修改，`Cmd + S` 快捷保存，并配备了未安装字体的安全兜底降级渲染，高保真还原原生编辑器质感。
* 🔄 **中英双语 0ms 热刷新**
  拥有完备的本地化多语言适配（English & 简体中文），支持应用内分段选择一键热刷新，偏好设置、菜单项及状态栏文案 0ms 瞬间变换，无需重启。
* 🔌 **系统级原生深度融合**
  - **自适应状态栏**：使用单色品牌 `Template` 状态栏图标，随系统主题及壁纸反色变色。
  - **高精度物理飞回**：利用 `AXUIElement` 递归搜寻前台 Finder 窗口的选中项，在关闭窗口时，完美播放收缩动画“精准飞回”到 Finder 文件的原位图标处。
  - **自启动与静默运行**：基于 macOS 13+ 现代 `SMAppService` 登录项接口注册，后台 Agent 静默运行，无常驻垃圾后台，极简环保。

---

## 🚀 快速开始

### 1. 下载与安装
直接下载编译好的 [QuickCookies.app](Build/Build/Products/Debug/QuickCookies.app)，或者通过下文“开发与构建”小节自行编译后，将应用放入您的 `/Applications`（应用程序）目录。

### 2. 授权辅助功能权限 (Accessibility)
由于 Quick Cookies 需要全局监听双击 `⌥ Option` 热键，并向 Finder 提取选中项目的物理坐标，因此首次启动应用时，请按照系统引导，在：
> **系统设置** → **隐私与安全性** → **辅助功能** 
中勾选并允许 **Quick Cookies** 运行。

---

## ⌨️ 使用指南

应用在后台静默运行，您可以通过以下物理快捷键控制全局工作流：

| 动作 | 物理快捷键 (Kbd) | 作用描述 |
| :--- | :--- | :--- |
| **快捷预览 / Toggle关闭** | <kbd>⌥ Option</kbd> <kbd>⌥ Option</kbd> | 在 Finder 中选中文件，**双击 Option** 瞬间呼出预览；再次双击或在窗口聚焦时按任意键即可关闭。*(支持在设置中自定义组合热键)* |
| **切换编辑 / 预览模式** | <kbd>⌘ Command</kbd> + <kbd>E</kbd> | 在预览窗口打开时，一键进入编辑模式修改内容；再次按下返回预览模式。 |
| **实时保存修改** | <kbd>⌘ Command</kbd> + <kbd>S</kbd> | 在编辑模式且内容有改动时，保存当前修改到物理文件中。 |
| **安全退出窗口** | <kbd>Esc</kbd> | 在预览/编辑窗口中按下，安全关闭并使窗口缩小飞回 Finder 原位置。 |

---

## 🛠 开发与构建

### 开发环境要求
* **运行系统**：macOS 13.0 或更高版本
* **编译工具**：Xcode 14.0+ / Swift 5.9+
* **依赖管理**：Swift Package Manager (SPM)

### 引入依赖包
项目通过 SPM 引入了两个高保真渲染依赖包：
1. **[MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)**：用于原生、精美的 Markdown 排版展示。
2. **[Highlightr](https://github.com/raspu/Highlightr)**：用于提供跨语言的高亮着色引擎。

### 命令行编译步骤
```bash
# 1. 克隆项目并进入根目录
cd QuickCookies

# 2. 执行 clean 编译构建 Debug 版本
xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -configuration Debug -derivedDataPath Build/ clean build

# 3. 运行编译出的程序
open Build/Build/Products/Debug/QuickCookies.app
```

---

## ❔ 常见问题 (FAQ)

#### Q: 为什么编译时报错，提示找不到 Markdown 或 Highlightr 依赖？
**A:** 项目使用 Swift Package Manager 管理依赖，如果您是在 Xcode 中直接打开项目，Xcode 会自动解析并下载包。如果在编译时缺失，请在 Xcode 中选择 `File` → `Packages` → `Resolve Package Versions` 强行拉取。

#### Q: 为什么修改了自定义快捷键，录制显示与实际生效的不一致？
**A:** 请确认在录制时是否按下了额外的设备修饰键。您可以在设置面板中随时点击“**恢复默认设置**”，即可瞬间恢复到极简的“双击 Option”物理触发模式。

#### Q: 为什么双击快捷键没有反应，提示“未检测到选中文件”？
**A:** 1. 请确认当前前台活动窗口是 Finder 访达，且已经明确选中了一个文件；2. 请确认已在系统设置中授予了 Quick Cookies “辅助功能”权限，如未授权，应用将无法提取选中项目的物理路径。

---

## 🎨 图标资源与版权声明

### 1. 应用图标来源
本项目当前采用的卡通网格面包应用图标（AppIcon）源自 [iconfont 矢量图标库（合集 ID: 15128）](https://www.iconfont.cn/collections/detail?spm=a313x.manage_type_mylikes.0.da5a778a4.77973a81n26vWj&cid=15128)。

### 2. SVG 图标来源
本项目中使用的所有工具栏、状态栏及下拉菜单自定义 SVG 图标，均源自开源的 [Remix Icon](https://remixicon.com/) 矢量图标库（采用 Apache License 2.0 开源协议）。

### 3. 商用合规性评估
* **版权归属**：iconfont 上的图标资源（除阿里官方出品外）均由独立设计师或用户上传分享，其著作权属于原上传作者。平台不拥有这些图标的版权，亦无法提供统一的商用授权。
* **非商用合规性**：若本项目处于个人学习、研究及非营利性开源阶段，按平台要求在 `README` 中明确标注出处即可合规引用。
* **商用合规风险**：如果本项目未来有任何商业化计划（包括但不限于上架 Mac App Store 售卖、内购、收取捐赠等），直接使用此图标将存在侵权风险。**必须主动联系图标原作者以获取书面的商用授权**。
* **避险方案**：在未取得作者商用授权前，如需进行商业发布，请将图标资产更换为具有 CC0、MIT 协议或其他免授权商用协议（如 Font Awesome Free、Material Design Icons、苹果官方 SF Symbols 或自研设计）的资源。

---

## 📄 License

本项目采用 [MIT License](LICENSE) 协议开源。