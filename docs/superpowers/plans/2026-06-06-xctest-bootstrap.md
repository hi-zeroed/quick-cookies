# QuickCookies XCTest Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 QuickCookies 建立第一阶段可稳定运行的 XCTest 基础设施，并落地 `EncodingDetector`、`FileTypeClassifier`、`FileChunkReader`、`FileUtils` 的首批单元测试。

**Architecture:** 方案分为两部分。第一部分是工程接入，包括新增 `QuickCookiesTests` target、将测试 bundle 关联到 `QuickCookies` scheme，并确保命令行 `xcodebuild test` 可运行。第二部分是围绕当前已具备较强可测试性的纯逻辑和文件处理模块，采用临时文件与显式断言的方式逐步补齐测试，避免在第一阶段引入 Finder、Hotkey、WebKit、登录项等高耦合系统依赖。

**Tech Stack:** Xcode project (`project.pbxproj`), XCTest, Swift 5, macOS unit test bundle, `xcodebuild`

---

## File Structure

### Existing files to modify

- Modify: `QuickCookies.xcodeproj/project.pbxproj`
- Modify: `QuickCookies.xcodeproj/xcshareddata/xcschemes/QuickCookies.xcscheme`

### New files to create

- Create: `QuickCookiesTests/EncodingDetectorTests.swift`
- Create: `QuickCookiesTests/FileTypeClassifierTests.swift`
- Create: `QuickCookiesTests/FileChunkReaderTests.swift`
- Create: `QuickCookiesTests/FileUtilsTests.swift`

### Optional helper files

- Optional Create: `QuickCookiesTests/TestSupport/TemporaryDirectory.swift`

### Validation commands

- `xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' build-for-testing`
- `xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -only-testing:QuickCookiesTests/EncodingDetectorTests`
- `xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS'`

---

### Task 1: Add `QuickCookiesTests` Target To The Xcode Project

**Files:**
- Modify: `QuickCookies.xcodeproj/project.pbxproj`
- Modify: `QuickCookies.xcodeproj/xcshareddata/xcschemes/QuickCookies.xcscheme`

- [ ] **Step 1: Inspect the current project graph before editing**

Run:

```bash
rg -n "PBXNativeTarget|PBXBuildFile|PBXFileReference|PBXSourcesBuildPhase|XCBuildConfiguration|QuickCookiesTests" QuickCookies.xcodeproj/project.pbxproj
```

Expected:

```text
Shows existing QuickCookies / QuickCookiesFinderSync target definitions and confirms QuickCookiesTests does not yet exist.
```

- [ ] **Step 2: Add a new macOS unit test bundle target to `project.pbxproj`**

Add a `QuickCookiesTests` target with:

```text
productType = "com.apple.product-type.bundle.unit-test"
PRODUCT_BUNDLE_IDENTIFIER = com.quickcookies.app.tests
PRODUCT_NAME = "$(TARGET_NAME)"
TEST_HOST = ""
BUNDLE_LOADER = ""
SWIFT_VERSION = 5.0
MACOSX_DEPLOYMENT_TARGET = 13.0
GENERATE_INFOPLIST_FILE = YES
CODE_SIGN_STYLE = Automatic
```

Also add:

```text
QuickCookiesTests group / file references
PBXSourcesBuildPhase for test sources
PBXFrameworksBuildPhase with XCTest.framework
PBXTargetDependency or target linkage required for `@testable import QuickCookies`
Debug / Release build configurations for QuickCookiesTests
```

Expected result:

```text
The Xcode project opens with a visible QuickCookiesTests target and no broken references.
```

- [ ] **Step 3: Attach the test target to the shared scheme**

Update `QuickCookies.xcodeproj/xcshareddata/xcschemes/QuickCookies.xcscheme` so `TestAction` contains a `TestableReference` for `QuickCookiesTests.xctest`.

The resulting structure should look conceptually like:

