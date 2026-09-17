# QuickCookies Alfred 5 Workflow

[QuickCookies](https://github.com/hi-zeroed/quick-cookies) 的官方 Alfred 5 原生工作流套件，为键盘流极客打造的 0ms 极致预览与代码卡片利器。

## 🌟 核心功能

### 1. File Actions（文件动作）
在 Alfred 中选中任意文件或目录，按下 `Tab` 或 `Right Arrow` 进入动作列表：
- **Preview in QuickCookies**：立即在 QuickCookies 浮层中秒开预览（支持高亮、Markdown、CSV 数据表、Hex 二进制等）；
- **Create Code Card with QuickCookies**：直达代码分享卡片工坊（Card Studio）。

### 2. Universal Action（全局动作）
在系统任意位置选中文件或文件路径文本，按下 Alfred Universal Action 全局快捷键：
- **Preview in QuickCookies**：一键透视。

### 3. Keyword 快捷指令
- `qc`：直接回车，立即透视访达（Finder）当前选中的文件；
- `qc <路径>`：透视指定路径文件（支持 `~` 用户目录展开）；
- `qcc`：透视剪贴板中的任意文本、源代码、JSON 数据或图片；
- `qcard`：直接唤起代码分享卡片工坊（优先嗅探剪贴板代码）；
- `qcard <路径>`：以指定代码文件直达卡片工坊。

## 🚀 安装指南

1. 双击本目录下的 **`QuickCookies.alfredworkflow`**；
2. 在 Alfred 弹窗中点击 **`Import`** 导入；
3. 即可立即在 Alfred 5 中使用全部指令与动作！

## 📦 自定义重新打包

如果修改了 `info.plist`，可运行以下命令更新工作流包：
```bash
cd extensions/alfred
zip -r QuickCookies.alfredworkflow info.plist icon.png
```

## 📄 License
MIT
