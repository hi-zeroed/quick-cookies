<p align="center">
  <img src="QuickCookies/Resources/AppIcon_transparent.png" width="128" height="128" alt="Quick Cookies Logo">
</p>

<h1 align="center">Quick Cookies</h1>

<p align="center">
  <strong>极速无感、卡片式 macOS 开源文件预览与快捷编辑工具</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue?style=flat-square&logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/Language-Swift%205.9-orange?style=flat-square&logo=swift" alt="Language">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Icons-Remix%20Icon-blueviolet?style=flat-square&logo=remix-icon" alt="Icons">
</p>

<p align="center">
  <a href="#-核心特性">核心特性</a> •
  <a href="#-支持的文件类型">支持的文件类型</a> •
  <a href="#-项目架构概览">项目架构</a> •
  <a href="#-使用指南">使用指南</a> •
  <a href="#-开发与构建">开发与构建</a> •
  <a href="#-参与贡献-contributing">参与贡献</a> •
  <a href="#-常见问题-faq">常见问题 (FAQ)</a>
</p>

---

**Quick Cookies** 是一款专为 macOS 设计的极轻量、卡片式文件预览与快捷编辑工具。它致力于消除传统“双击打开文件”的繁琐步骤，通过全局双击 `⌥ Option` 热键实现文件的 0ms 瞬间预览，并支持在预览窗口中直接快捷编辑、实时保存修改。

界面采用高对比度的毛玻璃 HUD 视感与黄金阅读比例，配备原生的 `matchedGeometry` 空间轨迹弹簧动效，与 macOS 访达（Finder）深度集成，为您的日常研发、文档审阅与阅读带来无感、丝滑的极速体验。

---

## ✨ 核心特性

- 🚀 **0ms 闪电级响应弹出**
  在按下快捷键的瞬间，窗口立即以鼠标位置为起点 0ms 无缝淡入起跳，文件内容于后台 Task 异步解密、加载与语法高亮渲染。体验行云流水，绝不抢占或挂起主线程，彻底消除大文件读取造成的视觉卡顿。
- 📐 **黄金书籍阅读比例**
  窗口宽高比经过多轮人机交互与排版美学调优（宽度 `38%` : 高度 `88%`），呈现拔挺的单栏高级书籍质感，完美契合长文本段落、Markdown 文档以及复杂代码的阅读与审阅。
- 🎨 **卡片化现代美学设计**
  无边框毛玻璃面板（Visual Effect）背景，支持按住窗口任意空白处直接拖拽移动。完美适配 macOS 亮色、暗色主题以及自适应系统模式，提供极高对比度、呼吸感留白的排版版面。
- 📝 **无缝代码预览与快捷编辑**
  集成公用行号标尺，支持自动折行对齐。在预览状态下可通过 `Cmd + E` 一键进入编辑模式实时修改，`Cmd + S` 快捷保存，并配备了未安装字体的安全兜底降级渲染，高保真还原原生编辑器质感。
- 📊 **Office 文档与媒体格式支持**
  内置基于 `QLPreviewView` 原生框架的渲染容器，支持对 Word, Excel, PPT, iWork (Pages, Numbers, Keynote), PDF, RTF/RTFD 及 CSV 文件的无缝原生预览，保障 100% 格式不丢失，并对文档渲染区域进行 12px 圆角物理裁剪与防分层直角优化。
- 💾 **Markdown 导出 PDF**
  在预览 Markdown 文档时支持一键调起系统的 `NSSavePanel` 另存为 PDF 文件。采用离屏 `WKWebView` + 内置 `marked.js` 高性能渲染机制，自动对齐源文件同级目录，并在工具栏原位展示精致的线性进度反馈。
- 🔄 **中英双语 0ms 热刷新**
  拥有完备的本地化多语言适配（English & 简体中文），支持应用内分段选择一键热刷新，偏好设置、菜单项及状态栏文案 0ms 瞬间变换，无需重启。
