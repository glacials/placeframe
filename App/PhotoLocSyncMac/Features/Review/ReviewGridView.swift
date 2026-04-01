import AppKit
import PhotoLocSyncAdapters
import PhotoLocSyncCore
import SwiftUI

@MainActor
final class ReviewThumbnailLoader: ObservableObject {
    @Published private(set) var image: NSImage?

    private let item: ReviewItem
    private let thumbnailProvider: PhotoThumbnailProvider
    private var hasStarted = false

    init(item: ReviewItem, thumbnailProvider: PhotoThumbnailProvider) {
        self.item = item
        self.thumbnailProvider = thumbnailProvider
    }

    func loadIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            do {
                if let cgImage = try await thumbnailProvider.thumbnail(for: item.asset, maxPixelSize: 320) {
                    image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                }
            } catch {
                image = nil
            }
        }
    }
}

@MainActor
final class ReviewPreviewSourceAnchor: ObservableObject {
    weak var view: NSView?
}

private struct ReviewPreviewSourceBridge: NSViewRepresentable {
    let captureView: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        captureView(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        captureView(nsView)
    }
}

private struct ReviewGridItemView: View {
    let entry: ReviewSelection
    let isPhotoSelected: Bool
    let selectPhoto: (String, ReviewPhotoSelectionMode) -> Void
    let applyChange: (String) async -> Void
    let skipForNow: (String) -> Void
    let dismissPermanently: (String) async -> Void
    let copyLocation: (String) -> Void
    let pasteLocation: (String) -> Void
    let canPasteLocation: (String) -> Bool
    let deletePhoto: (String) async -> Void
    let showOnMap: (ReviewItem) -> Void
    let quickLook: (ReviewItem, NSView?, NSImage?) -> Void
    let captureDateText: (ReviewItem) -> String
    let timeDeltaText: (ReviewItem) -> String

    @StateObject private var thumbnailLoader: ReviewThumbnailLoader
    @StateObject private var previewSourceAnchor = ReviewPreviewSourceAnchor()
    init(
        entry: ReviewSelection,
        isPhotoSelected: Bool,
        thumbnailProvider: PhotoThumbnailProvider,
        selectPhoto: @escaping (String, ReviewPhotoSelectionMode) -> Void,
        applyChange: @escaping (String) async -> Void,
        skipForNow: @escaping (String) -> Void,
        dismissPermanently: @escaping (String) async -> Void,
        copyLocation: @escaping (String) -> Void,
        pasteLocation: @escaping (String) -> Void,
        canPasteLocation: @escaping (String) -> Bool,
        deletePhoto: @escaping (String) async -> Void,
        showOnMap: @escaping (ReviewItem) -> Void,
        quickLook: @escaping (ReviewItem, NSView?, NSImage?) -> Void,
        captureDateText: @escaping (ReviewItem) -> String,
        timeDeltaText: @escaping (ReviewItem) -> String
    ) {
        self.entry = entry
        self.isPhotoSelected = isPhotoSelected
        self.selectPhoto = selectPhoto
        self.applyChange = applyChange
        self.skipForNow = skipForNow
        self.dismissPermanently = dismissPermanently
        self.copyLocation = copyLocation
        self.pasteLocation = pasteLocation
        self.canPasteLocation = canPasteLocation
        self.deletePhoto = deletePhoto
        self.showOnMap = showOnMap
        self.quickLook = quickLook
        self.captureDateText = captureDateText
        self.timeDeltaText = timeDeltaText
        _thumbnailLoader = StateObject(wrappedValue: ReviewThumbnailLoader(item: entry.item, thumbnailProvider: thumbnailProvider))
    }

