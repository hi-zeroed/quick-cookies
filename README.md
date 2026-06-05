<p align="center">
  <img src="QuickCookies/Resources/AppIcon_transparent.png" width="128" height="128" alt="Quick Cookies Logo">
</p>

<h1 align="center">Quick Cookies</h1>

<p align="center">
  <strong>An open-source, ultra-fast, card-style file preview and quick editing tool for macOS.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue?style=flat-square&logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/Language-Swift%205.9-orange?style=flat-square&logo=swift" alt="Language">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Icons-Remix%20Icon-blueviolet?style=flat-square&logo=remix-icon" alt="Icons">
</p>

<p align="center">
  <a href="README-cn.md">简体中文</a> •
  <a href="#-features">Features</a> •
  <a href="#-supported-file-types">Supported File Types</a> •
  <a href="#-project-architecture">Project Structure</a> •
  <a href="#-usage-guide">Usage Guide</a> •
  <a href="#-development--build">Development & Build</a> •
  <a href="#-contributing">Contributing</a> •
  <a href="#-license">License</a>
</p>

---

**Quick Cookies** is a lightweight, elegant card-style preview and editor utility designed specifically for macOS. It bypasses the tedious "double-click to open file" cycle by allowing users to instantly preview files with a global double <kbd>⌘ Command</kbd> hotkey and make quick edits directly inside the preview window.

The interface features a borderless frosted HUD card overlay with a golden-ratio reading width, accompanied by an `AXUIElement`-anchored physical spring fly-back animation. Seamlessly integrated with Finder, it brings an incredibly responsive, non-intrusive workspace boost to developers and writers.

---

## ✨ Features

- 🚀 **0ms Instant Pop-up Response**
  The overlay panel starts expanding instantly from your mouse position. Decryption, file loading, and code highlighting occur asynchronously in the background. The main thread is never blocked, eliminating visual hiccups.
- 📐 **Golden-Ratio Reading Layout**
  The card's width/height ratio has been strictly tuned (width `38%` : height `88%`) to mimic single-column book pages, which is perfect for reading code blocks, text document edits, and Markdown files.
- 🎨 **Modern HUD Glassmorphism**
  Enjoy a borderless frosted visual effect panel supporting click-and-drag from any empty workspace area. It dynamically adapts to Dark Mode, Light Mode, and system-adaptive schemes with crisp contrast.
- 📝 **Code Highlight & On-the-Fly Editing**
  Displays editor-grade line numbers and handles auto-wrapping. Press `Cmd + E` to transition into edit mode, modify text, and save changes using `Cmd + S`. Safe font fallback is active to safeguard layout sanity.
- 📊 **Office Documents & Rich Text Previews**
  Integrates a wrapped AppKit `QLPreviewView` to support 100% accurate format-rich preview of Word, Excel, PPT, iWork (Pages, Numbers, Keynote), PDF, RTF/RTFD, and CSV sheets. Applied 12px rounded corner cropping to avoid layered raw square borders.
- 💾 **Markdown-to-PDF Export**
  Export Markdown to styled PDFs matching GitHub's preview theme via `NSSavePanel` (pointing to the parent folder by default). Running offscreen `WKWebView` rendering and a local compiled `marked.js` engine, it features an in-place linear progress bar.
- 🔄 **0ms Hot Multilingual Switching**
  Provides complete native localization (English & 简体中文). You can toggle languages in the preference panel with zero lag; menu bars, statuses, and toast alerts refresh immediately.
- 🔌 **System-Level Native Integration**
  - **Adaptive Menubar Icon**: Features a single-color `Template` icon that automatically flips colors depending on system dark/light aesthetics.
  - **Scripting Bridge Hook**: Zero-overhead AppleEvent query retrieves active Finder selection in microseconds, falling back to a safe mouse-coordinate pop-up when permissions are off.
  - **matchedGeometry Spring Transition**: Utilizes `AXUIElement` recursive target searching to fly the preview card back to the exact Finder cell position during close.
  - **SMAppService Startup**: Integrates modern macOS 13+ ServiceManagement login item API for lightweight, silent, and sandboxed auto-launch.

---

## 📋 Supported File Types

### Code & Syntax Highlighting

Quick Cookies provides syntax highlighting for **30+ languages** across **60+ file extensions**:

| Language | Extensions |
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
| **SQL / INI / Config** | `sql` `ini` `conf` `config` `properties` `env` |
| **Docker / Make / Misc** | `dockerfile` `makefile` `log` `diff` `patch` `csv` `tsv` `lock` |

### Markdown

| Format | Extensions | Extra |
| :--- | :--- | :--- |
| Markdown | `md` `markdown` `mdown` `mdwn` `mkd` `mkdn` | Export to styled PDF via offscreen WebKit |

### Office & Rich Documents

| Format | Via |
| :--- | :--- |
| Word (`.doc` `.docx`) | Native `QLPreviewView` |
| Excel (`.xls` `.xlsx`) | Native `QLPreviewView` |
| PowerPoint (`.ppt` `.pptx`) | Native `QLPreviewView` |
| iWork — Pages, Numbers, Keynote | Native `QLPreviewView` |
| PDF | Native `QLPreviewView` |
| RTF / RTFD | Native `QLPreviewView` |

