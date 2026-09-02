import XCTest
@testable import QuickCookies

final class ArchiveTreeBuilderTests: XCTestCase {

    func testBuildTreeFromEmptyEntriesReturnsEmpty() {
        let tree = ArchiveTreeBuilder.buildTree(from: [])
        XCTAssertTrue(tree.isEmpty)
    }

    func testBuildTreeSingleRootFile() {
        let entries = [
            ArchiveEntry(path: "README.md", uncompressedSize: 100, compressedSize: 50, isDirectory: false, modificationDate: nil)
        ]
        let tree = ArchiveTreeBuilder.buildTree(from: entries)
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree[0].name, "README.md")
        XCTAssertEqual(tree[0].fullPath, "README.md")
        XCTAssertFalse(tree[0].isDirectory)
        XCTAssertEqual(tree[0].uncompressedSize, 100)
    }

    func testBuildTreeFoldersFirstAndAlphabeticalSorting() {
        let entries = [
            ArchiveEntry(path: "zebra.txt", uncompressedSize: 10, compressedSize: nil, isDirectory: false, modificationDate: nil),
            ArchiveEntry(path: "apple.txt", uncompressedSize: 20, compressedSize: nil, isDirectory: false, modificationDate: nil),
            ArchiveEntry(path: "docs/", uncompressedSize: 0, compressedSize: nil, isDirectory: true, modificationDate: nil),
            ArchiveEntry(path: "docs/guide.md", uncompressedSize: 50, compressedSize: nil, isDirectory: false, modificationDate: nil),
            ArchiveEntry(path: "assets/", uncompressedSize: 0, compressedSize: nil, isDirectory: true, modificationDate: nil),
            ArchiveEntry(path: "assets/logo.png", uncompressedSize: 200, compressedSize: nil, isDirectory: false, modificationDate: nil)
        ]

        let tree = ArchiveTreeBuilder.buildTree(from: entries)
        XCTAssertEqual(tree.count, 4) // assets, docs, apple.txt, zebra.txt

        // 文件夹在前
        XCTAssertTrue(tree[0].isDirectory)
        XCTAssertEqual(tree[0].name, "assets")
        XCTAssertEqual(tree[0].uncompressedSize, 200)

        XCTAssertTrue(tree[1].isDirectory)
        XCTAssertEqual(tree[1].name, "docs")
        XCTAssertEqual(tree[1].uncompressedSize, 50)

        // 文件在后
        XCTAssertFalse(tree[2].isDirectory)
        XCTAssertEqual(tree[2].name, "apple.txt")

        XCTAssertFalse(tree[3].isDirectory)
        XCTAssertEqual(tree[3].name, "zebra.txt")
    }

    func testBuildTreeImplicitDirectoriesCreatedAutomatically() {
        let entries = [
            ArchiveEntry(path: "src/components/button/Button.tsx", uncompressedSize: 300, compressedSize: nil, isDirectory: false, modificationDate: nil)
        ]

        let tree = ArchiveTreeBuilder.buildTree(from: entries)
        XCTAssertEqual(tree.count, 1)

        let src = tree[0]
        XCTAssertEqual(src.name, "src")
        XCTAssertTrue(src.isDirectory)
        XCTAssertEqual(src.uncompressedSize, 300)
        XCTAssertEqual(src.children.count, 1)

        let components = src.children[0]
        XCTAssertEqual(components.name, "components")
        XCTAssertTrue(components.isDirectory)
        XCTAssertEqual(components.children.count, 1)

        let buttonDir = components.children[0]
        XCTAssertEqual(buttonDir.name, "button")
        XCTAssertTrue(buttonDir.isDirectory)
        XCTAssertEqual(buttonDir.children.count, 1)

        let file = buttonDir.children[0]
        XCTAssertEqual(file.name, "Button.tsx")
        XCTAssertFalse(file.isDirectory)
        XCTAssertEqual(file.uncompressedSize, 300)
    }

    func testFlattenVisibleNodesFoldedAndExpanded() {
        let entries = [
            ArchiveEntry(path: "folder/sub/file.txt", uncompressedSize: 10, compressedSize: nil, isDirectory: false, modificationDate: nil),
            ArchiveEntry(path: "root.txt", uncompressedSize: 5, compressedSize: nil, isDirectory: false, modificationDate: nil)
        ]

        let tree = ArchiveTreeBuilder.buildTree(from: entries)
        XCTAssertEqual(tree.count, 2) // folder, root.txt

        // 默认折叠状态下，只展平顶层 2 个可见行
        let foldedRows = ArchiveTreeBuilder.flattenVisibleNodes(from: tree)
        XCTAssertEqual(foldedRows.count, 2)
        XCTAssertEqual(foldedRows[0].node.name, "folder")
        XCTAssertEqual(foldedRows[0].depth, 0)
        XCTAssertEqual(foldedRows[1].node.name, "root.txt")
        XCTAssertEqual(foldedRows[1].depth, 0)

        // 展开 folder
        tree[0].isExpanded = true
        let expandedFolderRows = ArchiveTreeBuilder.flattenVisibleNodes(from: tree)
        XCTAssertEqual(expandedFolderRows.count, 3) // folder (depth 0), sub (depth 1), root.txt (depth 0)
        XCTAssertEqual(expandedFolderRows[1].node.name, "sub")
        XCTAssertEqual(expandedFolderRows[1].depth, 1)

        // 展开 sub
        tree[0].children[0].isExpanded = true
        let fullyExpandedRows = ArchiveTreeBuilder.flattenVisibleNodes(from: tree)
        XCTAssertEqual(fullyExpandedRows.count, 4) // folder, sub, file.txt, root.txt
        XCTAssertEqual(fullyExpandedRows[2].node.name, "file.txt")
        XCTAssertEqual(fullyExpandedRows[2].depth, 2)
    }
}