```xml
<TestAction
   buildConfiguration = "Debug"
   selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
   selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
   shouldUseLaunchSchemeArgsEnv = "YES"
   shouldAutocreateTestPlan = "YES">
   <Testables>
      <TestableReference
         skipped = "NO">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "QUICKCOOKIES_TESTS_TARGET_ID"
            BuildableName = "QuickCookiesTests.xctest"
            BlueprintName = "QuickCookiesTests"
            ReferencedContainer = "container:QuickCookies.xcodeproj">
         </BuildableReference>
      </TestableReference>
   </Testables>
</TestAction>
```

- [ ] **Step 4: Add placeholder test source files to the target**

Create these files with a minimal smoke test so the target can compile immediately:

```swift
import XCTest
@testable import QuickCookies

final class EncodingDetectorTests: XCTestCase {
    func testSmoke() {
        XCTAssertTrue(true)
    }
}
```

Repeat with one smoke test class per planned file:

```text
QuickCookiesTests/EncodingDetectorTests.swift
QuickCookiesTests/FileTypeClassifierTests.swift
QuickCookiesTests/FileChunkReaderTests.swift
QuickCookiesTests/FileUtilsTests.swift
```

- [ ] **Step 5: Run build-for-testing to validate project wiring**

Run:

```bash
xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' build-for-testing
```

Expected:

```text
BUILD SUCCEEDED
```

- [ ] **Step 6: Commit the project bootstrap**

Run:

```bash
git add QuickCookies.xcodeproj/project.pbxproj QuickCookies.xcodeproj/xcshareddata/xcschemes/QuickCookies.xcscheme QuickCookiesTests
git commit -m "test: bootstrap xctest target"
```

---

### Task 2: Implement `EncodingDetector` Tests

**Files:**
- Modify: `QuickCookiesTests/EncodingDetectorTests.swift`
- Test: `QuickCookiesTests/EncodingDetectorTests.swift`

- [ ] **Step 1: Replace the smoke test with real failing tests**

Use this test file body:

```swift
import XCTest
@testable import QuickCookies

final class EncodingDetectorTests: XCTestCase {
    func testDetectUTF8Text() {
        let text = "Hello, 世界"
        let data = text.data(using: .utf8)!

        XCTAssertEqual(EncodingDetector.detect(data: data), .utf8)
    }

    func testDetectUTF16TextWithBOM() {
        let text = "Hello, UTF16"
        let data = text.data(using: .utf16)!

        XCTAssertEqual(EncodingDetector.detect(data: data), .utf16)
    }

    func testDetectGB18030Text() {
        let raw = CFStringConvertEncodingToNSStringEncoding(0x0631)
        let encoding = String.Encoding(rawValue: raw)
        let text = "测试中文"

        guard let data = text.data(using: encoding) else {
            return XCTFail("Unable to build GB18030 sample data")
        }

        XCTAssertEqual(EncodingDetector.detect(data: data), encoding)
    }

    func testInvalidBinaryLikeDataFallsBackToUTF8() {
        let data = Data([0xFF, 0xFF, 0x00, 0x12, 0x85])

        XCTAssertEqual(EncodingDetector.detect(data: data), .utf8)
    }
}
```

- [ ] **Step 2: Run only the encoding tests and verify current behavior**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -only-testing:QuickCookiesTests/EncodingDetectorTests
```

Expected:

```text
Either PASS directly, or fail only on assertion mismatches that reflect current implementation behavior.
```

- [ ] **Step 3: If any assertion fails, adjust the test to match intended documented behavior rather than overfitting internals**

Allowed adjustments:

```text
- Keep UTF-8 and UTF-16 assertions exact.
- Keep GB18030 assertion exact because implementation explicitly checks it.
- Keep fallback expectation exact at `.utf8`.
```

Not allowed:

```text
Weakening the tests into "XCTAssertNotNil" or removing explicit encoding checks.
```

- [ ] **Step 4: Re-run the focused encoding suite**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -only-testing:QuickCookiesTests/EncodingDetectorTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 5: Commit the encoding tests**

Run:

```bash
git add QuickCookiesTests/EncodingDetectorTests.swift
git commit -m "test: cover encoding detector"
```

---

### Task 3: Implement `FileTypeClassifier` Tests

**Files:**
- Modify: `QuickCookiesTests/FileTypeClassifierTests.swift`
- Optional Create: `QuickCookiesTests/TestSupport/TemporaryDirectory.swift`
- Test: `QuickCookiesTests/FileTypeClassifierTests.swift`

- [ ] **Step 1: Add a tiny temporary-directory helper if repeated setup becomes noisy**

If needed, create:

```swift
import Foundation

struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
```

If the test file remains readable without this helper, skip the helper and keep setup inline.

- [ ] **Step 2: Replace the smoke test with explicit file classification coverage**

Use this body in `QuickCookiesTests/FileTypeClassifierTests.swift`:

```swift
import XCTest
@testable import QuickCookies

final class FileTypeClassifierTests: XCTestCase {
    private var tempDirURL: URL!

    override func setUpWithError() throws {
        tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirURL)
    }

    func testMarkdownFileClassifiesAsMarkdown() throws {
        let fileURL = tempDirURL.appendingPathComponent("note.md")
        try "# Title".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .markdown)
    }

    func testSwiftFileClassifiesAsCode() throws {
        let fileURL = tempDirURL.appendingPathComponent("App.swift")
        try "import SwiftUI".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .code)
    }

    func testPdfClassifiesAsPdf() throws {
        let fileURL = tempDirURL.appendingPathComponent("doc.pdf")
        try Data([0x25, 0x50, 0x44, 0x46]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .pdf)
    }

    func testPngClassifiesAsImage() throws {
        let fileURL = tempDirURL.appendingPathComponent("image.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .image)
    }

    func testOfficeDocumentClassifiesAsOffice() throws {
        let fileURL = tempDirURL.appendingPathComponent("sheet.xlsx")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .office)
    }

    func testBinaryFileClassifiesAsUnsupported() throws {
        let fileURL = tempDirURL.appendingPathComponent("exec.bin")
        try Data([0x41, 0x42, 0x00, 0x43]).write(to: fileURL)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .unsupported)
    }

    func testMakefileClassifiesAsCode() throws {
        let fileURL = tempDirURL.appendingPathComponent("Makefile")
        try "all:\n\t@echo ok".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .code)
    }

    func testUnknownTextExtensionDefaultsToPlainText() throws {
        let fileURL = tempDirURL.appendingPathComponent("notes.custom")
        try "plain text".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(FileTypeClassifier.classify(path: fileURL.path), .plainText)
    }

    func testMissingPathIsUnsupported() {
        let path = tempDirURL.appendingPathComponent("missing.md").path

        XCTAssertEqual(FileTypeClassifier.classify(path: path), .unsupported)
    }

    func testDirectoryPathIsUnsupported() {
        XCTAssertEqual(FileTypeClassifier.classify(path: tempDirURL.path), .unsupported)
    }
}
```

- [ ] **Step 3: Run the focused classifier suite**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -only-testing:QuickCookiesTests/FileTypeClassifierTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 4: If failures appear, check whether they expose a real behavior mismatch in `FileTypeClassifier`**

Review against:

```text
QuickCookies/Core/FileTypeClassifier.swift
QuickCookies/Utils/FileUtils.swift
QuickCookies/Config/Constants.swift
```

Only make product-code changes if:

```text
The current implementation contradicts intended project behavior already described in docs or UI expectations.
```

Otherwise:

```text
Adjust the test case input so it matches how the classifier is intentionally designed to behave.
```

- [ ] **Step 5: Re-run the focused classifier suite**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -only-testing:QuickCookiesTests/FileTypeClassifierTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 6: Commit the classifier tests**

Run:

```bash
git add QuickCookiesTests/FileTypeClassifierTests.swift QuickCookiesTests/TestSupport/TemporaryDirectory.swift
git commit -m "test: cover file type classifier"
```

If no helper file was created, use:

```bash
git add QuickCookiesTests/FileTypeClassifierTests.swift
git commit -m "test: cover file type classifier"
```

---

### Task 4: Implement `FileChunkReader` Tests

**Files:**
- Modify: `QuickCookiesTests/FileChunkReaderTests.swift`
- Test: `QuickCookiesTests/FileChunkReaderTests.swift`

- [ ] **Step 1: Replace the smoke test with chunked-reading coverage**

Use this body:

```swift
import XCTest
@testable import QuickCookies

