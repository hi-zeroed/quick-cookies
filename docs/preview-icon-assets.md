# Preview Icon Assets

本文件定义文件预览链路中允许使用的“文件类型图标”资产。这里是长期维护基线，不记录临时替代方案。

## 当前规则

1. 文件类型图标必须由产品侧提供资产后再接入。
2. 资产缺失时，预览顶栏、重型预览占位、不支持文件页、图片信息区不使用 SF Symbols 或 macOS 系统文件图标兜底。
3. Toolbar、菜单栏、设置页、Onboarding、Toast 等通用操作图标不属于本文件范围。
4. 接入新图标时，只更新 `PreviewFileIconAssetRegistry`，不要在具体 View 中直接写资产名或 `Image(systemName:)`。

## 必需资产

| 资产文件名 | Asset Catalog 名称 | 图标类型 | 使用场景 |
| --- | --- | --- | --- |
| `PreviewFileMarkdown.svg` | `PreviewFileMarkdown` | Markdown 文件类型图标 | `.md`、`.markdown` 等 Markdown 预览 |
| `PreviewFileCode.svg` | `PreviewFileCode` | 代码/配置文件类型图标 | 代码、高亮文本、配置文件预览 |
| `PreviewFilePlainText.svg` | `PreviewFilePlainText` | 纯文本文件类型图标 | 未命中高亮语言的文本预览 |
| `PreviewFileImage.svg` | `PreviewFileImage` | 图片文件类型图标 | PNG、JPG、SVG、WebP 等图片预览 |
| `PreviewFilePDF.svg` | `PreviewFilePDF` | PDF 文件类型图标 | PDF 预览 |
| `PreviewFileOffice.svg` | `PreviewFileOffice` | Office/文档文件类型图标 | Word、Excel、PowerPoint、Pages、Numbers、Keynote、RTF、CSV |
| `PreviewFileUnsupported.svg` | `PreviewFileUnsupported` | 不支持文件类型图标 | 不支持文件、文件夹、运行时失败后的不支持状态 |

## 可选资产

| 资产文件名 | Asset Catalog 名称 | 图标类型 | 使用场景 |
| --- | --- | --- | --- |
| `PreviewImageLoadFailed.svg` | `PreviewImageLoadFailed` | 图片加载失败图标 | 图片文件无法解码时的错误区域 |
| `PreviewImageInfoDimensions.svg` | `PreviewImageInfoDimensions` | 图片尺寸信息图标 | 图片信息 badge 中的尺寸项 |
| `PreviewImageInfoFileSize.svg` | `PreviewImageInfoFileSize` | 文件大小信息图标 | 图片信息 badge 中的文件大小项 |
| `PreviewImageInfoSVG.svg` | `PreviewImageInfoSVG` | SVG 矢量信息图标 | SVG 图片信息 badge |

## 接入位置

文件类型图标的唯一接入入口是：

- `QuickCookies/UI/ContentView.swift` 中的 `PreviewFileIconAssetRegistry`

后续如果产品侧提供了资产，应按以下顺序接入：

1. 将 SVG 加入 `QuickCookies/Resources/Assets.xcassets`。
2. 在 `PreviewFileIconAssetRegistry.assetName(for:)` 中返回对应 Asset Catalog 名称。
3. 补充或更新 XCTest，确认 registry 不再依赖 SF Symbols 或系统文件图标。
4. 手工检查预览顶栏、PDF 占位、不支持文件页、图片信息区是否符合设计稿。
