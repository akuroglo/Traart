import AppKit

/// Transparent overlay view that accepts drag-and-drop of audio/video files
/// onto the status bar icon. Supports all media formats that FileWatcher handles.
final class DragDropView: NSView {
    var onFilesDropped: (([URL]) -> Void)?

    private static let mediaExtensions: Set<String> = [
        "wav", "mp3", "m4a", "flac", "ogg", "oga", "opus",
        "aac", "wma", "amr", "m4b", "mp2", "aiff", "aif",
        "mp4", "mkv", "webm", "mov", "avi", "wmv", "m4v"
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let validFiles = extractMediaURLs(from: sender)
        return validFiles.isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let validFiles = extractMediaURLs(from: sender)
        return validFiles.isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = extractMediaURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onFilesDropped?(urls)
        return true
    }

    private func extractMediaURLs(from sender: NSDraggingInfo) -> [URL] {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else { return [] }

        return items.filter { url in
            let ext = url.pathExtension.lowercased()
            return Self.mediaExtensions.contains(ext)
        }
    }
}