final class FileChunkReaderTests: XCTestCase {
    private var tempDirURL: URL!

    override func setUpWithError() throws {
        tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirURL)
    }

    func testReadSmallFileInSingleChunk() throws {
        let fileURL = tempDirURL.appendingPathComponent("small.txt")
        try "hello world".write(to: fileURL, atomically: true, encoding: .utf8)

        let reader = try FileChunkReader(path: fileURL.path)
        let result = reader.readNextChunk(limitBytes: 1024)

        switch result {
        case .success(let payload):
            XCTAssertEqual(payload.content, "hello world")
            XCTAssertEqual(payload.bytesRead, "hello world".lengthOfBytes(using: .utf8))
            XCTAssertFalse(payload.hasMore)
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }
    }

    func testReadLargeFileAcrossMultipleChunks() throws {
        let content = String(repeating: "abcdefghij", count: 40)
        let fileURL = tempDirURL.appendingPathComponent("large.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let reader = try FileChunkReader(path: fileURL.path)
        let first = reader.readNextChunk(limitBytes: 50)
        let second = reader.readNextChunk(limitBytes: 500)

        switch first {
        case .success(let payload):
            XCTAssertEqual(payload.bytesRead, 50)
            XCTAssertTrue(payload.hasMore)
        case .failure(let error):
            XCTFail("Unexpected failure in first chunk: \(error)")
        }

        switch second {
        case .success(let payload):
            XCTAssertFalse(payload.content.isEmpty)
        case .failure(let error):
            XCTFail("Unexpected failure in second chunk: \(error)")
        }
    }

    func testReadRemainingReturnsUnreadTailAndClosesHandle() throws {
        let content = "0123456789ABCDEFGHIJ"
        let fileURL = tempDirURL.appendingPathComponent("tail.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let reader = try FileChunkReader(path: fileURL.path)
        _ = reader.readNextChunk(limitBytes: 10)
        let remaining = reader.readRemaining()

        switch remaining {
        case .success(let tail):
            XCTAssertEqual(tail, "ABCDEFGHIJ")
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }

        let afterClose = reader.readNextChunk(limitBytes: 10)
        switch afterClose {
        case .success:
            XCTFail("Expected closed-handle failure")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, FileUtils.FileError.readFailed(path: fileURL.path, reason: "文件句柄已关闭").errorDescription)
        }
    }

    func testBinaryFirstChunkFailsImmediately() throws {
        let fileURL = tempDirURL.appendingPathComponent("binary.bin")
        try Data([0x41, 0x00, 0x42, 0x43]).write(to: fileURL)

        let reader = try FileChunkReader(path: fileURL.path)
        let result = reader.readNextChunk(limitBytes: 16)

        switch result {
        case .success:
            XCTFail("Expected binary-file failure")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, FileUtils.FileError.binaryFile(path: fileURL.path).errorDescription)
        }
    }

    func testMissingFileThrowsFileNotFound() {
        let path = tempDirURL.appendingPathComponent("missing.txt").path

        XCTAssertThrowsError(try FileChunkReader(path: path)) { error in
            guard case FileUtils.FileError.fileNotFound(let actualPath) = error else {
                return XCTFail("Expected fileNotFound, got \(error)")
            }
            XCTAssertEqual(actualPath, path)
        }
    }
}
```

- [ ] **Step 2: Run the focused chunk-reader suite**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -only-testing:QuickCookiesTests/FileChunkReaderTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 3: If chunk-size assertions fail, reconcile them with byte-based behavior instead of character-count assumptions**

Keep these invariants:

```text
- `bytesRead` must reflect actual bytes read from disk.
- `hasMore` must track whether `currentOffset < totalSize`.
- binary detection must occur on the first read only.
```

- [ ] **Step 4: Re-run the focused chunk-reader suite**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -only-testing:QuickCookiesTests/FileChunkReaderTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 5: Commit the chunk-reader tests**

Run:

```bash
git add QuickCookiesTests/FileChunkReaderTests.swift
git commit -m "test: cover file chunk reader"
```

---

### Task 5: Implement `FileUtils` Tests

**Files:**
- Modify: `QuickCookiesTests/FileUtilsTests.swift`
- Test: `QuickCookiesTests/FileUtilsTests.swift`

- [ ] **Step 1: Replace the smoke test with coverage for the low-side-effect helpers**

Use this body:

```swift
import XCTest
@testable import QuickCookies

