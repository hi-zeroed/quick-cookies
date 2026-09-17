import Foundation
import ImageIO
import AVFoundation

enum TelemetryExtractor {
    
    /// 异步从指定路径提炼工程元数据
    static func extract(
        from path: String,
        renderType: FileRenderType,
        existingContent: String? = nil
    ) async -> TelemetryReport {
        return await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            var items: [TelemetryItem] = []
            
            switch renderType {
            case .code, .plainText, .markdown:
                items = extractTextTelemetry(url: url, renderType: renderType, existingContent: existingContent)
            case .image:
                items = extractImageTelemetry(url: url)
            case .audio:
                items = extractAudioTelemetry(url: url)
            case .video:
                items = extractVideoTelemetry(url: url)
            case .font:
                items = extractFontTelemetry(url: url)
            case .archive, .folder, .pdf, .office, .unsupported:
                items = extractGenericTelemetry(url: url)
            }
            
            return TelemetryReport(items: items)
        }.value
    }
    
    // MARK: - 文本与代码提炼
    
    static func extractTextTelemetry(
        url: URL,
        renderType: FileRenderType,
        existingContent: String?
    ) -> [TelemetryItem] {
        var items: [TelemetryItem] = []
        let text: String
        let isPartial: Bool
        
        if let existing = existingContent, !existing.isEmpty {
            text = existing
            isPartial = false
        } else {
            let maxBytes = 2 * 1024 * 1024 // 2MB
            if let fileHandle = try? FileHandle(forReadingFrom: url) {
                defer { try? fileHandle.close() }
                let data = fileHandle.readData(ofLength: maxBytes)
                let encoding = EncodingDetector.detect(data: data)
                let decoded = String(data: data, encoding: encoding) ?? ""
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
                isPartial = fileSize > UInt64(maxBytes)
                text = decoded
            } else {
                text = ""
                isPartial = false
            }
        }
        
        guard !text.isEmpty else {
            return extractGenericTelemetry(url: url)
        }
        
        // 1. 换行符类型检测
        let hasCRLF = text.contains("\r\n")
        let hasCR = !hasCRLF && text.contains("\r")
        let hasLF = text.contains("\n")
        let formatStr: String
        if hasCRLF && hasLF && text.replacingOccurrences(of: "\r\n", with: "").contains("\n") {
            formatStr = "Mixed"
        } else if hasCRLF {
            formatStr = "CRLF"
        } else if hasCR {
            formatStr = "CR"
        } else {
            formatStr = "LF"
        }
        
        // 2. 统计行、LoC、注释与空行
        let lines = text.components(separatedBy: "\n")
        let totalLines = lines.count
        var blankCount = 0
        var commentCount = 0
        var locCount = 0
        
        let ext = url.pathExtension.lowercased()
        let isJSON = ext == "json"
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                blankCount += 1
            } else if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") || trimmed.hasPrefix("--") ||
                        trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") || trimmed.hasPrefix("<!--") {
                commentCount += 1
            } else {
                locCount += 1
            }
        }
        
        let lineSuffix = isPartial ? "+" : ""
        items.append(TelemetryItem(
            id: "lines",
            label: "Lines".localized(),
            value: "\(formatNumber(totalLines))\(lineSuffix)"
        ))
        
        if renderType == .code {
            items.append(TelemetryItem(
                id: "loc",
                label: "LoC".localized(),
                value: "\(formatNumber(locCount))\(lineSuffix)",
                tooltip: "Lines of Code (excluding blank & comments)"
            ))
            items.append(TelemetryItem(
                id: "comments",
                label: "Comments".localized(),
                value: "\(formatNumber(commentCount))\(lineSuffix)"
            ))
        }
        
        items.append(TelemetryItem(
            id: "blank",
            label: "Blank".localized(),
            value: "\(formatNumber(blankCount))\(lineSuffix)"
        ))
        
        items.append(TelemetryItem(
            id: "format",
            label: "Format".localized(),
            value: formatStr
        ))
        
        // 3. 编码检测
        let encodingName: String
        if let data = (try? Data(contentsOf: url, options: .alwaysMapped)) ?? text.data(using: .utf8) {
            let enc = EncodingDetector.detect(data: data)
            encodingName = friendlyEncodingName(enc)
        } else {
            encodingName = "UTF-8"
        }
        items.append(TelemetryItem(
            id: "encoding",
            label: "Encoding".localized(),
            value: encodingName
        ))
        
        // 4. JSON 特殊元数据提炼
        if isJSON, let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            if let dict = json as? [String: Any] {
                items.append(TelemetryItem(
                    id: "json_keys",
                    label: "Keys".localized(),
                    value: "\(dict.count) keys"
                ))
                items.append(TelemetryItem(
                    id: "json_depth",
                    label: "Depth".localized(),
                    value: "L\(calculateJSONDepth(dict, current: 1))"
                ))
            } else if let arr = json as? [Any] {
                items.append(TelemetryItem(
                    id: "json_items",
                    label: "Items".localized(),
                    value: "\(arr.count) items"
                ))
                items.append(TelemetryItem(
                    id: "json_depth",
                    label: "Depth".localized(),
                    value: "L\(calculateJSONDepth(arr, current: 1))"
                ))
            }
        }
        
        return items
    }
    
    // MARK: - 图像与矢量提炼
    
    static func extractImageTelemetry(url: URL) -> [TelemetryItem] {
        var items: [TelemetryItem] = []
        let ext = url.pathExtension.lowercased()
        
        if ext == "svg" {
            items.append(TelemetryItem(id: "type", label: "Type".localized(), value: "Vector (SVG)"))
            if let data = try? Data(contentsOf: url), let content = String(data: data, encoding: .utf8) {
                if let (w, h) = parseSVGDimensions(content) {
                    items.append(TelemetryItem(id: "viewbox", label: "ViewBox".localized(), value: "\(w) × \(h)"))
                }
            }
            items.append(contentsOf: extractGenericTelemetry(url: url))
            return items
        }
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return extractGenericTelemetry(url: url)
        }
        
        guard let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return extractGenericTelemetry(url: url)
        }
        
        let width = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        
        if width > 0 && height > 0 {
            items.append(TelemetryItem(
                id: "resolution",
                label: "Resolution".localized(),
                value: "\(width) × \(height) px"
            ))
            
            // 比例 / Retina 检测
            let fileName = url.deletingPathExtension().lastPathComponent
            let dpiX = props[kCGImagePropertyDPIWidth] as? Double ?? 72.0
            if fileName.contains("@3x") || dpiX >= 216.0 {
                let logicalW = width / 3
                let logicalH = height / 3
                items.append(TelemetryItem(id: "scale", label: "Scale".localized(), value: "@3x (\(logicalW)×\(logicalH) pt)"))
            } else if fileName.contains("@2x") || dpiX >= 144.0 {
                let logicalW = width / 2
                let logicalH = height / 2
                items.append(TelemetryItem(id: "scale", label: "Scale".localized(), value: "@2x (\(logicalW)×\(logicalH) pt)"))
            } else {
                items.append(TelemetryItem(id: "scale", label: "Scale".localized(), value: "@1x"))
            }
        }
        
        // 色彩空间
        let colorModel = props[kCGImagePropertyColorModel] as? String
        let profileName = props[kCGImagePropertyProfileName] as? String
        let colorSpaceStr = profileName ?? colorModel ?? "sRGB"
        items.append(TelemetryItem(
            id: "color_space",
            label: "Color Space".localized(),
            value: colorSpaceStr
        ))
        
        // 位深与透明度
        if let depth = props[kCGImagePropertyDepth] as? Int {
            items.append(TelemetryItem(
                id: "depth",
                label: "Bit Depth".localized(),
                value: "\(depth)-bit"
            ))
        }
        
        if let hasAlpha = props[kCGImagePropertyHasAlpha] as? Bool {
            items.append(TelemetryItem(
                id: "alpha",
                label: "Alpha".localized(),
                value: hasAlpha ? "Yes".localized() : "No".localized()
            ))
        }
        
        return items
    }
    
    // MARK: - 音频提炼
    
    static func extractAudioTelemetry(url: URL) -> [TelemetryItem] {
        var items: [TelemetryItem] = []
        let asset = AVURLAsset(url: url)
        
        let seconds = CMTimeGetSeconds(asset.duration)
        if !seconds.isNaN && seconds > 0 {
            let m = Int(seconds) / 60
            let s = Int(seconds) % 60
            items.append(TelemetryItem(
                id: "duration",
                label: "Duration".localized(),
                value: String(format: "%02d:%02d", m, s)
            ))
        }
        
        if let track = asset.tracks(withMediaType: .audio).first {
            let formatDescriptions = track.formatDescriptions as? [CMAudioFormatDescription]
            if let desc = formatDescriptions?.first,
               let basicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
                let sampleRate = basicDesc.mSampleRate
                let channels = basicDesc.mChannelsPerFrame
                
                if sampleRate > 0 {
                    let khz = sampleRate / 1000.0
                    items.append(TelemetryItem(
                        id: "sample_rate",
                        label: "Sample Rate".localized(),
                        value: String(format: "%.1f kHz", khz)
                    ))
                }
                
                if channels > 0 {
                    let channelStr: String
                    if channels == 1 { channelStr = "Mono (1ch)" }
                    else if channels == 2 { channelStr = "Stereo (2ch)" }
                    else { channelStr = "\(channels) ch" }
                    items.append(TelemetryItem(
                        id: "channels",
                        label: "Channels".localized(),
                        value: channelStr
                    ))
                }
            }
        }
        
        items.append(contentsOf: extractGenericTelemetry(url: url))
        return items
    }
    
    // MARK: - 视频提炼
    
    static func extractVideoTelemetry(url: URL) -> [TelemetryItem] {
        var items: [TelemetryItem] = []
        let asset = AVURLAsset(url: url)
        
        let seconds = CMTimeGetSeconds(asset.duration)
        if !seconds.isNaN && seconds > 0 {
            let h = Int(seconds) / 3600
            let m = (Int(seconds) % 3600) / 60
            let s = Int(seconds) % 60
            let durStr = h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
            items.append(TelemetryItem(
                id: "duration",
                label: "Duration".localized(),
                value: durStr
            ))
        }
        
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            let size = videoTrack.naturalSize
            if size.width > 0 && size.height > 0 {
                items.append(TelemetryItem(
                    id: "resolution",
                    label: "Resolution".localized(),
                    value: "\(Int(size.width)) × \(Int(size.height))"
                ))
            }
            let fps = videoTrack.nominalFrameRate
            if fps > 0 {
                items.append(TelemetryItem(
                    id: "fps",
                    label: "FPS".localized(),
                    value: String(format: "%.0f fps", fps)
                ))
            }
        }
        
        items.append(contentsOf: extractGenericTelemetry(url: url))
        return items
    }
    
    // MARK: - 字体提炼
    
    static func extractFontTelemetry(url: URL) -> [TelemetryItem] {
        var items: [TelemetryItem] = []
        let ext = url.pathExtension.lowercased()
        
        let formatStr: String
        switch ext {
        case "otf": formatStr = "OpenType (OTF)"
        case "ttf": formatStr = "TrueType (TTF)"
        case "woff": formatStr = "Web Open Font (WOFF)"
        case "woff2": formatStr = "Web Open Font 2 (WOFF2)"
        default: formatStr = ext.uppercased()
        }
        
        items.append(TelemetryItem(id: "format", label: "Format".localized(), value: formatStr))
        items.append(contentsOf: extractGenericTelemetry(url: url))
        return items
    }
    
    // MARK: - 通用属性提炼
    
    static func extractGenericTelemetry(url: URL) -> [TelemetryItem] {
        var items: [TelemetryItem] = []
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return items
        }
        
        if let size = attrs[.size] as? UInt64 {
            items.append(TelemetryItem(
                id: "file_size",
                label: "Size".localized(),
                value: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            ))
        }
        
        if let posix = attrs[.posixPermissions] as? NSNumber {
            let octal = String(posix.intValue, radix: 8)
            items.append(TelemetryItem(
                id: "permissions",
                label: "Permissions".localized(),
                value: octal
            ))
        }
        
        return items
    }
    
    // MARK: - 工具函数
    
    private static func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
    
    private static func friendlyEncodingName(_ enc: String.Encoding) -> String {
        switch enc {
        case .utf8: return "UTF-8"
        case .utf16, .utf16BigEndian, .utf16LittleEndian: return "UTF-16"
        case .ascii: return "ASCII"
        case .isoLatin1: return "ISO-8859-1"
        default:
            return CFStringGetNameOfEncoding(CFStringConvertNSStringEncodingToEncoding(enc.rawValue)) as String? ?? "UTF-8"
        }
    }
    
    private static func calculateJSONDepth(_ obj: Any, current: Int, maxAllowed: Int = 15) -> Int {
        if current >= maxAllowed { return current }
        if let dict = obj as? [String: Any] {
            var maxD = current
            for (_, val) in dict {
                let d = calculateJSONDepth(val, current: current + 1, maxAllowed: maxAllowed)
                if d > maxD { maxD = d }
            }
            return maxD
        } else if let arr = obj as? [Any] {
            var maxD = current
            for val in arr {
                let d = calculateJSONDepth(val, current: current + 1, maxAllowed: maxAllowed)
                if d > maxD { maxD = d }
            }
            return maxD
        }
        return current
    }
    
    private static func parseSVGDimensions(_ svg: String) -> (Int, Int)? {
        let pattern = "viewBox=[\"'][0-9.\\s]+?([0-9.]+)[\\s,]+([0-9.]+)[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: svg, options: [], range: NSRange(location: 0, length: min(svg.utf16.count, 2048))) {
            let ns = svg as NSString
            let wStr = ns.substring(with: match.range(at: 1))
            let hStr = ns.substring(with: match.range(at: 2))
            if let w = Double(wStr), let h = Double(hStr) {
                return (Int(w), Int(h))
            }
        }
        return nil
    }
}
