//
//  CSVParserTests.swift
//  QuickCookiesTests
//
//  Created by Antigravity on 2026-09-17.
//

import XCTest
@testable import QuickCookies

final class CSVParserTests: XCTestCase {

    func testBasicCsvParsing() {
        let csv = "Name,Age,City\nAlice,30,New York\nBob,25,San Francisco"
        let dataSet = CSVParser.parse(text: csv)

        XCTAssertEqual(dataSet.headers, ["Name", "Age", "City"])
        XCTAssertEqual(dataSet.rows.count, 2)
        XCTAssertEqual(dataSet.totalRows, 2)
        XCTAssertEqual(dataSet.totalColumns, 3)
        XCTAssertEqual(dataSet.delimiter, ",")
        XCTAssertFalse(dataSet.isTruncated)
        XCTAssertEqual(dataSet.rows[0], ["Alice", "30", "New York"])
        XCTAssertEqual(dataSet.rows[1], ["Bob", "25", "San Francisco"])
    }

    func testTsvParsingAndDelimiterSniffing() {
        let tsv = "ID\tProduct\tPrice\n101\tLaptop\t1200\n102\tMouse\t25"
        let dataSet = CSVParser.parse(text: tsv)

        XCTAssertEqual(dataSet.delimiter, "\t")
        XCTAssertEqual(dataSet.headers, ["ID", "Product", "Price"])
        XCTAssertEqual(dataSet.rows.count, 2)
        XCTAssertEqual(dataSet.rows[0], ["101", "Laptop", "1200"])
    }

    func testQuotedFieldWithCommaAndEscapedQuotes() {
        let csv = "ID,Description,Notes\n1,\"Item with, comma\",\"Item with \"\"escaped\"\" quotes\""
        let dataSet = CSVParser.parse(text: csv)

        XCTAssertEqual(dataSet.headers, ["ID", "Description", "Notes"])
        XCTAssertEqual(dataSet.rows.count, 1)
        XCTAssertEqual(dataSet.rows[0][0], "1")
        XCTAssertEqual(dataSet.rows[0][1], "Item with, comma")
        XCTAssertEqual(dataSet.rows[0][2], "Item with \"escaped\" quotes")
    }

    func testQuotedFieldWithNewlines() {
        let csv = "Header1,Header2\n\"Line 1\nLine 2\",Value2\nValue3,Value4"
        let dataSet = CSVParser.parse(text: csv)

        XCTAssertEqual(dataSet.headers, ["Header1", "Header2"])
        XCTAssertEqual(dataSet.rows.count, 2)
        XCTAssertEqual(dataSet.rows[0][0], "Line 1\nLine 2")
        XCTAssertEqual(dataSet.rows[0][1], "Value2")
        XCTAssertEqual(dataSet.rows[1][0], "Value3")
    }

    func testUnevenColumnsAutoPadded() {
        let csv = "ColA,ColB,ColC\nVal1\nVal2,Val3,Val4,Val5"
        let dataSet = CSVParser.parse(text: csv)

        // 数据行最多 4 列，表头应自动补齐第 4 列标尺
        XCTAssertEqual(dataSet.totalColumns, 4)
        XCTAssertEqual(dataSet.headers.count, 4)
        XCTAssertEqual(dataSet.headers[3], "D")
        XCTAssertEqual(dataSet.rows[0], ["Val1", "", "", ""])
        XCTAssertEqual(dataSet.rows[1], ["Val2", "Val3", "Val4", "Val5"])
    }

    func testSortingNumericAndNaturalText() {
        let rows = [
            ["Item 10", "45.5"],
            ["Item 2", "120.0"],
            ["Item 1", "5.0"]
        ]

        // 按数值列 (index 1) 升序排序
        let numSortedAsc = CSVParser.sort(rows: rows, by: 1, direction: .ascending)
        XCTAssertEqual(numSortedAsc.map { $0[1] }, ["5.0", "45.5", "120.0"])

        // 按数值列 (index 1) 降序排序
        let numSortedDesc = CSVParser.sort(rows: rows, by: 1, direction: .descending)
        XCTAssertEqual(numSortedDesc.map { $0[1] }, ["120.0", "45.5", "5.0"])

        // 按自然字母列 (index 0) 升序排序 (Item 1 < Item 2 < Item 10)
        let textSortedAsc = CSVParser.sort(rows: rows, by: 0, direction: .ascending)
        XCTAssertEqual(textSortedAsc.map { $0[0] }, ["Item 1", "Item 2", "Item 10"])
    }

    func testSortStateToggle() {
        var state = CSVSortState()
        XCTAssertNil(state.columnIndex)

        state.toggle(for: 1)
        XCTAssertEqual(state.columnIndex, 1)
        XCTAssertEqual(state.direction, .ascending)

        state.toggle(for: 1)
        XCTAssertEqual(state.columnIndex, 1)
        XCTAssertEqual(state.direction, .descending)

        state.toggle(for: 1)
        XCTAssertNil(state.columnIndex)

        state.toggle(for: 2)
        XCTAssertEqual(state.columnIndex, 2)
        XCTAssertEqual(state.direction, .ascending)
    }

    func testMaxRowsTruncation() {
        var lines: [String] = ["H1,H2"]
        for i in 1...20 {
            lines.append("val\(i),val\(i)")
        }
        let csv = lines.joined(separator: "\n")

        let dataSet = CSVParser.parse(text: csv, maxRows: 5)
        XCTAssertTrue(dataSet.isTruncated)
        XCTAssertEqual(dataSet.rows.count, 5)
    }

    func testColumnLetter() {
        XCTAssertEqual(CSVParser.columnLetter(for: 0), "A")
        XCTAssertEqual(CSVParser.columnLetter(for: 25), "Z")
        XCTAssertEqual(CSVParser.columnLetter(for: 26), "AA")
        XCTAssertEqual(CSVParser.columnLetter(for: 27), "AB")
    }

    func testEmptyTextReturnsEmptyDataSet() {
        let emptySet = CSVParser.parse(text: "")
        XCTAssertEqual(emptySet, .empty)
    }
}
