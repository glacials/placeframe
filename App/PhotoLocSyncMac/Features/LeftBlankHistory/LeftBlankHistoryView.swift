import AppKit
import PhotoLocSyncAdapters
import PhotoLocSyncCore
import SwiftUI

@MainActor
final class LeftBlankHistoryViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var records: [LeftBlankPhotoRecord] = []

    let thumbnailProvider: PhotoThumbnailProvider
    private let reviewSuppressionStore: ReviewSuppressionStoring

    init(
        reviewSuppressionStore: ReviewSuppressionStoring,
        thumbnailProvider: PhotoThumbnailProvider
    ) {
        self.reviewSuppressionStore = reviewSuppressionStore
        self.thumbnailProvider = thumbnailProvider
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        records = await reviewSuppressionStore.suppressedRecords()
    }
}

@MainActor
private final class LeftBlankHistoryThumbnailLoader: ObservableObject {
    @Published private(set) var image: NSImage?

    private let asset: PhotoAsset
    private let thumbnailProvider: PhotoThumbnailProvider
    private var hasStarted = false

    init(record: LeftBlankPhotoRecord, thumbnailProvider: PhotoThumbnailProvider) {
        self.asset = PhotoAsset(
            id: record.assetID,
            creationDate: record.captureDate ?? .distantPast,
            hasLocation: false
        )
        self.thumbnailProvider = thumbnailProvider
    }

    func loadIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            do {
                guard let cgImage = try await thumbnailProvider.thumbnail(for: asset, maxPixelSize: 560) else {
                    image = nil
                    return
                }

                image = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )
            } catch {
                image = nil
            }
        }
    }
}

struct LeftBlankHistoryView: View {
    @ObservedObject var viewModel: LeftBlankHistoryViewModel

    private let gridColumns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 16, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if viewModel.isLoading && viewModel.records.isEmpty {
                ProgressView("Loading left blank photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.records.isEmpty {
                ContentUnavailableView(
                    "No Left Blank Photos",
                    systemImage: "eye.slash",
                    description: Text("Photos you choose to leave blank forever will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                        ForEach(viewModel.records) { record in
                            LeftBlankHistoryCard(
                                record: record,
                                thumbnailProvider: viewModel.thumbnailProvider
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 680, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Left Blank Photos")
                    .font(.largeTitle.bold())
                Text("This window keeps a running list of photos you chose to leave blank forever, so you can revisit those decisions later.")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
    }
}

private struct LeftBlankHistoryCard: View {
    let record: LeftBlankPhotoRecord
    let thumbnailProvider: PhotoThumbnailProvider

    @StateObject private var thumbnailLoader: LeftBlankHistoryThumbnailLoader

    init(record: LeftBlankPhotoRecord, thumbnailProvider: PhotoThumbnailProvider) {
        self.record = record
        self.thumbnailProvider = thumbnailProvider
        _thumbnailLoader = StateObject(
            wrappedValue: LeftBlankHistoryThumbnailLoader(
                record: record,
                thumbnailProvider: thumbnailProvider
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondary.opacity(0.08))

                if let image = thumbnailLoader.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("Preview unavailable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .frame(height: 180)
            .task {
                thumbnailLoader.loadIfNeeded()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(captureDateText)
                    .font(.headline)

                if let locationLabel = record.locationLabel {
                    Label(locationLabel, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let selectedPrecision = record.selectedPrecision {
                    Text(selectedPrecision.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }

                Text("Left blank \(record.suppressedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(record.assetID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    private var captureDateText: String {
        guard let captureDate = record.captureDate else { return "Capture date unavailable" }
        return captureDate.formatted(date: .abbreviated, time: .shortened)
    }
}
