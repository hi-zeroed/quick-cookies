import Foundation

// macOS GB18030/GBK 编码常量（CoreFoundation 定义）
// CFStringEncodingGB_18030_2000 = 0x0631
private let CFStringEncodingGB_18030_2000: CFStringEncoding = 0x0631

enum EncodingDetector {
    /// 尝试检测文件编码，优先 UTF-8
    static func detect(data: Data) -> String.Encoding {
        // 尝试 UTF-8
        if isValidUTF8(data) {
            return .utf8
        }

        // 尝试 UTF-16
        if data.count >= 2 {
            let bom = data.prefix(2)
            if bom == Data([0xFE, 0xFF]) || bom == Data([0xFF, 0xFE]) {
                return .utf16
            }
        }

        // 尝试 GB18030（中文环境，包含 GBK）
        // macOS 使用 CFStringEncodingGB_18030_2000 (0x0631) 作为 GB18030/GBK 编码常量
        let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncodingGB_18030_2000)
        if let _ = String(data: data, encoding: String.Encoding(rawValue: gbkEncoding)) {
            return String.Encoding(rawValue: gbkEncoding)
        }

        // 默认返回 UTF-8（可能显示乱码）
        return .utf8
    }

    private static func isValidUTF8(_ data: Data) -> Bool {
        var index = 0
        while index < data.count {
            let byte = data[index]

            // 单字节字符 (0x00-0x7F)
            if byte < 0x80 {
                index += 1
                continue
            }

            // 多字节字符
            let length: Int
            if byte < 0xC0 { return false }      // 无效起始字节
            else if byte < 0xE0 { length = 2 }   // 2字节
            else if byte < 0xF0 { length = 3 }   // 3字节
            else if byte < 0xF8 { length = 4 }   // 4字节
            else { return false }                // 无效

            if index + length > data.count { return false }

            // 检查后续字节
            for i in 1..<length {
                let nextByte = data[index + i]
                if nextByte < 0x80 || nextByte >= 0xC0 { return false }
            }

            index += length
        }
        return true
    }
}