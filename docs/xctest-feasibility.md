# Quick Cookies 项目集成 XCTest 可行性评估

本文基于 **当前 Quick Cookies 工程现状**，评估引入 **XCTest** 的可行性、首期建议范围，以及落地时需要注意的限制。

---

## 1. 结论

**结论：可行，且值得做，但建议分阶段推进。**

以当前工程结构来看，Quick Cookies 已具备接入 XCTest 的基础条件，但并不适合一开始就把所有模块都纳入自动化测试。更现实的路径是：

1. 先创建 `QuickCookiesTests` target。
2. 首期只覆盖纯逻辑模块与文件处理模块。
3. 对 Finder、快捷键、WebKit、登录项等系统依赖较强的模块，先做隔离和重构，再进入测试。

换句话说，**“接入 XCTest” 本身完全可行**，但 **“现阶段即可全面自动化测试所有核心模块” 并不准确**。

---

## 2. 当前工程现状

结合当前仓库结构，可以确认以下几点：

### 2.1 已具备的条件

* 工程已开启 `ENABLE_TESTABILITY = YES`，支持后续使用 `@testable import QuickCookies`。
* 核心逻辑代码已按职责拆分，存在一批天然适合单元测试的模块：
  * `EncodingDetector`
  * `FileTypeClassifier`
  * `FileChunkReader`
  * `FileUtils`

### 2.2 当前缺少的部分

* 目前工程里**还没有**测试 target，例如 `QuickCookiesTests`。
* 当前 shared scheme 的 `Test` 配置为空，尚未关联任何测试 bundle。
* 部分模块虽然逻辑上值得测试，但实现上直接依赖系统能力，不适合首期直接纳入 CI：
  * `FileDetector`：直接调用 `NSAppleScript` 和 Finder
  * `HotkeyManager`：依赖辅助功能权限、全局热键
  * `Settings`：依赖 `UserDefaults`、窗口更新、登录项注册
  * `MarkdownPDFExporter`：依赖 `WKWebView`、主线程、异步页面加载

---

## 3. 按当前现状的可测试性分层

### 3.1 第一层：首期推荐，直接落地

这部分适合作为 XCTest 接入的第一阶段，目标是尽快建立稳定、低维护成本的测试基础。

| 模块 | 可行性 | 说明 |
| :--- | :---: | :--- |
| `EncodingDetector` | 高 | 输入输出明确，可直接构造 `Data` 测试不同编码和异常字节流。 |
| `FileTypeClassifier` | 高 | 可通过临时文件覆盖扩展名映射、特殊文件名、二进制快速检测。 |
| `FileChunkReader` | 高 | 可用临时文件测试分块读取、边界、关闭句柄后的行为、二进制拦截。 |
| `FileUtils` | 中到高 | 适合覆盖路径处理、符号链接、相对路径转换等纯文件逻辑。 |

**这一层最适合首期落地，也最有机会稳定运行在 CI 中。**

### 3.2 第二层：可以测试，但应先做隔离

这部分不建议在当前实现上直接写测试，而应先拆出可注入边界。

| 模块 | 当前可测性 | 原因 | 建议 |
| :--- | :---: | :--- | :--- |
| `FileDetector` | 中 | 当前直接调用 Finder 和 AppleScript。 | 抽象脚本执行与 Finder 状态查询，再用 mock 验证逻辑分支。 |
| `Settings` | 中 | 属性写入伴随窗口刷新、语言切换、登录项同步。 | 拆分 `UserDefaults`、UI 更新、`SMAppService` 副作用。 |
| `MarkdownPDFExporter` | 中偏低 | 依赖 `WKWebView`、主线程和异步渲染。 | 先把 HTML 构造逻辑拆出来，优先测试纯字符串生成部分。 |

### 3.3 第三层：不建议首期纳入自动化

| 模块 | 当前可测性 | 原因 |
| :--- | :---: | :--- |
| `HotkeyManager` | 低 | 涉及 AX 权限、全局事件与宿主环境，CI 稳定性差。 |
| 真实 Finder 集成链路 | 低 | 依赖 GUI 状态、Finder 行为和系统授权。 |
| 真实 WebKit PDF 导出链路 | 低到中 | 本地可做探索性验证，但不建议首期承诺为稳定 CI 用例。 |

---

## 4. 首期推荐测试范围

如果目标是尽快让 Quick Cookies 拥有可运行、可维护的 XCTest 基础，建议首期只做以下内容：

### 4.1 `EncodingDetector`

建议覆盖：

* UTF-8 文本识别
* UTF-16 BOM 识别
* GB18030 / GBK 文本识别
* 非法字节流的默认回退行为

### 4.2 `FileTypeClassifier`

建议覆盖：

* Markdown、代码、图片、PDF、Office 文件分类
* `Makefile` / `Dockerfile` 这类无扩展名文件
* 包含 `NULL` 字节的二进制文件识别
* 不存在路径、目录路径的处理

