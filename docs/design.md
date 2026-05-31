# Quick Cookies 设计文档

> macOS 轻量级文件预览/编辑应用

## 项目概述

**名称**：Quick Cookies
**定位**：一个 Swift macOS App，通过可自定义全局快捷键触发，弹出浮动窗口预览/编辑文本类文件，解决 macOS Quick Look 对开发者常用文件类型支持不足的问题。

### 解决的痛点

1. 空格预览配置文件（yml/json/toml 等）经常失败
2. 预览这些文件会拉起重型编辑器（VS Code/Xcode）
3. Markdown 文件只能看源码，无法渲染预览
4. 简单编辑需要打开完整编辑器

---

## 架构设计

```
┌─────────────────────────────────────────────────────┐
│                    Quick Cookies App                     │
├─────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌──────────┐ │
│  │ HotkeyMgr   │───▶│ FileDetector│───▶│ Preview  │ │
│  │ (全局热键)   │    │(Finder选中) │    │ Window   │ │
│  └─────────────┘    └─────────────┘    └──────────┘ │
│         │                                    │      │
│         ▼                                    ▼      │
│  ┌─────────────┐                     ┌───────────┐ │
│  │ Settings    │                     │ Editor    │ │
│  │ (快捷键配置) │                     │ (轻量编辑) │ │
│  └─────────────┘                     └───────────┘ │
│                              │                      │
│                              ▼                      │
│                     ┌───────────────┐              │
│                     │ Renderer      │              │
│                     │ (MD渲染/语法   │              │
│                     │  高亮引擎)     │              │
│                     └───────────────┘              │
└─────────────────────────────────────────────────────┘
```

**架构要点**：
- 纯 Swift + SwiftUI 单体 App，无扩展依赖
- 全局热键监听使用 `NSEvent.addGlobalMonitor`
- 文件检测通过 AppleScript 与 Finder 通信
- 浮动窗口使用 NSPanel 实现

---

## 核心组件

### 1. HotkeyManager（热键管理器）

**职责**：注册/监听全局快捷键，触发预览窗口

**功能**：
- 存储用户自定义快捷键组合
- 使用 NSEvent.addGlobalMonitor 监听按键
- 支持 Cmd/Option/Control + 字母/数字组合
- 系统休眠/唤醒时自动重注册

### 2. FileDetector（文件检测器）

**职责**：获取 Finder 当前选中的文件路径

**功能**：
- 通过 AppleScript 与 Finder 通信
- 返回选中文件的完整路径
- 支持单文件和多文件（取第一个）
- 错误处理：无选中文件、权限不足等

### 3. PreviewWindow（预览窗口）

**职责**：浮动窗口展示文件内容

**功能**：
- NSPanel 实现，可浮动在其他窗口之上
- 支持拖拽调整大小
- 点击外部区域可选关闭（可配置）
- 快捷键 Cmd+W 关闭

### 4. Renderer（渲染引擎）

**职责**：根据文件类型渲染内容

**功能**：
- Markdown → HTML 渲染
- 代码/配置文件 → 语法高亮
- 纯文本 → 直接显示

### 5. Editor（轻量编辑器）

**职责**：简单的文本编辑功能

**功能**：
- 基础编辑：输入、删除、换行
- 行号显示
- Cmd+S 保存
- 编辑状态指示（标题栏显示 ● 修改标记）

### 6. SettingsWindow（设置窗口）

**职责**：用户配置界面

**功能**：
- 快捷键设置（录制按键组合）
- 文件类型关联设置
- 外观设置（字体大小、主题）

---

## 数据流

### 预览触发流程

```
用户按下快捷键
       │
       ▼
HotkeyManager 检测到按键事件
       │
       ▼
FileDetector 调用 AppleScript
       │
       ▼
获取 Finder 选中文件路径
       │
       ├─ 无选中文件 → 显示提示 "未选中文件"
       ├─ 文件类型不支持 → 显示提示 "不支持此文件类型"
       ▼
PreviewWindow 弹出
       │
       ▼
Renderer 根据后缀选择渲染策略
       │
       ├─ .md → Markdown 渲染为 HTML
       ├─ .json/.yaml/.toml → 语法高亮 + 格式化
       ├─ .sh/.zsh → Shell 语法高亮
       ├─ .ts/.js/.py/.go → 对应语言高亮
       ▼
内容显示在窗口中
```

### 编辑保存流程

```
用户在预览窗口中编辑内容
       │
       ▼
Editor 更新文本状态，标题栏显示修改标记 (●)
       │
       ▼
用户按下 Cmd+S
       │
       ▼
写入文件（UTF-8 编码）
       │
       ├─ 成功 → 移除修改标记
       ├─ 失败 → 显示错误提示
       ▼
继续停留在预览窗口
```

### 快捷键配置流程

```
用户打开设置窗口 → 点击 "更改快捷键"
       │
       ▼
进入录制模式（监听下一次按键）
       │
       ▼
用户按下组合键
       │
       ▼
验证快捷键有效性
       │
       ├─ 冲突 → 显示警告
       ▼
保存到 UserDefaults，HotkeyManager 重新注册
```

---

## 错误处理

### 错误场景

| 场景 | 处理方式 |
|------|----------|
| 无选中文件 | 窗口显示 "未检测到选中文件" 提示，3秒后自动消失 |
| 文件类型不支持 | 显示 "不支持预览此文件类型" + 支持列表提示 |
| 文件读取失败 | 显示错误信息 + "请检查文件权限" |
| 文件过大（>5MB） | 显示警告 "文件较大，可能影响性能" + 继续加载选项 |
| 文件写入失败 | 弹出警告框 "保存失败: [错误原因]" |
| Finder 未运行 | 显示 "请先打开 Finder" 提示 |
| 快捷键冲突 | 设置界面显示 "此快捷键可能与其他应用冲突" |