- 🔌 **系统级原生深度融合**
  - **自适应状态栏**：使用单色品牌 `Template` 状态栏图标，随系统主题及壁纸反色变色。
  - **Scripting Bridge 高性能检测**：通过内存级 AppleEvent 零开销同步获取 Finder 当前高亮文件路径，支持免辅助功能权限的鼠标定位降级策略。
  - **高精度物理飞回**：利用 `AXUIElement` 递归搜寻前台 Finder 窗口的选中项，在关闭窗口时，完美播放收缩动画“精准飞回”到 Finder 文件的原位图标处。
  - **自启动与静默运行**：基于 macOS 13+ 现代 `SMAppService` 登录项接口注册，后台 Agent 静默运行，无常驻垃圾后台，极简环保。


## 📋 支持的文件类型

### 代码语法高亮

支持 **30+ 语言**、**60+ 文件扩展名** 的语法高亮：

| 语言 | 扩展名 |
| :--- | :--- |
| **Web** | `html` `css` `scss` `sass` `less` `js` `jsx` `ts` `tsx` `vue` `svelte` `mdx` `graphql` `cjs` `mjs` `cts` `mts` |
| **JSON / YAML / TOML / XML** | `json` `jsonc` `json5` `yaml` `yml` `eyaml` `toml` `xml` `plist` |
| **Shell** | `sh` `zsh` `bash` `fish` `command` `ksh` |
| **Python / Go / Rust** | `py` `go` `rs` |
| **Java / Kotlin / Dart** | `java` `kt` `dart` |
| **Swift / C / C++** | `swift` `c` `cpp` `h` `hpp` `cc` `cxx` |
| **Ruby / PHP / Perl** | `rb` `php` `pl` `pm` `podspec` `fastfile` |
| **Lua / Groovy / Scala** | `lua` `groovy` `scala` `gradle` `jenkinsfile` |
| **Haskell / Erlang / Elixir** | `hs` `erl` `ex` `exs` |
| **Clojure / Lisp / Scheme** | `clj` `cljs` `lisp` `lsp` `scheme` `scm` |
| **SQL / INI / 配置** | `sql` `ini` `conf` `config` `properties` `env` |
| **Docker / Make / 其他** | `dockerfile` `makefile` `log` `diff` `patch` `csv` `tsv` `lock` |

### Markdown

| 格式 | 扩展名 | 附加功能 |
| :--- | :--- | :--- |
| Markdown | `md` `markdown` `mdown` `mdwn` `mkd` `mkdn` | 支持导出为带样式的 PDF |

### Office 与富文本文档

| 格式 | 渲染方式 |
| :--- | :--- |
| Word（`.doc` `.docx`） | 原生 `QLPreviewView` |
| Excel（`.xls` `.xlsx`） | 原生 `QLPreviewView` |
| PowerPoint（`.ppt` `.pptx`） | 原生 `QLPreviewView` |
| iWork — Pages, Numbers, Keynote | 原生 `QLPreviewView` |
| PDF | 原生 `QLPreviewView` |
| RTF / RTFD | 原生 `QLPreviewView` |

### 媒体文件

| 格式 | 扩展名 |
| :--- | :--- |
| 图片 | `png` `jpg` `jpeg` `gif` `bmp` `tiff` `webp` |

### 纯文本（通用兜底）

任何未在上述列表中明确列出的扩展名，且通过二进制检测的文件，一律以纯文本模式打开，并自动检测文件编码。不遗漏任何可读文件。

---

## 📂 项目架构概览

项目采用清晰的模块化分层架构，方便外部开发者进行扩展与贡献：

```
QuickCookies/
├── App/           # 应用程序入口及生命周期 (AppDelegate, Onboarding, Configuration)
├── Core/          # 核心底层引擎 (热键路由, ScriptingBridge 文件探测, FileWatcher 冲突监听)
├── UI/            # 界面视图组件 (窗口动画, CodeView, MarkdownView, UnsupportedFileView)
├── Renderer/      # 语法高亮与字体处理 (Highlightr 桥接, 字体缓存, Markdown HTML 预处理)
├── Resources/     # 物理资源资产 (内置 JetBrains Mono 字体, 状态栏及工具栏 SVG 图标, Onboarding 动画素材)
└── Support/       # 系统权限、自启动配置及 Info.plist 支持
```

