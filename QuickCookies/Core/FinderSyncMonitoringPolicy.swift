import Foundation

enum FinderSyncMonitoringPolicy {
    static func monitoredDirectoryURLs(
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Set<URL> {
        _ = homeDirectoryURL
        return [URL(fileURLWithPath: "/", isDirectory: true)]
    }
}
