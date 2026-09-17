import Foundation
import AppKit

/// 剪贴板内容类型嗅探结果
enum ClipboardSniffResult: Equatable {
    case fileURL(path: String)
    case image(data: Data)
    case json(formattedContent: String)
    case code(content: String, language: String, fileExtension: String)
    case markdown(content: String)
    case plainText(content: String)
    case empty
}

/// 剪贴板内容智能分析器与受管临时文件落地器
enum ClipboardContentSniffer {
    
    /// 受管剪贴板临时文件缓存目录
    static var cacheDirectory: URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("QuickCookiesClipboard", isDirectory: true)
    }
    
    /// 嗅探 NSPasteboard 中的内容类型
    static func sniff(pasteboard: NSPasteboard = .general) -> ClipboardSniffResult {
        // 1. 优先检查是否存在复制的文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = urls.first,
           firstURL.isFileURL {
            let path = firstURL.path
            if FileManager.default.fileExists(atPath: path) {
                return .fileURL(path: path)
            }
        }
        
        // 2. 检查是否有复制的图片对象
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let firstImage = images.first,
           let tiffData = firstImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            return .image(data: pngData)
        }
        
        // 3. 检查是否有纯文本
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 3.1 检查文本是否本身是一个有效的本地文件绝对路径
            if (trimmed.hasPrefix("/") || trimmed.hasPrefix("file://")),
               let url = trimmed.hasPrefix("file://") ? URL(string: trimmed) : URL(fileURLWithPath: trimmed),
               FileManager.default.fileExists(atPath: url.path) {
                return .fileURL(path: url.path)
            }
            
            // 3.2 检查是否为合法的 JSON 数据
            if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
                if let jsonData = trimmed.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    return .json(formattedContent: prettyString)
                }
            }
            
            // 3.3 检查是否为典型的编程语言代码
            if let codeLang = detectProgrammingLanguage(in: trimmed) {
                return .code(content: text, language: codeLang.language, fileExtension: codeLang.fileExtension)
            }
            
            // 3.4 检查是否为 Markdown
            if isMarkdownContent(trimmed) {
                return .markdown(content: text)
            }
            
            // 3.5 纯文本兜底
            return .plainText(content: text)
        }
        
        return .empty
    }
    
    /// 将嗅探结果落地为受管临时文件，返回对应路径与标题
    static func materialize(result: ClipboardSniffResult) throws -> (filePath: String, displayName: String)? {
        switch result {
        case .empty:
            return nil
            
        case .fileURL(let path):
            return (path, URL(fileURLWithPath: path).lastPathComponent)
            
        case .image(let data):
            let fileURL = try prepareTemporaryFile(named: "clipboard.png")
            try data.write(to: fileURL)
            return (fileURL.path, "Clipboard Image (PNG)".localized())
            
        case .json(let formattedContent):
            let fileURL = try prepareTemporaryFile(named: "clipboard.json")
            try formattedContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return (fileURL.path, "Clipboard (JSON)".localized())
            
        case .code(let content, let language, let ext):
            let fileURL = try prepareTemporaryFile(named: "clipboard.\(ext)")
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return (fileURL.path, "Clipboard (\(language))")
            
        case .markdown(let content):
            let fileURL = try prepareTemporaryFile(named: "clipboard.md")
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return (fileURL.path, "Clipboard (Markdown)".localized())
            
        case .plainText(let content):
            let fileURL = try prepareTemporaryFile(named: "clipboard.txt")
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return (fileURL.path, "Clipboard Text".localized())
        }
    }
    
    // MARK: - 内部辅助方法
    
    private static func prepareTemporaryFile(named fileName: String) throws -> URL {
        let dir = cacheDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let target = dir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.removeItem(at: target)
        }
        return target
    }
    
    /// 语言嗅探特征
    private static func detectProgrammingLanguage(in text: String) -> (language: String, fileExtension: String)? {
        let lines = text.components(separatedBy: .newlines)
        
        // Swift 特征
        if text.contains("import SwiftUI") || text.contains("import Foundation") || text.contains("@State ") || text.contains("func ") && text.contains(" -> ") {
            return ("Swift", "swift")
        }
        
        // Python 特征
        if text.contains("def ") && text.contains(":") || text.contains("import ") && (text.contains("from ") || text.contains("sys") || text.contains("os")) || text.contains("print(") {
            return ("Python", "py")
        }
        
        // JavaScript / TypeScript 特征
        if text.contains("const ") || text.contains("let ") || text.contains("export ") || text.contains("console.log(") || text.contains("function ") || text.contains("interface ") {
            if text.contains("interface ") || text.contains(": string") || text.contains(": number") {
                return ("TypeScript", "ts")
            }
            return ("JavaScript", "js")
        }
        
        // Go 特征
        if text.contains("package main") || text.contains("func main()") || text.contains("import (") && text.contains("\"fmt\"") {
            return ("Go", "go")
        }
        
        // Rust 特征
        if text.contains("fn main()") || text.contains("let mut ") || text.contains("println!(") || text.contains("impl ") {
            return ("Rust", "rs")
        }
        
        // HTML 特征
        if (text.contains("<!DOCTYPE html") || text.contains("<html")) && text.contains("</html>") {
            return ("HTML", "html")
        }
        
        // SQL 特征
        let uppercased = text.uppercased()
        if (uppercased.contains("SELECT ") && uppercased.contains(" FROM ")) || uppercased.contains("INSERT INTO ") || uppercased.contains("CREATE TABLE ") {
            return ("SQL", "sql")
        }
        
        // Shell 特征
        if text.hasPrefix("#!/bin/bash") || text.hasPrefix("#!/bin/zsh") || text.hasPrefix("#!/bin/sh") {
            return ("Shell", "sh")
        }
        
        return nil
    }
    
    /// Markdown 格式特征判断
    private static func isMarkdownContent(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        var markdownScore = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                markdownScore += 2
            }
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") {
                markdownScore += 2
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("> ") {
                markdownScore += 1
            }
            if trimmed.contains("[") && trimmed.contains("](") && trimmed.contains(")") {
                markdownScore += 2
            }
            if trimmed.contains("```") {
                markdownScore += 2
            }
        }
        
        return markdownScore >= 3
    }
}
