# QuickPeek macOS 文件预览应用

## 快速开始

### 1. 安装 SPM 依赖

**在 Xcode 中添加以下包依赖：**

#### swift-markdown（Markdown 渲染）
```
File → Add Packages...
URL: https://github.com/apple/swift-markdown.git
版本: 0.3.0 或更高
```

#### Highlightr（代码语法高亮）
```
File → Add Packages...
URL: https://github.com/raspu/Highlightr.git
版本: 2.1.0 或更高
```

**添加后选择 target：**
- 在 Package Products 列表中勾选：
  - `Markdown` (from swift-markdown)
  - `Highlightr` (from Highlightr)

### 2. 编译运行

```bash
# 或直接在 Xcode 中编译
xcodebuild -project QuickPeek.xcodeproj -scheme QuickPeek -configuration Debug build
```

### 3. 测试功能

1. 运行应用（Cmd+R）
2. 在 Finder 中选中一个 `.md` 或 `.swift` 文件
3. 按快捷键 `Cmd+Shift+Space` 触发预览
4. 确认预览窗口弹出并显示内容

## 已修复的问题

### ✅ 模块依赖问题

**问题：**
- `Cannot find 'SettingsWindowController' in scope`
- `Cannot find 'AppDelegate' in scope`
- `Unable to resolve module dependency: 'AppleScript'`

**根本原因：**
1. project.pbxproj 缺少文件引用（已修复）
2. FileDetector.swift 错误地 import 了不存在的 AppleScript 模块（已修复）

**修复措施：**
- ✅ 重写 project.pbxproj，添加所有 21个源文件引用
- ✅ 删除错误的 `import AppleScript`（NSAppleScript 属于 AppKit）
- ✅ 修复目录层级混乱（从三层嵌套改为正确的两层结构）

### ⏳ 外部依赖待添加

**需要通过 Xcode SPM 集成添加：**
- swift-markdown：Markdown 解析和渲染
- Highlightr：代码语法高亮

## 项目结构

```
QuickPeek/
├── QuickPeek.xcodeproj/          # Xcode 项目文件
│   ├── project.pbxproj           # 包含所有源文件引用
│   └── xcshareddata/xcschemes/
│
├── QuickPeek/                    # 源代码目录
│   ├── App/                      # 应用入口
│   │   ├── QuickPeekApp.swift    # SwiftUI MenuBarExtra
│   │   └── AppDelegate.swift     # 生命周期管理
│   │
│   ├── Config/                   # 配置层
│   │   ├── Constants.swift       # 文件类型映射、默认值
│   │   └── Settings.swift        # UserDefaults 管理
│   │
│   ├── Core/                     # 核心业务逻辑
│   │   ├── HotkeyManager.swift   # 全局热键监听（NSEvent）
│   │   ├── FileDetector.swift    # Finder 文件检测（NSAppleScript）
│   │   └── FileTypeClassifier.swift # 文件类型分类
│   │
│   ├── UI/                       # 用户界面层
│   │   ├── PreviewWindow.swift   # NSPanel 浮动窗口
│   │   ├── ContentView.swift     # 主内容视图路由
│   │   ├── MarkdownView.swift    # Markdown WebView渲染
│   │   ├── CodeView.swift        # 代码 TextView
│   │   ├── EditorView.swift      # 编辑器 + 行号
│   │   ├── SettingsWindow.swift # 设置界面
│   │   └── ToastView.swift       # 提示组件
│   │
│   ├── Renderer/                 # 渲染引擎
│   │   ├── MarkdownRenderer.swift # swift-markdown → HTML
│   │   └── SyntaxHighlighter.swift # Highlightr 包装
│   │
│   ├── Utils/                    # 工具层
│   │   ├── FileUtils.swift       # 文件读写
│   │   └── EncodingDetector.swift # 编码检测
│   │
│   ├── Resources/
│   │   └── markdown.css          # Markdown 样式
│   │
│   ├── Info.plist                # 权限声明
│   └── QuickPeek.entitlements    # Sandbox 配置
│
└── init-git.sh                   # Git 初始化脚本
```

## MVP 功能清单

✅ 全局热键监听（Cmd+Shift+Space 默认）
✅ Finder 文件检测（AppleScript）
✅ 文件类型分类（Markdown、代码、纯文本）
✅ Markdown 渲染（swift-markdown + WebView）
✅ 代码语法高亮（Highlightr）
✅ 浮动预览窗口（NSPanel）
✅ 编辑模式 + 行号显示
✅ 设置界面（快捷键配置、字体大小）
✅ Accessibility 权限处理

## 权限配置

**Info.plist：**
- `NSAppleEventsUsageDescription`: 与 Finder 通信获取选中文件

**QuickPeek.entitlements：**
- `com.apple.security.app-sandbox`: false（关闭 Sandbox）
- `com.apple.security.automation.apple-events`: true（允许 AppleScript）

## 常见问题

### Q: 编译报错 "Cannot find 'Markdown' in scope"

**A:** 需要通过 Xcode SPM 添加 swift-markdown 包：
```
File → Add Packages → https://github.com/apple/swift-markdown.git
```

### Q: 编译报错 "Cannot find 'Highlightr' in scope"

**A:** 需要通过 Xcode SPM 添加 Highlightr 包：
```
File → Add Packages → https://github.com/raspu/Highlightr.git
```

### Q: 快捷键不响应

**A:** 检查 Accessibility 权限：
```
系统偏好设置 → 安全性与隐私 → 辅助功能 → 添加 QuickPeek
```

## 技术栈

- Swift 5.9
- SwiftUI（MenuBarExtra）
- AppKit（NSPanel、NSEvent、NSAppleScript）
- swift-markdown 0.3.0+
- Highlightr 2.1.0+
- WebKit（Markdown HTML 渲染）

## License

MIT