final class FileUtilsTests: XCTestCase {
    private var tempDirURL: URL!

    override func setUpWithError() throws {
        tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirURL)
    }

    func testResolveSymlinkReturnsDestinationPath() throws {
        let target = tempDirURL.appendingPathComponent("target.txt")
        let link = tempDirURL.appendingPathComponent("link.txt")
        try "hello".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertEqual(FileUtils.resolveSymlink(at: link.path), target.path)
    }

    func testReadFileReturnsContentAndEncoding() throws {
        let fileURL = tempDirURL.appendingPathComponent("read.txt")
        try "sample".write(to: fileURL, atomically: true, encoding: .utf8)

        let result = FileUtils.readFile(at: fileURL.path)

        switch result {
        case .success(let payload):
            XCTAssertEqual(payload.content, "sample")
            XCTAssertEqual(payload.encoding, .utf8)
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }
    }

    func testReadFileRejectsBinaryData() throws {
        let fileURL = tempDirURL.appendingPathComponent("binary.bin")
        try Data([0x41, 0x00, 0x42]).write(to: fileURL)

        let result = FileUtils.readFile(at: fileURL.path)

        switch result {
        case .success:
            XCTFail("Expected binary-file failure")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, FileUtils.FileError.binaryFile(path: fileURL.path).errorDescription)
        }
    }

    func testReadFileReturnsFileNotFound() {
        let fileURL = tempDirURL.appendingPathComponent("missing.txt")
        let result = FileUtils.readFile(at: fileURL.path)

        switch result {
        case .success:
            XCTFail("Expected file-not-found failure")
        case .failure(let error):
            XCTAssertEqual(error.errorDescription, FileUtils.FileError.fileNotFound(path: fileURL.path).errorDescription)
        }
    }

    func testReadLimitFileMarksLargeInputAsTruncated() throws {
        let fileURL = tempDirURL.appendingPathComponent("large.txt")
        let content = String(repeating: "1234567890", count: 100)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = FileUtils.readLimitFile(at: fileURL.path, limitBytes: 50)

        switch result {
        case .success(let payload):
            XCTAssertTrue(payload.isTruncated)
            XCTAssertEqual(payload.content.utf8.count, 50)
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }
    }

    func testWriteFilePersistsUTF8Content() throws {
        let fileURL = tempDirURL.appendingPathComponent("write.txt")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let write = FileUtils.writeFile(at: fileURL.path, content: "saved")
        XCTAssertTrue({
            if case .success = write { return true }
            return false
        }())

        let stored = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(stored, "saved")
    }
}
```

- [ ] **Step 2: Run the focused FileUtils suite**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -only-testing:QuickCookiesTests/FileUtilsTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 3: If any assertion fails, verify whether the failure exposes an implementation limitation worth documenting**

Check especially:

```text
- `writeFile` requires the file to already be writable at path
- `readLimitFile` truncation is byte-based, not character-based
- `resolveSymlink` behavior follows Foundation path resolution semantics
```

If behavior is intentional, keep the product code unchanged and adjust only the test input.

- [ ] **Step 4: Re-run the focused FileUtils suite**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -only-testing:QuickCookiesTests/FileUtilsTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 5: Commit the FileUtils tests**

Run:

```bash
git add QuickCookiesTests/FileUtilsTests.swift
git commit -m "test: cover file utils"
```

---

### Task 6: Run The Full Test Suite And Stabilize

**Files:**
- Modify as needed: `QuickCookiesTests/*.swift`
- Modify as needed: `QuickCookies.xcodeproj/project.pbxproj`
- Modify as needed: `QuickCookies.xcodeproj/xcshareddata/xcschemes/QuickCookies.xcscheme`

- [ ] **Step 1: Run the full QuickCookies test suite**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS'
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 2: If the full run fails, categorize failures before changing code**

Use this triage rule:

```text
1. Project wiring failure -> fix project / scheme metadata.
2. Compile failure in tests -> fix imports, visibility, or enum comparison usage.
3. Assertion failure -> verify intended behavior against source.
4. Environment-specific failure -> reduce test coupling to filesystem timing or byte-count assumptions.
```

- [ ] **Step 3: Re-run the full suite after each fix, not just the focused target**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS'
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 4: Capture the final successful command for documentation**

Record this exact command in the delivery notes and, if helpful, in developer docs:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS'
```

- [ ] **Step 5: Commit the stabilized test suite**

Run:

```bash
git add QuickCookies.xcodeproj/project.pbxproj QuickCookies.xcodeproj/xcshareddata/xcschemes/QuickCookies.xcscheme QuickCookiesTests
git commit -m "test: add first-pass xctest coverage"
```

---

### Task 7: Add CI Coverage After Local Stability

**Files:**
- Create: `.github/workflows/test.yml`
- Optional Modify: `README.md`

- [ ] **Step 1: Create the GitHub Actions workflow only after local green status**

Use this workflow body:

```yaml
name: Run Unit Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-14

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Cache SwiftPM
        uses: actions/cache@v4
        with:
          path: |
            ~/Library/Caches/org.swift.swiftpm
            ~/Library/Developer/Xcode/DerivedData
          key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
          restore-keys: |
            ${{ runner.os }}-spm-

      - name: Run Tests
        run: |
          xcodebuild test \
            -project QuickCookies.xcodeproj \
            -scheme QuickCookies \
            -destination 'platform=macOS' \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 2: Verify the workflow syntax locally before pushing**

Run:

```bash
sed -n '1,220p' .github/workflows/test.yml
```

Expected:

```text
Workflow includes only first-phase unit tests and does not reference Finder / Hotkey / WebKit integration coverage.
```

- [ ] **Step 3: Optionally document the local test command in `README.md`**

Add a short developer section such as:

```md
## Running Tests

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS'
```
```

Skip this step if the README already has a suitable developer workflow section.

- [ ] **Step 4: Commit the CI workflow**

Run:

```bash
git add .github/workflows/test.yml README.md
git commit -m "ci: run xctest suite on github actions"
```

If `README.md` was unchanged, use:

```bash
git add .github/workflows/test.yml
git commit -m "ci: run xctest suite on github actions"
```

---

## Spec Coverage Check

This plan covers the validated scope from `docs/xctest-feasibility.md`:

- `QuickCookiesTests` target bootstrap
- Scheme wiring
- First-phase tests for `EncodingDetector`
- First-phase tests for `FileTypeClassifier`
- First-phase tests for `FileChunkReader`
- First-phase tests for `FileUtils`
- Local full-suite validation
- Optional GitHub Actions integration after local stability

Excluded by design from this plan:

- `FileDetector` testability refactor
- `Settings` side-effect isolation
- `MarkdownPDFExporter` extraction and test coverage
- `HotkeyManager` automation

These should be separate follow-up plans.

---

## Risks To Watch During Execution

- `project.pbxproj` edits are easy to corrupt; validate with `build-for-testing` immediately after wiring changes.
- Some assertions may need to compare `errorDescription` or destructure `FileUtils.FileError`, because the enum is not declared `Equatable`.
- `readLimitFile` and `FileChunkReader` are byte-oriented APIs; avoid character-count assumptions in tests using multibyte text.
- `writeFile` only succeeds when the target path is already writable, so create the file first in tests.
- CI should be introduced only after local green runs, otherwise project wiring and environment issues get mixed together.
