import Foundation

class FileWatcher {
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private let url: URL
    private var isWatching = false
    
    var onFileChanged: (() -> Void)?

    init(url: URL) {
        self.url = url
    }

    func start() {
        guard !isWatching else { return }
        
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .default)
        )
        
        source?.setEventHandler { [weak self] in
            // Delay for 100ms to allow file writing to settle down and prevent duplicate triggers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.onFileChanged?()
            }
        }
        
        source?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        
        source?.resume()
        isWatching = true
    }

    func stop() {
        guard isWatching else { return }
        source?.cancel()
        source = nil
        isWatching = false
    }
    
    deinit {
        stop()
    }
}
