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
    let contextMenuTargetIDs: [String]
    let canApplyContextMenuTargets: Bool
    let contextMenuPrecisions: [LocationPrecision]
    let selectedContextMenuPrecision: LocationPrecision?
    let selectPhoto: (String, ReviewPhotoSelectionMode) -> Void
    let setLocationPrecision: ([String], LocationPrecision) -> Void
    let applyChange: (String) async -> Void
    let applyChanges: ([String]) async -> Void
    let skipForNow: (String) -> Void
    let skipPhotosForNow: ([String]) -> Void
    let dismissPermanently: (String) async -> Void
    let dismissPhotosPermanently: ([String]) async -> Void
    let copyLocation: (String) -> Void
    let pasteLocation: ([String]) -> Void
    let canPasteLocation: ([String]) -> Bool
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
        contextMenuTargetIDs: [String],
        canApplyContextMenuTargets: Bool,
        contextMenuPrecisions: [LocationPrecision],
        selectedContextMenuPrecision: LocationPrecision?,
        thumbnailProvider: PhotoThumbnailProvider,
        selectPhoto: @escaping (String, ReviewPhotoSelectionMode) -> Void,
        setLocationPrecision: @escaping ([String], LocationPrecision) -> Void,
        applyChange: @escaping (String) async -> Void,
        applyChanges: @escaping ([String]) async -> Void,
        skipForNow: @escaping (String) -> Void,
        skipPhotosForNow: @escaping ([String]) -> Void,
        dismissPermanently: @escaping (String) async -> Void,
        dismissPhotosPermanently: @escaping ([String]) async -> Void,
        copyLocation: @escaping (String) -> Void,
        pasteLocation: @escaping ([String]) -> Void,
        canPasteLocation: @escaping ([String]) -> Bool,
        deletePhoto: @escaping (String) async -> Void,
        showOnMap: @escaping (ReviewItem) -> Void,
        quickLook: @escaping (ReviewItem, NSView?, NSImage?) -> Void,
        captureDateText: @escaping (ReviewItem) -> String,
        timeDeltaText: @escaping (ReviewItem) -> String
    ) {
        self.entry = entry
        self.isPhotoSelected = isPhotoSelected
        self.contextMenuTargetIDs = contextMenuTargetIDs
        self.canApplyContextMenuTargets = canApplyContextMenuTargets
        self.contextMenuPrecisions = contextMenuPrecisions
        self.selectedContextMenuPrecision = selectedContextMenuPrecision
        self.selectPhoto = selectPhoto
        self.setLocationPrecision = setLocationPrecision
        self.applyChange = applyChange
        self.applyChanges = applyChanges
        self.skipForNow = skipForNow
        self.skipPhotosForNow = skipPhotosForNow
        self.dismissPermanently = dismissPermanently
        self.dismissPhotosPermanently = dismissPhotosPermanently
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
        let canPasteCopiedLocation = canPasteLocation(contextMenuTargetIDs)
        let selectedPrecisionTitle = entry.item.selectedPrecision?.title ?? LocationPrecision.exact.title

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
                Text("Timeline suggestion")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(entry.item.locationLabel)
                    .font(.headline)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(entry.item.asset.hasLocation ? "Apple Photos already has saved location metadata." : "Apple Photos currently has no saved location metadata.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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
                        Text("What will be written")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(selectedPrecisionTitle)
                            .font(.caption)
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
                        } else {
                            Text("Source: this photo's timeline match")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Does this suggested location look right?")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Menu {
                    ForEach(entry.item.availableLocationOptions) { option in
                        Button {
                            setLocationPrecision([entry.id], option.precision)
                        } label: {
                            if entry.item.selectedPrecision == option.precision {
                                Label(option.precision.title, systemImage: "checkmark")
                            } else {
                                Text(option.precision.title)
                            }
                        }
                    }
                } label: {
                    Label("Precision: \(selectedPrecisionTitle)", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)

                Button("This Looks Correct") {
                    Task {
                        await applyChange(entry.id)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(entry.item.suggestedDecision == nil)

                Menu("This Looks Wrong") {
                    Button("Skip for Now") {
                        skipForNow(entry.id)
                    }

                    Button("Never Show Again") {
                        Task {
                            await dismissPermanently(entry.id)
                        }
                    }
                }
                .buttonStyle(.bordered)
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

            Divider()
            if !contextMenuPrecisions.isEmpty {
                Menu(precisionContextMenuTitle) {
                    ForEach(contextMenuPrecisions) { precision in
                        Button {
                            setLocationPrecision(contextMenuTargetIDs, precision)
                        } label: {
                            if selectedContextMenuPrecision == precision {
                                Label(precision.title, systemImage: "checkmark")
                            } else {
                                Text(precision.title)
                            }
                        }
                    }
                }
            }

            Button(applyContextMenuTitle) {
                Task {
                    await applyChanges(contextMenuTargetIDs)
                }
            }
            .disabled(!canApplyContextMenuTargets)

            Menu(incorrectContextMenuTitle) {
                Button(skipContextMenuTitle) {
                    skipPhotosForNow(contextMenuTargetIDs)
                }

                Button(dismissContextMenuTitle) {
                    Task {
                        await dismissPhotosPermanently(contextMenuTargetIDs)
                    }
                }
            }

            if hasLocation || canPasteCopiedLocation {
                Divider()
                Button("Copy Location") {
                    copyLocation(entry.id)
                }
                .disabled(!hasLocation)

                Button("Paste Location") {
                    pasteLocation(contextMenuTargetIDs)
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

    private var appliesToMultiplePhotos: Bool {
        contextMenuTargetIDs.count > 1
    }

    private var applyContextMenuTitle: String {
        appliesToMultiplePhotos ? "These Look Correct (\(contextMenuTargetIDs.count))" : "This Looks Correct"
    }

    private var incorrectContextMenuTitle: String {
        appliesToMultiplePhotos ? "These Look Wrong (\(contextMenuTargetIDs.count))" : "This Looks Wrong"
    }

    private var skipContextMenuTitle: String {
        appliesToMultiplePhotos ? "Skip Selected for Now (\(contextMenuTargetIDs.count))" : "Skip for Now"
    }

    private var dismissContextMenuTitle: String {
        appliesToMultiplePhotos ? "Never Show Selected Again (\(contextMenuTargetIDs.count))" : "Never Show Again"
    }

    private var precisionContextMenuTitle: String {
        appliesToMultiplePhotos ? "Choose Precision (\(contextMenuTargetIDs.count))" : "Choose Precision"
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
    let setLocationPrecision: ([String], LocationPrecision) -> Void
    let applyChange: (String) async -> Void
    let applyChanges: ([String]) async -> Void
    let skipForNow: (String) -> Void
    let skipPhotosForNow: ([String]) -> Void
    let dismissPermanently: (String) async -> Void
    let dismissPhotosPermanently: ([String]) async -> Void
    let copyLocation: (String) -> Void
    let pasteLocation: ([String]) -> Void
    let canPasteLocation: ([String]) -> Bool
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
                    Text("Each photo shows a timeline suggestion, not existing metadata from Apple Photos. Click a photo to focus the map. Command-click toggles photos. Shift-click selects the range between photos. Command-A selects every photo on the current day. Right-click a selected group to change precision or mark it correct or incorrect together.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            let contextMenuTargetIDs = contextMenuTargetIDs(for: entry)
                            ReviewGridItemView(
                                entry: entry,
                                isPhotoSelected: selectedPhotoIDs.contains(entry.id),
                                contextMenuTargetIDs: contextMenuTargetIDs,
                                canApplyContextMenuTargets: canApply(to: contextMenuTargetIDs),
                                contextMenuPrecisions: contextMenuPrecisions(for: contextMenuTargetIDs),
                                selectedContextMenuPrecision: selectedPrecision(for: contextMenuTargetIDs),
                                thumbnailProvider: thumbnailProvider,
                                selectPhoto: selectPhoto,
                                setLocationPrecision: setLocationPrecision,
                                applyChange: applyChange,
                                applyChanges: applyChanges,
                                skipForNow: skipForNow,
                                skipPhotosForNow: skipPhotosForNow,
                                dismissPermanently: dismissPermanently,
                                dismissPhotosPermanently: dismissPhotosPermanently,
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

    private func contextMenuTargetIDs(for entry: ReviewSelection) -> [String] {
        guard selectedPhotoIDs.count > 1, selectedPhotoIDs.contains(entry.id) else {
            return [entry.id]
        }

        return entries.compactMap { candidate in
            selectedPhotoIDs.contains(candidate.id) ? candidate.id : nil
        }
    }

    private func canApply(to assetIDs: [String]) -> Bool {
        let targetAssetIDs = Set(assetIDs)
        guard !targetAssetIDs.isEmpty else { return false }

        return entries
            .filter { targetAssetIDs.contains($0.id) }
            .allSatisfy { $0.item.suggestedDecision != nil }
    }

    private func contextMenuPrecisions(for assetIDs: [String]) -> [LocationPrecision] {
        let targetAssetIDs = Set(assetIDs)
        guard let firstEntry = entries.first(where: { targetAssetIDs.contains($0.id) }) else {
            return []
        }

        var sharedPrecisions = Set(firstEntry.item.availableLocationOptions.map(\.precision))
        for entry in entries where targetAssetIDs.contains(entry.id) {
            sharedPrecisions.formIntersection(entry.item.availableLocationOptions.map(\.precision))
        }

        return LocationPrecision.allCases.filter { sharedPrecisions.contains($0) }
    }

    private func selectedPrecision(for assetIDs: [String]) -> LocationPrecision? {
        let targetAssetIDs = Set(assetIDs)
        let precisions = entries
            .filter { targetAssetIDs.contains($0.id) }
            .compactMap(\.item.selectedPrecision)

        guard let firstPrecision = precisions.first,
              precisions.count == assetIDs.count,
              precisions.allSatisfy({ $0 == firstPrecision }) else {
            return nil
        }

        return firstPrecision
    }
}