    var body: some View {
        let hasLocation = entry.item.proposedCoordinate != nil
        let canPasteCopiedLocation = canPasteLocation(entry.id)

        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 220)
                if let image = thumbnailLoader.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
            }
            .task {
                thumbnailLoader.loadIfNeeded()
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture(count: 2) {
                triggerQuickLook()
            }
            .overlay {
                ReviewPreviewSourceBridge { view in
                    previewSourceAnchor.view = view
                }
                .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.item.locationLabel)
                    .font(.headline)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Label(captureDateText(entry.item), systemImage: "calendar")
                    .foregroundStyle(.secondary)

                HStack {
                    Label(entry.item.confidence.rawValue.capitalized, systemImage: confidenceSymbol(for: entry.item.confidence))
                    Spacer()
                    Text("Δ \(timeDeltaText(entry.item))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(dispositionText(entry.item.disposition))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(dispositionColor(entry.item.disposition))

                if let coordinate = entry.item.proposedCoordinate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.copiedFromAssetID == nil ? "Raw match" : "Pasted location")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        if let copiedFromAssetID = entry.copiedFromAssetID {
                            Text("Copied from: \(copiedFromAssetID)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else if let decision = entry.item.suggestedDecision {
                            Text("Asset: \(decision.assetID)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Review action")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button("Apply") {
                    Task {
                        await applyChange(entry.id)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(entry.item.suggestedDecision == nil)

                HStack(spacing: 8) {
                    Button("Skip for Now") {
                        skipForNow(entry.id)
                    }
                    .buttonStyle(.bordered)

                    Button("Never Show Again") {
                        Task {
                            await dismissPermanently(entry.id)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isPhotoSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            selectPhoto(entry.id, selectionMode)
        }
        .contextMenu {
            Button("Quick Look") {
                triggerQuickLook()
            }

            if hasLocation || canPasteCopiedLocation {
                Divider()
                Button("Copy Location") {
                    copyLocation(entry.id)
                }
                .disabled(!hasLocation)

                Button("Paste Location") {
                    pasteLocation(entry.id)
                }
                .disabled(!canPasteCopiedLocation)

                if hasLocation {
                    Button("See on map") {
                        showOnMap(entry.item)
                    }
                }
            }

            Divider()
            Button("Delete Photo", role: .destructive) {
                Task {
                    await deletePhoto(entry.id)
                }
            }
        }
    }

    private var cardBackgroundColor: Color {
        isPhotoSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08)
    }

    private var selectionMode: ReviewPhotoSelectionMode {
        guard let modifierFlags = NSApp.currentEvent?.modifierFlags else {
            return .replace
        }

        if modifierFlags.contains(.shift) {
            return .range(extendExisting: modifierFlags.contains(.command))
        }

        if modifierFlags.contains(.command) {
            return .toggle
        }

        return .replace
    }

    private func triggerQuickLook() {
        quickLook(entry.item, previewSourceAnchor.view, thumbnailLoader.image)
    }

    private func confidenceSymbol(for confidence: MatchConfidence) -> String {
        switch confidence {
        case .excellent: "checkmark.seal.fill"
        case .acceptable: "checkmark.seal"
        case .maybe: "questionmark.diamond"
        case .rejected: "xmark.octagon"
        }
    }

    private func dispositionText(_ disposition: MatchDisposition) -> String {
        switch disposition {
        case .autoSuggested: "Auto-suggested"
        case .ambiguous: "Needs review"
        case .unmatched: "Unmatched"
        }
    }

    private func dispositionColor(_ disposition: MatchDisposition) -> Color {
        switch disposition {
        case .autoSuggested: .green
        case .ambiguous: .orange
        case .unmatched: .secondary
        }
    }
}

struct ReviewGridView: View {
    let entries: [ReviewSelection]
    let selectedPhotoIDs: Set<String>
    let thumbnailProvider: PhotoThumbnailProvider
    let selectPhoto: (String, ReviewPhotoSelectionMode) -> Void
    let applyChange: (String) async -> Void
    let skipForNow: (String) -> Void
    let dismissPermanently: (String) async -> Void
    let copyLocation: (String) -> Void
    let pasteLocation: (String) -> Void
    let canPasteLocation: (String) -> Bool
    let deletePhoto: (String) async -> Void
    let showOnMap: (ReviewItem) -> Void
    let quickLook: (ReviewItem, NSView?, NSImage?) -> Void
    let captureDateText: (ReviewItem) -> String
    let timeDeltaText: (ReviewItem) -> String

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 240), spacing: 16)]
    }

    private var focusedPhotoID: String? {
        guard selectedPhotoIDs.count == 1 else { return nil }
        return selectedPhotoIDs.first
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Use the action buttons to work through the queue. Click a photo to focus the map. Command-click toggles photos. Shift-click selects the range between photos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            ReviewGridItemView(
                                entry: entry,
                                isPhotoSelected: selectedPhotoIDs.contains(entry.id),
                                thumbnailProvider: thumbnailProvider,
                                selectPhoto: selectPhoto,
                                applyChange: applyChange,
                                skipForNow: skipForNow,
                                dismissPermanently: dismissPermanently,
                                copyLocation: copyLocation,
                                pasteLocation: pasteLocation,
                                canPasteLocation: canPasteLocation,
                                deletePhoto: deletePhoto,
                                showOnMap: showOnMap,
                                quickLook: quickLook,
                                captureDateText: captureDateText,
                                timeDeltaText: timeDeltaText
                            )
                            .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollToFocusedPhoto(using: proxy)
            }
            .onChange(of: focusedPhotoID) { _, _ in
                scrollToFocusedPhoto(using: proxy)
            }
            .onChange(of: entries.map(\.id)) { _, _ in
                scrollToFocusedPhoto(using: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func scrollToFocusedPhoto(using proxy: ScrollViewProxy) {
        guard let focusedPhotoID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(focusedPhotoID, anchor: .top)
            }
        }
    }
}
