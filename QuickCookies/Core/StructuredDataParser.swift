import Foundation

/// 结构化数据的值类型
enum StructuredDataValueType: Equatable {
    case object(Int) // 键值对数量
    case array(Int)  // 元素数量
    case string
    case number
    case boolean
    case null

    var badgeText: String {
        switch self {
        case .object(let count): return "{\(count)}"
        case .array(let count): return "[\(count)]"
        case .string: return "string"
        case .number: return "number"
        case .boolean: return "bool"
        case .null: return "null"
        }
    }
}

/// 结构化数据注册中心（集中维护所有支持的结构化配置格式）
struct StructuredDataCategoryRegistry {
    /// 所有支持结构化树状透视与格式化的扩展名
    static let supportedExtensions: Set<String> = [
        // JSON 家族
        "json", "jsonc", "json5", "geojson", "schema", "bowerrc",
        // YAML 家族
        "yaml", "yml", "eyaml",
        // Property List 与 XML 家族
        "plist", "xml", "rss", "atom",
        // TOML 配置文件
        "toml",
        // 键值对与系统配置
        "ini", "env", "properties", "conf"
    ]

    static let supportedFilenames: Set<String> = [
        ".env", ".bowerrc", ".prettierrc", ".eslintrc", ".stylelintrc", "cargo.lock"
    ]

    /// 判断文件是否为结构化数据配置
    static func isStructuredData(path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        let filename = (path as NSString).lastPathComponent.lowercased()

        if supportedExtensions.contains(ext) {
            return true
        }
        if supportedFilenames.contains(filename) || filename.hasPrefix(".env.") {
            return true
        }
        return false
    }
}

/// 结构化数据树节点
final class StructuredDataNode: Identifiable, ObservableObject, Equatable {
    let id: String
    let key: String?
    let valueType: StructuredDataValueType
    let displayValue: String
    let rawValue: String
    var children: [StructuredDataNode]
    @Published var isExpanded: Bool

    init(
        id: String,
        key: String?,
        valueType: StructuredDataValueType,
        displayValue: String,
        rawValue: String,
        children: [StructuredDataNode] = [],
        isExpanded: Bool = true
    ) {
        self.id = id
        self.key = key
        self.valueType = valueType
        self.displayValue = displayValue
        self.rawValue = rawValue
        self.children = children
        self.isExpanded = isExpanded
    }

    static func == (lhs: StructuredDataNode, rhs: StructuredDataNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.key == rhs.key &&
        lhs.valueType == rhs.valueType &&
        lhs.displayValue == rhs.displayValue &&
        lhs.rawValue == rhs.rawValue &&
        lhs.children == rhs.children &&
        lhs.isExpanded == rhs.isExpanded
    }
}

struct StructuredDataParser {
    /// 尝试将文本解析为结构化数据树及格式化（美化）文本
    static func parse(content: String, fileExtension: String) -> (root: StructuredDataNode, formattedText: String)? {
        var ext = fileExtension.lowercased()
        if ext.hasPrefix(".") {
            ext = String(ext.dropFirst())
        }
        guard let data = content.data(using: .utf8) else { return nil }

        // 1. JSON 家族
        if ["json", "jsonc", "json5", "geojson", "schema", "bowerrc", "prettierrc", "eslintrc", "stylelintrc"].contains(ext) {
            return parseJSON(content: content)
        }

        // 2. YAML 家族
        if ["yaml", "yml", "eyaml"].contains(ext) {
            return parseYAML(content: content)
        }

        // 3. Plist 与 XML 家族
        if ["plist", "xml", "rss", "atom"].contains(ext) {
            return parsePlistOrXML(data: data, originalString: content)
        }

        // 4. TOML 配置文件
        if ext == "toml" || ext == "lock" {
            return parseTOML(content: content)
        }

        // 5. INI / ENV / Properties 配置文件
        if ["ini", "env", "properties", "conf"].contains(ext) {
            return parseINI(content: content)
        }

        return nil
    }

    // MARK: - 1. JSON 家族解析器

    static func parseJSON(content: String) -> (root: StructuredDataNode, formattedText: String)? {
        // 剥离注释（支持 // 和 /* ... */）
        let sanitized = sanitizeJSONComments(content)
        guard let data = sanitized.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }

        let prettyString: String
        if let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
           let str = String(data: prettyData, encoding: .utf8) {
            prettyString = str
        } else {
            prettyString = content
        }

