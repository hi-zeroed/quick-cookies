import Foundation

struct PreviewTargetResolver {
    let finderSelectionProvider: () -> String?

    init(
        finderSelectionProvider: @escaping () -> String? = {
            switch FileDetector.getSelectedFilePath() {
            case .success(let path):
                return path
            case .failure:
                return nil
            }
        }
    ) {
        self.finderSelectionProvider = finderSelectionProvider
    }

    func resolve(request: PreviewLaunchRequest) throws -> PreviewTarget {
        let originalPath: String

        switch request.pathIntent {
        case .direct(let path):
            originalPath = path
        case .finderSelection:
            guard let selectedPath = finderSelectionProvider() else {
                throw PreviewTargetError.noFinderSelection
            }
            originalPath = selectedPath
        }

        let resolvedPath = FileUtils.resolveSymlink(at: originalPath)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory) else {
            throw PreviewTargetError.fileNotFound
        }

        if isDirectory.boolValue {
            return PreviewTarget(
                originalPath: originalPath,
                resolvedPath: resolvedPath,
                renderType: .unsupported,
                language: nil,
                displayName: URL(fileURLWithPath: resolvedPath).lastPathComponent
            )
        }

        let renderType = FileTypeClassifier.classify(path: resolvedPath)

        return PreviewTarget(
            originalPath: originalPath,
            resolvedPath: resolvedPath,
            renderType: renderType,
            language: FileTypeClassifier.getLanguageName(path: resolvedPath),
            displayName: URL(fileURLWithPath: resolvedPath).lastPathComponent
        )
    }
}
