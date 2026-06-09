import Foundation

struct PreviewNavigationContext: Equatable {
    let currentPath: String
    let orderedPaths: [String]
    let currentIndex: Int

    var previousPath: String? {
        guard currentIndex > 0 else {
            return nil
        }
        return orderedPaths[currentIndex - 1]
    }

    var nextPath: String? {
        guard currentIndex + 1 < orderedPaths.count else {
            return nil
        }
        return orderedPaths[currentIndex + 1]
    }
}

enum PreviewNavigationContextBuilder {
    static func build(
        currentPath: String,
        fileManager: FileManager = .default
    ) -> PreviewNavigationContext? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: currentPath, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }

        let currentURL = URL(fileURLWithPath: currentPath)
        let directoryURL = currentURL.deletingLastPathComponent()

        let directoryPath = directoryURL.path
        guard let childNames = try? fileManager.contentsOfDirectory(atPath: directoryPath) else {
            return nil
        }

        let orderedPaths = childNames
            .filter { childName in
                let childPath = (directoryPath as NSString).appendingPathComponent(childName)
                var childIsDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: childPath, isDirectory: &childIsDirectory) else {
                    return false
                }
                return !childIsDirectory.boolValue
            }
            .sorted { lhs, rhs in
                let comparison = lhs.localizedStandardCompare(rhs)
                return comparison == .orderedAscending
            }
            .map { childName in
                (directoryPath as NSString).appendingPathComponent(childName)
            }

        guard let currentIndex = orderedPaths.firstIndex(of: currentPath) else {
            return nil
        }

        return PreviewNavigationContext(
            currentPath: currentPath,
            orderedPaths: orderedPaths,
            currentIndex: currentIndex
        )
    }
}
