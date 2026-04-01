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
    let toggleSelection: (String) -> Void
    let showOnMap: (ReviewItem) -> Void
    let quickLook: (ReviewItem, NSView?, NSImage?) -> Void
    let captureDateText: (ReviewItem) -> String
    let timeDeltaText: (ReviewItem) -> String

    @StateObject private var thumbnailLoader: ReviewThumbnailLoader
    @StateObject private var previewSourceAnchor = ReviewPreviewSourceAnchor()

    init(
        entry: ReviewSelection,
        thumbnailProvider: PhotoThumbnailProvider,
        toggleSelection: @escaping (String) -> Void,
        showOnMap: @escaping (ReviewItem) -> Void,
        quickLook: @escaping (ReviewItem, NSView?, NSImage?) -> Void,
        captureDateText: @escaping (ReviewItem) -> String,
        timeDeltaText: @escaping (ReviewItem) -> String
    ) {
        self.entry = entry
        self.toggleSelection = toggleSelection
        self.showOnMap = showOnMap
        self.quickLook = quickLook
        self.captureDateText = captureDateText
        self.timeDeltaText = timeDeltaText
        _thumbnailLoader = StateObject(wrappedValue: ReviewThumbnailLoader(item: entry.item, thumbnailProvider: thumbnailProvider))
    }

    var body: some View {
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
                        Text("Raw match")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        if let decision = entry.item.suggestedDecision {
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

            Toggle(isOn: Binding(
                get: { entry.isSelected },
                set: { _ in toggleSelection(entry.id) }
            )) {
                Text(entry.item.suggestedDecision == nil ? "No suggested write" : "Apply to Photos")
            }
            .toggleStyle(.switch)
            .disabled(entry.item.suggestedDecision == nil)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button("Quick Look") {
                triggerQuickLook()
            }

            if entry.item.proposedCoordinate != nil {
                Divider()
                Button("See on map") {
                    showOnMap(entry.item)
                }
            }
        }
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
    let thumbnailProvider: PhotoThumbnailProvider
    let toggleSelection: (String) -> Void
    let showOnMap: (ReviewItem) -> Void
    let quickLook: (ReviewItem, NSView?, NSImage?) -> Void
    let captureDateText: (ReviewItem) -> String
    let timeDeltaText: (ReviewItem) -> String

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 240), spacing: 16)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(entries) { entry in
                    ReviewGridItemView(
                        entry: entry,
                        thumbnailProvider: thumbnailProvider,
                        toggleSelection: toggleSelection,
                        showOnMap: showOnMap,
                        quickLook: quickLook,
                        captureDateText: captureDateText,
                        timeDeltaText: timeDeltaText
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