### Media

| Format | Extensions |
| :--- | :--- |
| Images | `png` `jpg` `jpeg` `gif` `bmp` `tiff` `webp` |

### Plain Text (Universal Fallback)

Files with extensions not explicitly listed above — and that pass the binary detection check — are opened as plain text with automatic encoding detection. No file left unviewable.

---

## 📂 Project Architecture

The codebase utilizes a modularized architectural pattern:

```
QuickCookies/
├── App/           # Lifecycle entries (AppDelegate, Onboarding, Configuration)
├── Core/          # Engine layers (Hotkey listening, ScriptingBridge hooks, FileWatcher changes)
├── UI/            # Layout views (Spring animations, CodeView, MarkdownView, UnsupportedFileView)
├── Renderer/      # Text engines (Highlightr wrappers, font caches, Markdown HTML preprocessing)
├── Resources/     # Graphic resources (Bundled JetBrains Mono fonts, Menubar SVG files, Onboarding assets)
└── Support/       # Sandboxing entitlements, startup services, and Info.plist configs
```

---

## 📥 Installation

### Option 1: Install via Homebrew Cask (Recommended 🍺)

This is the most convenient way to install and keep the application updated automatically. Simply run in your Terminal:

```bash
brew tap hi-zeroed/tap
brew install --cask quick-cookies
```

### Option 2: Download DMG Package Manually

1. Navigate to the [GitHub Releases](https://github.com/hi-zeroed/quick-cookies/releases) page and download the latest `QuickCookies-macOS.dmg` archive.
2. Double-click the DMG and drag `QuickCookies.app` into your **Applications** folder.
3. Due to the lack of an Apple Developer Program subscription, macOS Gatekeeper may block launch. Hold the **Control** key and right-click `QuickCookies.app` on the first launch, select **Open**, and click "Open" to save the exception.

---

## ⌨️ Usage Guide

Quick Cookies runs silently in the background. Use the following global keystrokes to control the workflow:

| Action                       | Shortcut (Kbd)                          | Description                                                                                                                                               |
| :--------------------------- | :-------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Instant Preview / Toggle** | <kbd>⌘ Command</kbd> <kbd>⌘ Command</kbd> | Double-click Command to open when a file is selected in Finder. Trigger again (or click background) to fade out and fly back. _(Configurable in Settings)_ |
| **Edit Mode Switch**         | <kbd>⌘ Command</kbd> + <kbd>E</kbd>     | Toggle between reader preview mode and editor text mode.                                                                                                  |
| **Save Modifications**       | <kbd>⌘ Command</kbd> + <kbd>S</kbd>     | Commit editor buffer changes back to the physical disk.                                                                                                   |
| **Dismiss Window**           | <kbd>Esc</kbd>                          | Close the window safely and shrink it back to Finder file icon.                                                                                           |

---

## 🛠 Development & Build

### Prerequisites

- **Operating System**: macOS 13.0 or higher
- **Compiler**: Xcode 14.0+ / Swift 5.9+
- **Dependency Manager**: Swift Package Manager (SPM)

### Third-Party Dependencies

The project uses SPM to load two external libraries:

1. **[MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)**: For rich, GitHub-like native Markdown rendering.
2. **[Highlightr](https://github.com/raspu/Highlightr)**: Syntactical coloring framework for coding templates.

### Compilation Steps

```bash
# 1. Clone the project and enter workspace
git clone https://github.com/hi-zeroed/quick-cookies.git
cd quick-cookies

# 2. Trigger clean Debug build phase
xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -configuration Debug -derivedDataPath Build/ clean build

# 3. Launch the compiled app bundle
open Build/Build/Products/Debug/QuickCookies.app
```

---

## 🤝 Contributing

We welcome contributions to Quick Cookies! If you want to fix bugs, propose features, or polish documents, please follow these guidelines:

### 1. Git Branch Model

- `main`: Represents validated, stable, production-ready releases.
- `develop`: Active integration branch. Submit your Pull Requests (PRs) targeting `develop`.

### 2. PR Checklist

Before submitting a PR, make sure you self-check:

1. **Xcode Build**: Build via command line to guarantee zero warnings and zero errors.

---

## 🎨 Asset Copyrights & Attributions

### 1. App Icon

The cartoon grid sandwich icon used in `AppIcon` is sourced from the [iconfont design platform (Collection ID: 15128)](https://www.iconfont.cn/collections/detail?cid=15128).

### 2. Custom Toolbar & SVG Icons

All custom SVGs mapped under UI items, preferences, and status menus are fetched from the open-source [Remix Icon](https://remixicon.com/) suite (Licensed under Apache License 2.0).

### 3. Commercial Use Caveat

- **Ownership**: Icons from iconfont belong to their uploading artists. The project does not hold proprietary copyrights.
- **Non-Commercial Exemption**: Safe for educational/non-commercial open-source fork deployments with attribution in README.
- **Commercial Release**: If you plan to sell or monetize this tool (e.g. Mac App Store), you must replace this logo asset with CC0/MIT vectors or get formal author sign-off.

---

## 📄 License

Quick Cookies is licensed under the [MIT License](LICENSE).