### 边界情况

- 多文件选中：只处理第一个文件
- 文件正在被其他程序编辑：尝试读取，写入时可能失败
- 文件编码非 UTF-8：尝试自动检测，失败则显示乱码警告
- 空文件：正常显示空白内容
- 二进制文件误触发：检测文件内容，发现二进制则拒绝打开
- 网络路径文件：支持，但可能较慢
- 符号链接：解析为真实路径后处理

### 权限处理

首次运行需要授权：
1. **全局键盘监听权限（Accessibility）**
   - App 启动时检测，未授权则弹出引导窗口
   - 显示 "请前往 系统偏好设置 → 安全性与隐私 → 辅助功能"

---

## 技术栈

### 核心技术

| 组件 | 技术选择 | 原因 |
|------|----------|------|
| UI 框架 | SwiftUI | 现代化、声明式、开发效率高 |
| 窗口管理 | NSPanel | 浮动窗口支持 |
| 热键监听 | NSEvent.addGlobalMonitor | 原生 API |
| Finder 通信 | AppleScript | 简单直接 |
| Markdown 渲染 | swift-markdown | 苹果官方维护 |
| 语法高亮 | Highlightr | 支持语言多、效果好 |

### 项目结构

```
QuickCookies/
├── App/
│   ├── QuickCookiesApp.swift          # App 入口
│   └── AppDelegate.swift           # 生命周期管理
├── Core/
│   ├── HotkeyManager.swift         # 热键管理
│   ├── FileDetector.swift          # 文件检测
│   ├── FileTypeClassifier.swift    # 文件类型判断
├── UI/
│   ├── PreviewWindow.swift         # 预览窗口
│   ├── SettingsWindow.swift        # 设置窗口
│   ├── ContentView.swift           # 主内容视图
│   ├── MarkdownView.swift          # Markdown 渲染视图
│   ├── CodeView.swift              # 代码高亮视图
│   └── EditorView.swift            # 编辑视图
├── Renderer/
│   ├── MarkdownRenderer.swift      # MD 渲染逻辑
│   ├── SyntaxHighlighter.swift     # 语法高亮逻辑
├── Utils/
│   ├── FileUtils.swift             # 文件读写
│   ├── EncodingDetector.swift      # 编码检测
├── Config/
│   ├── Settings.swift              # 用户配置存储
│   ├── Constants.swift             # 常量定义
├── Resources/
│   ├── Assets.xcassets             # 图标资源
│   └── Styles/                     # CSS/样式文件
└── Info.plist                      # 权限声明
```

### 外部依赖

通过 Swift Package Manager：
- swift-markdown（苹果官方，Markdown 解析）
- Highlightr（语法高亮）

### 系统要求

- macOS 12.0（Monterey）或更高
- 支持 Intel 和 Apple Silicon

---

## 功能清单

### MVP（第一版）

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 全局快捷键触发 | 默认 Cmd+Shift+Space，可配置 | P0 |
| 文件类型检测 | JSON/YAML/TOML/XML/.env/.md/.txt/.sh/.zsh/.ts/.js/.py/.go 等 | P0 |
| 浮动预览窗口 | NSPanel，可拖拽、可调整大小 | P0 |
| Markdown 渲染 | HTML 渲染，支持标题、列表、代码块、表格、链接 | P0 |
| 语法高亮 | 代码/配置文件语法高亮显示 | P0 |
| 轻量编辑 | 基础文本编辑 + Cmd+S 保存 | P0 |
| 行号显示 | 编辑模式下显示行号 | P0 |
| 快捷键设置 | 用户可自定义触发快捷键 | P0 |

### V2（后续增强）

| 功能 | 描述 | 优先级 |
|------|------|--------|
| JSON/YAML 格式化 | 自动格式化显示，支持折叠 | P1 |
| 深色/浅色主题 | 根据系统主题自动切换 | P1 |
| 字体大小设置 | 用户可调整显示字体大小 | P1 |
| 历史记录 | 最近打开的文件列表 | P2 |
| 多标签页 | 同时预览多个文件 | P2 |

### 不做（明确排除）

- Excel/Word/PDF 等二进制格式
- 图片预览（系统 Quick Look 已支持）
- Git 集成/版本控制
- 插件扩展系统
- 云端同步
- 正则搜索/替换
- 代码自动补全

---

## 文件类型支持

### 配置文件
- `.json` - JSON 语法高亮
- `.yaml` / `.yml` - YAML 语法高亮
- `.toml` - TOML 语法高亮
- `.xml` - XML 语法高亮
- `.env` / `.env.local` / `.env.*` - 环境变量格式

### Markdown
- `.md` / `.markdown` - HTML 渲染预览

### Shell 脚本
- `.sh` - Bash 语法高亮
- `.zsh` - Zsh 语法高亮
- `.bash` - Bash 语法高亮

### 代码文件
- `.ts` / `.tsx` - TypeScript
- `.js` / `.jsx` - JavaScript
- `.py` - Python
- `.go` - Go
- `.rs` - Rust
- `.java` - Java
- `.kt` - Kotlin
- `.swift` - Swift
- `.c` / `.cpp` / `.h` - C/C++
- `.rb` - Ruby
- `.php` - PHP
- `.sql` - SQL

### 其他文本
- `.txt` - 纯文本
- `.log` - 日志文件
- `.csv` - CSV 格式
- `.conf` / `.config` / `.ini` - 配置文件
- `.gitignore` / `.dockerignore` - Ignore 文件
- `.editorconfig` - EditorConfig
- Makefile / Dockerfile - 无后缀文件