### 4.3 `FileChunkReader`

建议覆盖：

* 小文件一次读完
* 大文件分块读取与 `hasMore`
* 关闭句柄后再次读取
* 首块二进制检测
* 文件不存在、无权限等错误返回

### 4.4 `FileUtils`

建议优先挑纯函数或低副作用方法：

* 符号链接解析
* 路径规范化
* Markdown 相对资源路径转换

---

## 5. 暂不建议直接承诺的模块

下面这些模块不是“不能测”，而是**当前实现形态下不适合直接写成稳定单测**：

### 5.1 `FileDetector`

当前实现直接依赖：

* Finder 是否运行
* `NSAppleScript` 是否执行成功
* 当前 Finder 选中状态

这意味着它更像系统集成能力，而不是纯逻辑单元。若直接写测试，很容易出现：

* 本机能跑，CI 跑不了
* 与 Finder 当前状态耦合
* 权限弹窗或无头环境导致失败

### 5.2 `Settings`

`Settings` 看起来像配置对象，但当前实现混合了多种副作用：

* `UserDefaults` 持久化
* UI 外观更新
* 窗口标题更新
* `SMAppService` 登录项同步

因此它不适合作为“高可行、可直接 CI 的应用单测”对象，更适合作为后续重构目标。

### 5.3 `MarkdownPDFExporter`

当前实现依赖：

* `WKWebView`
* 主线程调度
* 异步导航完成回调
* 页面渲染时机
* 外部高亮脚本资源加载

这类能力更接近集成测试，不建议在首期把它写进“100% 自动化支持”的范围。

---

## 6. 工程接入建议

### 步骤 1：创建测试 Target

在 `QuickCookies.xcodeproj` 中新增 macOS Unit Testing Bundle，命名为 `QuickCookiesTests`。

### 步骤 2：关联 Scheme

将 `QuickCookiesTests` 加入 `QuickCookies` scheme 的 `Test` 配置，保证 `Cmd + U` 可运行测试。

### 步骤 3：先补最小测试集

建议先补：

* `EncodingDetectorTests`
* `FileTypeClassifierTests`
* `FileChunkReaderTests`
* `FileUtilsTests`

首期目标不是追求覆盖率数字，而是建立一条稳定、可信的测试链路。

### 步骤 4：再考虑 CI

当本地 `xcodebuild test` 稳定后，再接入 GitHub Actions。这样能避免把“工程尚未测试化”的问题直接带进 CI 配置阶段。

---

## 7. 命令行与 CI 建议

### 7.1 本地命令

完成测试 target 和 scheme 配置后，可使用：

```bash
xcodebuild test \
  -project QuickCookies.xcodeproj \
  -scheme QuickCookies \
  -destination 'platform=macOS' \
  -derivedDataPath ./buildTest
```

### 7.2 CI 建议

GitHub Actions 接入方向是可行的，但建议满足以下前提后再启用：

* 本地 `xcodebuild test` 已稳定
* 首期测试只覆盖第一层模块
* 不把 Finder / 热键 / WebKit 真实链路作为 CI 必过项

如需在 GitHub Actions 中关闭签名限制，可补充：

```bash
CODE_SIGN_IDENTITY="" \
CODE_SIGNING_REQUIRED=NO \
CODE_SIGNING_ALLOWED=NO
```

此外，若项目依赖 Swift Package Manager，建议缓存相关依赖目录，减少首次构建时间。

---

## 8. 风险与限制

### 8.1 系统权限相关能力不适合首期自动化

包括但不限于：

* Finder 交互
* Apple Events
* 辅助功能权限
* 全局快捷键

这些能力应视为后续的集成测试或手工验证范围，而不是首期单测目标。

### 8.2 文件测试应限制在临时目录

建议统一使用 `NSTemporaryDirectory()` 创建测试文件，避免依赖用户目录、外部权限或本机特定文件结构。

### 8.3 不要把“可重构后可测”写成“当前已可直接测”

这是本项目文档最需要避免的表述偏差。对后续排期来说，区分下面两类结论很重要：

* 当前可直接写测试
* 需要先重构再写测试

---

## 9. 最终建议

如果目标是让 Quick Cookies 在短时间内获得真正有价值的自动化测试能力，推荐采用下面的落地策略：

1. 本周只接入 `QuickCookiesTests` 基础设施。
2. 首期只覆盖 `EncodingDetector`、`FileTypeClassifier`、`FileChunkReader`、`FileUtils`。
3. 暂不把 `Settings`、`MarkdownPDFExporter`、`FileDetector`、`HotkeyManager` 纳入“必须自动化”的范围。
4. 等测试基础跑通后，再按模块逐步做解耦与补测。

**结论并不是“XCTest 不适合这个项目”，而是“非常适合，但应该从最容易稳定落地的层开始”。**
