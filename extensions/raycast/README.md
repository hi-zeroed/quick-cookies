# QuickCookies Raycast Extension

[QuickCookies](https://github.com/hi-zeroed/quick-cookies) 的官方 Raycast 扩展套件，为键盘流极客打造的 0ms 极致预览与代码卡片利器。

## 🌟 核心功能

1. **Preview Selected File (`preview-selected-file`)**：
   - 模式：`no-view`（极速静默触发）
   - 说明：从访达（Finder）或桌面中极速透视当前选中的文件，支持代码语法高亮、Markdown 渲染、CSV/TSV 数据表格、十六进制二进制探测等；
   - 快捷键建议：绑定全局快捷键（如 `⌥ Space`）。

2. **Preview Clipboard (`preview-clipboard`)**：
   - 模式：`no-view`
   - 说明：透视剪贴板中的任意文本、源代码、JSON 数据或图片，免存临时文件直接预览。

3. **Create Code Card (`create-code-card`)**：
   - 模式：`no-view`
   - 说明：将当前选中的代码文件或剪贴板代码直达 QuickCookies「代码卡片工坊 (Card Studio)」，一键定制窗口阴影、水滴圆角与渐变背景并导出高清 PNG。

4. **Search and Preview Files (`preview-file`)**：
   - 模式：`view`（交互式文件浏览）
   - 说明：在 Raycast 内搜索本地文件或快速切换常用目录（Desktop, Downloads, Documents 等），支持：
     - `Enter`：在 QuickCookies 浮层中秒开预览
     - `⌘ S`：直达代码分享卡片工坊
     - `⌘ C`：复制文件绝对路径
     - `⌘ ↵`：在访达中显示

## 🚀 本地开发与安装

### 方式一：Raycast 本地开发模式（Developer Mode）

1. 确保已安装 [Node.js](https://nodejs.org/)（v18+）与 [Raycast](https://raycast.com/)；
2. 进入本目录并安装依赖：
   ```bash
   cd extensions/raycast
   npm install
   ```
3. 启动 Raycast 扩展热重载：
   ```bash
   npm run dev
   ```
4. 此时打开 Raycast 搜索 `QuickCookies`，即可看到全部 4 个命令并可直接使用。

### 方式二：构建发布包

```bash
npm run build
```

## 🔗 URL Scheme 与协议说明

本扩展深度依赖 QuickCookies 原生 URL Scheme 协议：
- `quickcookies://preview?path=<encoded_path>`：打开指定路径
- `quickcookies://preview?source=clipboard`：透视剪贴板
- `quickcookies://preview?action=shareCard[&path=<encoded_path>]`：直达卡片工坊
- `quickcookies://preview?action=finderSelection`：透视访达选中项

## 📄 License
MIT
