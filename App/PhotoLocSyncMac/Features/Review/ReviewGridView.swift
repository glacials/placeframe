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

private struct ReviewLocationChangeBadge: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    let detailLines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(detailLines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct ReviewListItemView: View {
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
    @State private var isShowingStatusInfo = false
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
        let status = ReviewSuggestionStatusDescriptor(item: entry.item)

        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
                if let image = thumbnailLoader.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .frame(width: 168, height: 132)

            VStack(alignment: .leading, spacing: 10) {
                Text("Location")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 10) {
                    ReviewLocationChangeBadge(
                        title: "Now",
                        value: currentLocationSummary,
                        systemImage: "circle.dashed",
                        tint: Color.secondary,
                        detailLines: []
                    )

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    ReviewLocationChangeBadge(
                        title: "Apply",
                        value: selectedLocationLabel,
                        systemImage: "mappin.and.ellipse",
                        tint: Color.accentColor,
                        detailLines: selectedLocationDetailLines
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(currentLocationDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(locationSourceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(captureDateText(entry.item), systemImage: "calendar")
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 8) {
                    Label(status.title, systemImage: status.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status.tone.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status.tone.backgroundColor, in: Capsule())

                    Button {
                        isShowingStatusInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .help("Explain this minute badge")

                    Spacer()
                }
                .foregroundStyle(.secondary)
                .popover(isPresented: $isShowingStatusInfo, arrowEdge: .top) {
                    ReviewSuggestionStatusHelpView(item: entry.item)
                        .padding()
                }

                Text(status.shortDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if entry.item.timeDelta != nil {
                    Text("Timeline time offset: \(timeDeltaText(entry.item))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review action")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Menu {
                        ForEach(entry.item.availableLocationOptions) { option in
                            Button {
                                setLocationPrecision([entry.id], option.precision)
                            } label: {
                                if entry.item.selectedPrecision == option.precision {
                                    Label(locationOptionMenuTitle(for: option), systemImage: "checkmark")
                                } else {
                                    Text(locationOptionMenuTitle(for: option))
                                }
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save as")
                                    .font(.subheadline.weight(.semibold))
                                Text(selectedLocationMenuLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)

                    Button("Apply") {
                        Task {
                            await applyChange(entry.id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(entry.item.suggestedDecision == nil)

                    Menu("Leave Blank") {
                        Button("This Time") {
                            skipForNow(entry.id)
                        }

                        Button("Every Time") {
                            Task {
                                await dismissPermanently(entry.id)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                                Label(contextMenuPrecisionTitle(for: precision), systemImage: "checkmark")
                            } else {
                                Text(contextMenuPrecisionTitle(for: precision))
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

            Menu(leaveBlankContextMenuTitle) {
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
        appliesToMultiplePhotos ? "Apply Selected (\(contextMenuTargetIDs.count))" : "Apply"
    }

    private var leaveBlankContextMenuTitle: String {
        appliesToMultiplePhotos ? "Leave Selected Blank (\(contextMenuTargetIDs.count))" : "Leave Blank"
    }

    private var skipContextMenuTitle: String {
        "This Time"
    }

    private var dismissContextMenuTitle: String {
        "Every Time"
    }

    private var precisionContextMenuTitle: String {
        appliesToMultiplePhotos ? "Save Selected As (\(contextMenuTargetIDs.count))" : "Save As"
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

    private var selectedLocationOption: LocationOption? {
        if let selectedPrecision = entry.item.selectedPrecision,
           let option = entry.item.locationOption(for: selectedPrecision) {
            return option
        }
        return entry.item.availableLocationOptions.first
    }

    private var selectedLocationLabel: String {
        selectedLocationOption?.label ?? entry.item.locationLabel
    }

    private var selectedLocationMenuLabel: String {
        truncatedLocationLabel(selectedLocationLabel, maxLength: 72)
    }

    private var currentLocationSummary: String {
        entry.item.asset.hasLocation ? "Saved in Photos" : "Blank"
    }

    private var currentLocationDetailText: String {
        entry.item.asset.hasLocation
            ? "This photo already has saved location metadata."
            : "This photo has no saved location metadata yet."
    }

    private var selectedLocationDetailLines: [String] {
        guard let coordinate = entry.item.proposedCoordinate else { return [] }

        return [
            selectedLocationOption?.precision.title ?? "",
            String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
        ]
        .filter { !$0.isEmpty }
    }

    private var locationSourceText: String {
        if let copiedFromAssetID = entry.copiedFromAssetID {
            return "Source: copied from \(copiedFromAssetID)"
        }
        return "Source: matched from this photo's timeline data"
    }

    private func locationOptionMenuTitle(for option: LocationOption) -> String {
        truncatedLocationLabel(option.label)
    }

    private func contextMenuPrecisionTitle(for precision: LocationPrecision) -> String {
        guard contextMenuTargetIDs.count == 1,
              let option = entry.item.locationOption(for: precision) else {
            return precision.title
        }

        return locationOptionMenuTitle(for: option)
    }

    private func truncatedLocationLabel(_ label: String, maxLength: Int = 56) -> String {
        guard label.count > maxLength else { return label }
        let prefix = label.prefix(maxLength - 1)
        return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

struct ReviewListView: View {
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

    private var focusedPhotoID: String? {
        guard selectedPhotoIDs.count == 1 else { return nil }
        return selectedPhotoIDs.first
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(entries) { entry in
                        let contextMenuTargetIDs = contextMenuTargetIDs(for: entry)
                        ReviewListItemView(
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