        let rootNode = buildNode(from: jsonObject, key: nil, path: "root")
        return (rootNode, prettyString)
    }

    private static func sanitizeJSONComments(_ str: String) -> String {
        var result = ""
        let lines = str.components(separatedBy: .newlines)
        var insideBlockComment = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if insideBlockComment {
                if let endRange = line.range(of: "*/") {
                    insideBlockComment = false
                    let remainder = String(line[endRange.upperBound...])
                    result += remainder + "\n"
                }
                continue
            }

            if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                continue
            }

            if let startRange = line.range(of: "/*") {
                if let endRange = line.range(of: "*/") {
                    let before = String(line[..<startRange.lowerBound])
                    let after = String(line[endRange.upperBound...])
                    result += before + after + "\n"
                } else {
                    let before = String(line[..<startRange.lowerBound])
                    result += before + "\n"
                    insideBlockComment = true
                }
                continue
            }

            result += line + "\n"
        }
        return result
    }

    // MARK: - 2. YAML 家族解析器

    static func parseYAML(content: String) -> (root: StructuredDataNode, formattedText: String)? {
        let lines = content.components(separatedBy: .newlines)
        var rootDict: [String: Any] = [:]
        var keyStack: [(indent: Int, key: String)] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count

            // 弹出比当前缩进深的父级
            while let last = keyStack.last, last.indent >= indent {
                keyStack.removeLast()
            }

            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valStr = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                if valStr.isEmpty {
                    // 父级字典节点
                    keyStack.append((indent: indent, key: key))
                    setNestedValue(in: &rootDict, stack: keyStack, value: [String: Any]())
                } else {
                    let parsedVal = parsePrimitiveValue(valStr)
                    var currentStack = keyStack
                    currentStack.append((indent: indent, key: key))
                    setNestedValue(in: &rootDict, stack: currentStack, value: parsedVal)
                }
            } else if trimmed.hasPrefix("- ") {
                let itemStr = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let parsedVal = parsePrimitiveValue(itemStr)
                appendNestedArrayItem(in: &rootDict, stack: keyStack, value: parsedVal)
            }
        }

        guard !rootDict.isEmpty else { return nil }
        let rootNode = buildNode(from: rootDict, key: nil, path: "root")
        return (rootNode, content)
    }

    private static func setNestedValue(in dict: inout [String: Any], stack: [(indent: Int, key: String)], value: Any) {
        guard !stack.isEmpty else { return }
        if stack.count == 1 {
            dict[stack[0].key] = value
            return
        }

        // 简化的嵌套写入
        let topKey = stack[0].key
        if dict[topKey] == nil || !(dict[topKey] is [String: Any]) {
            dict[topKey] = [String: Any]()
        }
        if var sub = dict[topKey] as? [String: Any] {
            let nextStack = Array(stack.dropFirst())
            setNestedValue(in: &sub, stack: nextStack, value: value)
            dict[topKey] = sub
        }
    }

    private static func appendNestedArrayItem(in dict: inout [String: Any], stack: [(indent: Int, key: String)], value: Any) {
        guard let last = stack.last else { return }
        if var arr = dict[last.key] as? [Any] {
            arr.append(value)
            dict[last.key] = arr
        } else {
            dict[last.key] = [value]
        }
    }

    // MARK: - 3. Plist 与 XML 解析器

    static func parsePlistOrXML(data: Data, originalString: String) -> (root: StructuredDataNode, formattedText: String)? {
        if let plistObject = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            let prettyString: String
            if let xmlData = try? PropertyListSerialization.data(fromPropertyList: plistObject, format: .xml, options: 0),
               let str = String(data: xmlData, encoding: .utf8) {
                prettyString = str
            } else {
                prettyString = originalString
            }
            let rootNode = buildNode(from: plistObject, key: nil, path: "root")
            return (rootNode, prettyString)
        }

        // 通用 XML 树解析
        guard let xmlDoc = try? XMLDocument(data: data, options: [.nodePreserveWhitespace]) else {
            return nil
        }

        if let rootElement = xmlDoc.rootElement() {
            let node = buildXMLNode(element: rootElement, path: rootElement.name ?? "root")
            return (node, originalString)
        }

        return nil
    }

    private static func buildXMLNode(element: XMLElement, path: String) -> StructuredDataNode {
        let name = element.name ?? "item"
        let children = (element.children ?? []).compactMap { $0 as? XMLElement }

        if children.isEmpty {
            let val = element.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return StructuredDataNode(
                id: path,
                key: name,
                valueType: .string,
                displayValue: val,
                rawValue: val,
                children: [],
                isExpanded: false
            )
        } else {
            let childNodes = children.enumerated().map { idx, el in
                buildXMLNode(element: el, path: "\(path).\(el.name ?? "node")_\(idx)")
            }
            return StructuredDataNode(
                id: path,
                key: name,
                valueType: .object(childNodes.count),
                displayValue: "Element (\(childNodes.count) children)",
                rawValue: "<xml>",
                children: childNodes,
                isExpanded: true
            )
        }
    }

    // MARK: - 4. TOML 解析器

    static func parseTOML(content: String) -> (root: StructuredDataNode, formattedText: String)? {
        let lines = content.components(separatedBy: .newlines)
        var rootDict: [String: Any] = [:]
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                if rootDict[currentSection] == nil {
                    rootDict[currentSection] = [String: Any]()
                }
            } else if let eqIdx = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<eqIdx]).trimmingCharacters(in: .whitespaces)
                let valStr = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
                let parsedVal = parsePrimitiveValue(valStr)

                if currentSection.isEmpty {
                    rootDict[key] = parsedVal
                } else {
                    var sec = rootDict[currentSection] as? [String: Any] ?? [String: Any]()
                    sec[key] = parsedVal
                    rootDict[currentSection] = sec
                }
            }
        }

        guard !rootDict.isEmpty else { return nil }
        let rootNode = buildNode(from: rootDict, key: nil, path: "root")
        return (rootNode, content)
    }

    // MARK: - 5. INI / ENV / Properties 解析器

    static func parseINI(content: String) -> (root: StructuredDataNode, formattedText: String)? {
        let lines = content.components(separatedBy: .newlines)
        var rootDict: [String: Any] = [:]
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";") else { continue }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                if rootDict[currentSection] == nil {
                    rootDict[currentSection] = [String: Any]()
                }
            } else if let eqIdx = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<eqIdx]).trimmingCharacters(in: .whitespaces)
                let valStr = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
                let parsedVal = parsePrimitiveValue(valStr)

                if currentSection.isEmpty {
                    rootDict[key] = parsedVal
                } else {
                    var sec = rootDict[currentSection] as? [String: Any] ?? [String: Any]()
                    sec[key] = parsedVal
                    rootDict[currentSection] = sec
                }
            }
        }

        guard !rootDict.isEmpty else { return nil }
        let rootNode = buildNode(from: rootDict, key: nil, path: "root")
        return (rootNode, content)
    }

    // MARK: - 辅助解析

    private static func parsePrimitiveValue(_ str: String) -> Any {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        if trimmed.lowercased() == "true" { return true }
        if trimmed.lowercased() == "false" { return false }
        if trimmed.lowercased() == "null" || trimmed.lowercased() == "none" || trimmed.lowercased() == "nil" { return NSNull() }
        if let intVal = Int(trimmed) { return intVal }
        if let doubleVal = Double(trimmed) { return doubleVal }
        return trimmed
    }

    // MARK: - 递归树构建

    private static func buildNode(from value: Any, key: String?, path: String) -> StructuredDataNode {
        if let dict = value as? [String: Any] {
            let sortedKeys = dict.keys.sorted()
            let children = sortedKeys.map { k in
                buildNode(from: dict[k]!, key: k, path: "\(path).\(k)")
            }
            return StructuredDataNode(
                id: path,
                key: key,
                valueType: .object(dict.count),
                displayValue: "{\(dict.count)}",
                rawValue: "{}",
                children: children,
                isExpanded: true
            )
        } else if let array = value as? [Any] {
            let children = array.enumerated().map { idx, item in
                buildNode(from: item, key: "[\(idx)]", path: "\(path)[\(idx)]")
            }
            return StructuredDataNode(
                id: path,
                key: key,
                valueType: .array(array.count),
                displayValue: "[\(array.count)]",
                rawValue: "[]",
                children: children,
                isExpanded: true
            )
        } else if let str = value as? String {
            return StructuredDataNode(
                id: path,
                key: key,
                valueType: .string,
                displayValue: "\"\(str)\"",
                rawValue: str,
                children: [],
                isExpanded: false
            )
        } else if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                let boolVal = num.boolValue
                return StructuredDataNode(
                    id: path,
                    key: key,
                    valueType: .boolean,
                    displayValue: boolVal ? "true" : "false",
                    rawValue: boolVal ? "true" : "false",
                    children: [],
                    isExpanded: false
                )
            } else {
                return StructuredDataNode(
                    id: path,
                    key: key,
                    valueType: .number,
                    displayValue: "\(num)",
                    rawValue: "\(num)",
                    children: [],
                    isExpanded: false
                )
            }
        } else if value is NSNull {
            return StructuredDataNode(
                id: path,
                key: key,
                valueType: .null,
                displayValue: "null",
                rawValue: "null",
                children: [],
                isExpanded: false
            )
        } else {
            let str = String(describing: value)
            return StructuredDataNode(
                id: path,
                key: key,
                valueType: .string,
                displayValue: str,
                rawValue: str,
                children: [],
                isExpanded: false
            )
        }
    }
}
