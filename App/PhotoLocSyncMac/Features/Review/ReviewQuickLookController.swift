import AppKit
import Foundation
import PhotoLocSyncAdapters
import PhotoLocSyncCore
@preconcurrency import QuickLookUI

@MainActor
final class ReviewQuickLookController: NSObject, ObservableObject {
    private let previewDirectory: URL

    private var previewURL: URL?
    private var previewTask: Task<Void, Never>?
    private weak var sourceView: NSView?
    private var transitionImage: NSImage?

    override init() {
        let fileManager = FileManager.default
        self.previewDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PhotoLocSyncQuickLook-\(UUID().uuidString)", isDirectory: true)
        super.init()

        try? fileManager.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
    }

    func quickLook(
        _ item: ReviewItem,
        using thumbnailProvider: PhotoThumbnailProvider,
        sourceView: NSView?,
        transitionImage: NSImage?
    ) {
        previewTask?.cancel()
        self.sourceView = sourceView
        self.transitionImage = transitionImage
        previewTask = Task {
            do {
                guard let url = try await thumbnailProvider.previewFileURL(for: item.asset, in: previewDirectory) else {
                    NSSound.beep()
                    return
                }
                guard !Task.isCancelled else { return }
                previewURL = url
                presentPanel()
            } catch {
                guard !Task.isCancelled else { return }
                NSSound.beep()
            }
        }
    }

    private func presentPanel() {
        guard let panel = QLPreviewPanel.shared(), previewURL != nil else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        panel.makeKeyAndOrderFront(nil)
    }

    private func sourceFrameOnScreen() -> NSRect {
        guard let sourceView,
              let window = sourceView.window else {
            return .zero
        }

        let windowRect = sourceView.convert(sourceView.bounds, to: nil)
        return window.convertToScreen(windowRect)
    }

}

@MainActor
extension ReviewQuickLookController: @preconcurrency QLPreviewPanelDataSource {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL.map { $0 as NSURL }
    }
}

extension ReviewQuickLookController: QLPreviewPanelDelegate {
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        MainActor.assumeIsolated {
            sourceFrameOnScreen()
        }
    }

    nonisolated func previewPanel(
        _ panel: QLPreviewPanel!,
        transitionImageFor item: QLPreviewItem!,
        contentRect: UnsafeMutablePointer<NSRect>!
    ) -> Any! {
        let transitionImage = MainActor.assumeIsolated { self.transitionImage }
        if let transitionImage {
            contentRect?.pointee = NSRect(origin: .zero, size: transitionImage.size)
        }
        return transitionImage
    }
}
