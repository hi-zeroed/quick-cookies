import XCTest
@testable import QuickCookies

final class StructuredDataParserTests: XCTestCase {

    func testParseStandardJSON() {
        let jsonStr = """
        {
            "name": "QuickCookies",
            "version": 1.5,
            "isNative": true,
            "dependencies": ["SwiftUI", "AppKit"],
            "meta": {
                "author": "Antigravity",
                "count": 42
            }
        }
        """

        let result = StructuredDataParser.parse(content: jsonStr, fileExtension: "json")
        XCTAssertNotNil(result)

        guard let (root, pretty) = result else { return }
        XCTAssertFalse(pretty.isEmpty)
        XCTAssertEqual(root.valueType, .object(5))
        XCTAssertEqual(root.children.count, 5)

        // 验证按 key 字母升序排序
        let names = root.children.compactMap { $0.key }
        XCTAssertEqual(names, ["dependencies", "isNative", "meta", "name", "version"])

        // 验证数组节点
        let depsNode = root.children.first(where: { $0.key == "dependencies" })
        XCTAssertNotNil(depsNode)
        XCTAssertEqual(depsNode?.valueType, .array(2))
        XCTAssertEqual(depsNode?.children.count, 2)
        XCTAssertEqual(depsNode?.children[0].displayValue, "\"SwiftUI\"")

        // 验证布尔节点
        let boolNode = root.children.first(where: { $0.key == "isNative" })
        XCTAssertEqual(boolNode?.valueType, .boolean)
        XCTAssertEqual(boolNode?.displayValue, "true")

        // 验证数字节点
        let verNode = root.children.first(where: { $0.key == "version" })
        XCTAssertEqual(verNode?.valueType, .number)
    }

    func testParseMinifiedJSONGeneratesPrettyFormattedString() {
        let minified = "{\"a\":1,\"b\":[true,false],\"c\":{\"d\":\"val\"}}"
        let result = StructuredDataParser.parse(content: minified, fileExtension: "json")
        XCTAssertNotNil(result)

        guard let (_, pretty) = result else { return }
        // 美化后应该包含换行与缩进
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.contains("  "))
    }

    func testParseInvalidJSONReturnsNilForSafeFallback() {
        let invalid = "{ key: broken_json_without_quotes "
        let result = StructuredDataParser.parse(content: invalid, fileExtension: "json")
        XCTAssertNil(result)
    }

    func testParseYAMLHierarchy() {
        let yaml = """
        name: QuickCookies
        version: 2.0
        server:
          host: 127.0.0.1
          port: 8080
        plugins:
          - FinderSync
          - QuickLook
        """

        let result = StructuredDataParser.parse(content: yaml, fileExtension: "yaml")
        XCTAssertNotNil(result)

        guard let (root, _) = result else { return }
        XCTAssertEqual(root.children.count, 4)

        let serverNode = root.children.first(where: { $0.key == "server" })
        XCTAssertNotNil(serverNode)
        XCTAssertEqual(serverNode?.children.count, 2)

        let pluginsNode = root.children.first(where: { $0.key == "plugins" })
        XCTAssertNotNil(pluginsNode)
        XCTAssertEqual(pluginsNode?.children.count, 2)
    }

    func testParseTOMLConfiguration() {
        let toml = """
        [package]
        name = "quick-cookies"
        version = "1.0.0"

        [dependencies]
        swift = true
        """

        let result = StructuredDataParser.parse(content: toml, fileExtension: "toml")
        XCTAssertNotNil(result)

        guard let (root, _) = result else { return }
        XCTAssertEqual(root.children.count, 2)
    }

    func testParseINIConfiguration() {
        let ini = """
        [database]
        host = localhost
        port = 3306

        [redis]
        port = 6379
        """

        let result = StructuredDataParser.parse(content: ini, fileExtension: "ini")
        XCTAssertNotNil(result)

        guard let (root, _) = result else { return }
        XCTAssertEqual(root.children.count, 2)
    }

    func testStructuredDataCategoryRegistry() {
        XCTAssertTrue(StructuredDataCategoryRegistry.isStructuredData(path: "config.yaml"))
        XCTAssertTrue(StructuredDataCategoryRegistry.isStructuredData(path: "app.yml"))
        XCTAssertTrue(StructuredDataCategoryRegistry.isStructuredData(path: "Info.plist"))
        XCTAssertTrue(StructuredDataCategoryRegistry.isStructuredData(path: "Cargo.toml"))
        XCTAssertTrue(StructuredDataCategoryRegistry.isStructuredData(path: ".env"))
        XCTAssertTrue(StructuredDataCategoryRegistry.isStructuredData(path: "pom.xml"))

        XCTAssertFalse(StructuredDataCategoryRegistry.isStructuredData(path: "main.swift"))
        XCTAssertFalse(StructuredDataCategoryRegistry.isStructuredData(path: "index.html"))
    }

    func testParseJSONWithComments() {
        let jsonc = """
        {
            // 单行注释
            "theme": "dark",
            /* 多行
               块级注释 */
            "fontSize": 14
        }
        """
        let result = StructuredDataParser.parse(content: jsonc, fileExtension: "jsonc")
        XCTAssertNotNil(result)
        guard let (root, _) = result else { return }
        XCTAssertEqual(root.children.count, 2)
        XCTAssertEqual(root.children.first(where: { $0.key == "theme" })?.displayValue, "\"dark\"")
        XCTAssertEqual(root.children.first(where: { $0.key == "fontSize" })?.displayValue, "14")
    }

    func testParsePlistAndXML() {
        let plistXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleName</key>
            <string>QuickCookies</string>
            <key>CFBundleVersion</key>
            <string>1.0</string>
        </dict>
        </plist>
        """

        let result = StructuredDataParser.parse(content: plistXML, fileExtension: "plist")
        XCTAssertNotNil(result)
        guard let (root, _) = result else { return }
        XCTAssertEqual(root.children.count, 2)
    }
}
