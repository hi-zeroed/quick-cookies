import Foundation

enum CLIInstallLocation: String, CaseIterable {
    case usrLocalBin = "/usr/local/bin/qc"
    case userLocalBin = "~/.local/bin/qc"
    
    var expandedPath: String {
        switch self {
        case .usrLocalBin:
            return "/usr/local/bin/qc"
        case .userLocalBin:
            return NSString(string: "~/.local/bin/qc").expandingTildeInPath
        }
    }
}

struct CLIInstallStatus: Equatable {
    let isInstalled: Bool
    let installedPath: String?
    let version: String?
    
    init(isInstalled: Bool, installedPath: String? = nil, version: String? = nil) {
        self.isInstalled = isInstalled
        self.installedPath = installedPath
        self.version = version
    }
}

enum CLIInstallerPolicy {
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7.0"
    }
    
    /// 检查指定路径中的 qc 脚本状态
    static func checkStatus(
        fileManager: FileManager = .default,
        locations: [CLIInstallLocation] = CLIInstallLocation.allCases
    ) -> CLIInstallStatus {
        for location in locations {
            let path = location.expandedPath
            if fileManager.fileExists(atPath: path) {
                let version = extractVersion(from: path)
                return CLIInstallStatus(
                    isInstalled: true,
                    installedPath: path,
                    version: version
                )
            }
        }
        return CLIInstallStatus(isInstalled: false)
    }
    
    /// 从脚本文件中解析版本号
    static func extractVersion(from path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        // 解析形如 VERSION="1.6.0"
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("VERSION=") {
                let value = trimmed
                    .replacingOccurrences(of: "VERSION=", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
    
    /// 获取内置 qc 脚本的内容
    static func defaultScriptContent() -> String {
        """
        #!/bin/bash
        #
        # qc - QuickCookies 命令行快速预览工具
        # 用法: qc [选项] <文件或目录路径>
        #

        VERSION="\(currentVersion)"

        is_chinese() {
            case "${LC_ALL:-${LANG:-}}" in
                zh*|*zh_CN*|*zh_TW*|*zh_HK*) return 0 ;;
                *) return 1 ;;
            esac
        }

        show_help() {
            if is_chinese; then
                cat << EOF
        QuickCookies CLI (qc) v${VERSION}
        在访达与终端中极速预览代码、Markdown、配置、归档与各类文件。

        用法:
            qc <文件或目录路径>     在 QuickCookies 浮层中打开预览
            qc <文件路径:行号>      在浮层中打开并精准定位到指定行（如 qc App.swift:142）
            qc -l, --line <行号>   指定预览跳转的目标行号（如 qc -l 142 App.swift）
            qc .                   预览当前目录
            qc -c, --clipboard     透视剪贴板中的文本、代码、JSON 或图片
            qc -h, --help          查看帮助信息
            qc -v, --version       查看版本号

        示例:
            qc README.md
            qc src/main.swift:142
            qc -l 142 src/main.swift
            qc archive.zip
            qc -c
            qc .

        EOF
            else
                cat << EOF
        QuickCookies CLI (qc) v${VERSION}
        Instantly preview code, Markdown, configs, archives and files from Finder and Terminal.

        Usage:
            qc <file or directory path>    Open preview in QuickCookies overlay
            qc <file:line>                 Open preview and jump to target line (e.g. qc App.swift:142)
            qc -l, --line <number>         Specify target line number (e.g. qc -l 142 App.swift)
            qc .                           Preview current directory
            qc -c, --clipboard             Inspect text, code, JSON, or image from clipboard
            qc -h, --help                  Show help information
            qc -v, --version               Show version number

        Examples:
            qc README.md
            qc src/main.swift:142
            qc -l 142 src/main.swift
            qc archive.zip
            qc -c
            qc .

        EOF
            fi
        }

        # 寻找可用的 QuickCookies.app 路径，避免被系统中其它陈旧版本或历史构建拦截
        find_quickcookies_app() {
            # 1. 显式环境变量指定的 App 路径
            if [ -n "$QUICKCOOKIES_APP" ] && [ -d "$QUICKCOOKIES_APP" ]; then
                echo "$QUICKCOOKIES_APP"
                return 0
            fi

            # 2. 系统/用户标准安装目录 (生产环境)
            if [ -d "/Applications/QuickCookies.app" ]; then
                echo "/Applications/QuickCookies.app"
                return 0
            fi
            if [ -d "$HOME/Applications/QuickCookies.app" ]; then
                echo "$HOME/Applications/QuickCookies.app"
                return 0
            fi

            # 3. 检查当前或父级工作区中的本地开发构建产物 (开发调试场景)
            local cur_dir="$PWD"
            while [ "$cur_dir" != "/" ] && [ -n "$cur_dir" ]; do
                for candidate in \
                    "$cur_dir/buildClean/Build/Products/Debug/QuickCookies.app" \
                    "$cur_dir/build/Build/Products/Debug/QuickCookies.app" \
                    "$cur_dir/buildRelease/Build/Products/Release/QuickCookies.app"; do
                    if [ -d "$candidate" ]; then
                        echo "$candidate"
                        return 0
                    fi
                done
                cur_dir="$(dirname "$cur_dir")"
            done

            # 4. 系统 DerivedData 中的最新 Debug 产物
            local dd_match
            dd_match=$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/QuickCookies-*/Build/Products/Debug/QuickCookies.app 2>/dev/null | head -n 1)
            if [ -n "$dd_match" ] && [ -d "$dd_match" ]; then
                echo "$dd_match"
                return 0
            fi

            return 1
        }

        if [ $# -eq 0 ]; then
            show_help
            exit 0
        fi

        TARGET_LINE=""
        RAW_TARGET=""

        while [ $# -gt 0 ]; do
            case "$1" in
                -h|--help)
                    show_help
                    exit 0
                    ;;
                -v|--version)
                    echo "QuickCookies CLI (qc) v${VERSION}"
                    exit 0
                    ;;
                -c|--clipboard)
                    TARGET_APP="$(find_quickcookies_app 2>/dev/null)"
                    if [ -n "$TARGET_APP" ] && [ -d "$TARGET_APP" ]; then
                        open -a "$TARGET_APP" -g "quickcookies://preview?source=clipboard"
                    else
                        if pgrep -x "QuickCookies" >/dev/null 2>&1; then
                            open -b com.quickcookies.app -g "quickcookies://preview?source=clipboard"
                        else
                            if is_chinese; then
                                echo "qc: 未找到可用的 QuickCookies.app。" >&2
                                echo "请先启动 QuickCookies，或将其安装至 /Applications 目录。" >&2
                            else
                                echo "qc: QuickCookies.app not found." >&2
                                echo "Please launch QuickCookies first or install it to /Applications." >&2
                            fi
                            exit 1
                        fi
                    fi
                    exit 0
                    ;;
                -l|--line)
                    if [ -n "$2" ]; then
                        TARGET_LINE="$2"
                        shift 2
                    else
                        shift
                    fi
                    ;;
                *)
                    if [ -z "$RAW_TARGET" ]; then
                        RAW_TARGET="$1"
                    fi
                    shift
                    ;;
            esac
        done

        if [ -z "$RAW_TARGET" ]; then
            show_help
            exit 0
        fi

        TARGET="$RAW_TARGET"

        # 若目标文件未直接存在，尝试剥离 file:line 或 file:line:col 模式
        if [ ! -e "$TARGET" ]; then
            case "$TARGET" in
                *:*:[0-9]*)
                    CANDIDATE="${TARGET%:*:*}"
                    POSSIBLE_LINE="${TARGET%:[0-9]*}"
                    POSSIBLE_LINE="${POSSIBLE_LINE##*:}"
                    if [ -e "$CANDIDATE" ] && [ -n "$POSSIBLE_LINE" ]; then
                        TARGET="$CANDIDATE"
                        [ -z "$TARGET_LINE" ] && TARGET_LINE="$POSSIBLE_LINE"
                    fi
                    ;;
                *:[0-9]*)
                    CANDIDATE="${TARGET%:*}"
                    POSSIBLE_LINE="${TARGET##*:}"
                    if [ -e "$CANDIDATE" ] && [ -n "$POSSIBLE_LINE" ]; then
                        TARGET="$CANDIDATE"
                        [ -z "$TARGET_LINE" ] && TARGET_LINE="$POSSIBLE_LINE"
                    fi
                    ;;
            esac
        fi

        # 检查目标文件或目录是否存在
        if [ ! -e "$TARGET" ]; then
            if is_chinese; then
                echo "qc: 找不到指定的文件或目录: $TARGET" >&2
            else
                echo "qc: Cannot find specified file or directory: $TARGET" >&2
            fi
            exit 1
        fi

        # 获取绝对物理路径
        if [ -d "$TARGET" ]; then
            ABS_PATH="$(cd "$TARGET" 2>/dev/null && pwd -P)"
        else
            DIR="$(dirname "$TARGET")"
            BASE="$(basename "$TARGET")"
            ABS_DIR="$(cd "$DIR" 2>/dev/null && pwd -P)"
            ABS_PATH="${ABS_DIR}/${BASE}"
        fi

        if [ -z "$ABS_PATH" ] || [ ! -e "$ABS_PATH" ]; then
            if is_chinese; then
                echo "qc: 无法解析绝对路径: $TARGET" >&2
            else
                echo "qc: Cannot resolve absolute path: $TARGET" >&2
            fi
            exit 1
        fi

        # 对路径进行 URL 编码
        python_urlencode() {
            python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$1" 2>/dev/null
        }

        ENCODED_PATH="$(python_urlencode "$ABS_PATH")"

        if [ -z "$ENCODED_PATH" ]; then
            ENCODED_PATH="$ABS_PATH"
        fi

        TARGET_APP="$(find_quickcookies_app 2>/dev/null)"

        FINAL_URL="quickcookies://preview?path=${ENCODED_PATH}"
        if [ -n "$TARGET_LINE" ]; then
            FINAL_URL="${FINAL_URL}&line=${TARGET_LINE}"
        fi

        if [ -n "$TARGET_APP" ] && [ -d "$TARGET_APP" ]; then
            # 精确定向唤起指定应用，避免被系统中其它陈旧或脏版本（如 QuickView/历史构建）拦截
            open -a "$TARGET_APP" -g "$FINAL_URL"
        else
            # 兜底：若系统已有实例在运行，尝试以 bundle id 发送
            if pgrep -x "QuickCookies" >/dev/null 2>&1; then
                open -b com.quickcookies.app -g "$FINAL_URL"
            else
                if is_chinese; then
                    echo "qc: 未找到可用的 QuickCookies.app。" >&2
                    echo "请先启动 QuickCookies，或将其安装至 /Applications 目录。" >&2
                else
                    echo "qc: QuickCookies.app not found." >&2
                    echo "Please launch QuickCookies first or install it to /Applications." >&2
                fi
                exit 1
            fi
        fi
        exit 0

        """
    }
    
    /// 执行一键安装到指定目录
    @discardableResult
    static func install(
        to targetLocation: CLIInstallLocation = .usrLocalBin,
        fileManager: FileManager = .default
    ) -> Result<String, Error> {
        let destPath = targetLocation.expandedPath
        let destDir = (destPath as NSString).deletingLastPathComponent
        let script = defaultScriptContent()
        
        // 尝试免权限直接写
        do {
            if !fileManager.fileExists(atPath: destDir) {
                try fileManager.createDirectory(atPath: destDir, withIntermediateDirectories: true)
            }
            if fileManager.fileExists(atPath: destPath) {
                try fileManager.removeItem(atPath: destPath)
            }
            try script.write(toFile: destPath, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
            return .success(destPath)
        } catch {
            // 如果无权限写入 /usr/local/bin，且目标是 usrLocalBin，尝试 AppleScript 提权安装
            if targetLocation == .usrLocalBin {
                let tempPath = NSTemporaryDirectory() + "qc_\(UUID().uuidString)"
                do {
                    try script.write(toFile: tempPath, atomically: true, encoding: .utf8)
                    let appleScriptCmd = "do shell script \"mkdir -p /usr/local/bin && cp '\(tempPath)' '/usr/local/bin/qc' && chmod +x '/usr/local/bin/qc' && rm -f '\(tempPath)'\" with administrator privileges"
                    if let appleScript = NSAppleScript(source: appleScriptCmd) {
                        var errorDict: NSDictionary?
                        appleScript.executeAndReturnError(&errorDict)
                        if let errorDict = errorDict {
                            let msg = errorDict[NSAppleScript.errorMessage] as? String ?? "Authorization failed"
                            return .failure(NSError(domain: "CLIInstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: msg]))
                        }
                        return .success(destPath)
                    }
                } catch {
                    return .failure(error)
                }
            }
            return .failure(error)
        }
    }
    
    /// 执行卸载
    @discardableResult
    static func uninstall(
        from targetLocation: CLIInstallLocation = .usrLocalBin,
        fileManager: FileManager = .default
    ) -> Result<Void, Error> {
        let destPath = targetLocation.expandedPath
        guard fileManager.fileExists(atPath: destPath) else {
            return .success(())
        }
        
        do {
            try fileManager.removeItem(atPath: destPath)
            return .success(())
        } catch {
            if targetLocation == .usrLocalBin {
                let appleScriptCmd = "do shell script \"rm -f '/usr/local/bin/qc'\" with administrator privileges"
                if let appleScript = NSAppleScript(source: appleScriptCmd) {
                    var errorDict: NSDictionary?
                    appleScript.executeAndReturnError(&errorDict)
                    if let errorDict = errorDict {
                        let msg = errorDict[NSAppleScript.errorMessage] as? String ?? "Authorization failed"
                        return .failure(NSError(domain: "CLIInstaller", code: 2, userInfo: [NSLocalizedDescriptionKey: msg]))
                    }
                    return .success(())
                }
            }
            return .failure(error)
        }
    }
}