---

## ⌨️ 使用指南

应用在后台静默运行，您可以通过以下物理快捷键控制全局工作流：

| 动作                      | 物理快捷键 (Kbd)                        | 作用描述                                                                                                                   |
| :------------------------ | :-------------------------------------- | :------------------------------------------------------------------------------------------------------------------------- |
| **快捷预览 / Toggle关闭** | <kbd>⌥ Option</kbd> <kbd>⌥ Option</kbd> | 在 Finder 中选中文件，**双击 Option** 瞬间呼出预览；再次双击或在窗口聚焦时按任意键即可关闭。_(支持在设置中自定义组合热键)_ |
| **切换编辑 / 预览模式**   | <kbd>⌘ Command</kbd> + <kbd>E</kbd>     | 在预览窗口打开时，一键进入编辑模式修改内容；再次按下返回预览模式。                                                         |
| **实时保存修改**          | <kbd>⌘ Command</kbd> + <kbd>S</kbd>     | 在编辑模式且内容有改动时，保存当前修改到物理文件中。                                                                       |
| **安全退出窗口**          | <kbd>Esc</kbd>                          | 在预览/编辑窗口中按下，安全关闭并使窗口缩小飞回 Finder 原位置。                                                            |

---

## 🛠 开发与构建

### 开发环境要求

- **运行系统**：macOS 13.0 或更高版本
- **编译工具**：Xcode 14.0+ / Swift 5.9+
- **依赖管理**：Swift Package Manager (SPM)

### 引入依赖包

项目通过 SPM 引入了两个高保真渲染依赖包：

1. **[MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)**：用于原生、精美的 Markdown 排版展示。
2. **[Highlightr](https://github.com/raspu/Highlightr)**：用于提供跨语言的高亮着色引擎。

### 命令行编译步骤

```bash
# 1. 克隆项目并进入根目录
git clone https://github.com/your-username/QuickPeek.git
cd QuickPeek

# 2. 执行 clean 编译构建 Debug 版本
xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -configuration Debug -derivedDataPath Build/ clean build

# 3. 运行编译出的程序
open Build/Build/Products/Debug/QuickCookies.app
```

---

## 🤝 参与贡献 (Contributing)

我们非常欢迎并鼓励开发者参与 Quick Cookies 的开源贡献！如果您发现了 Bug、有新功能的想法，或者想要改进代码与文档，请遵循以下规范：

### 1. 开发分支模型

- `main` 分支：仅用于存放经过充分回归验证的稳定版本。
- `develop` 分支：日常功能开发与缺陷修复的核心分支。请将您的 Pull Request（PR）提交至 `develop` 分支。

### 2. 提交 Pull Request 清单

在提交 PR 之前，请确保完成以下自检：

1. **本地构建**：运行 `xcodebuild` 确保项目编译成功，无任何警告与错误。

---

## 🎨 图标资源与版权声明

### 1. 应用图标来源

本项目当前采用的卡通网格面包应用图标（AppIcon）源自 [iconfont 矢量图标库（合集 ID: 15128）](https://www.iconfont.cn/collections/detail?spm=a313x.manage_type_mylikes.0.da5a778a4.77973a81n26vWj&cid=15128)。

### 2. SVG 图标来源

本项目中使用的所有工具栏、状态栏及下拉菜单自定义 SVG 图标，均源自开源的 [Remix Icon](https://remixicon.com/) 矢量图标库（采用 Apache License 2.0 开源协议）。

### 3. 商用合规性评估

- **版权归属**：iconfont 上的图标资源（除阿里官方出品外）由独立设计师或用户分享，著作权属于原作者。平台不拥有其版权，不提供统一的商用授权。
- **非商用合规性**：本项目处于个人研究与非营利性开源阶段，按平台要求已在 README 中明确标注出处。
- **商用风险避险**：如本项目未来有任何商业发布或盈利计划，请更换为具有 CC0、MIT 协议或其他免授权商用协议（如 Font Awesome Free、苹果官方 SF Symbols 或自研设计）的图标。

---

## 📄 License

本项目采用 [MIT License](LICENSE) 协议开源。
