import Foundation
import PhotoLocSyncCore

struct LeftBlankPhotoRecord: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let assetID: String
    let captureDate: Date?
    let locationLabel: String?
    let coordinate: GeoCoordinate?
    let selectedPrecision: LocationPrecision?
    let suppressedAt: Date

    init(
        assetID: String,
        captureDate: Date? = nil,
        locationLabel: String? = nil,
        coordinate: GeoCoordinate? = nil,
        selectedPrecision: LocationPrecision? = nil,
        suppressedAt: Date
    ) {
        self.id = assetID
        self.assetID = assetID
        self.captureDate = captureDate
        self.locationLabel = locationLabel
        self.coordinate = coordinate
        self.selectedPrecision = selectedPrecision
        self.suppressedAt = suppressedAt
    }

    init(item: ReviewItem, suppressedAt: Date) {
        let selectedOption = item.selectedPrecision.flatMap { item.locationOption(for: $0) } ?? item.availableLocationOptions.first
        self.init(
            assetID: item.id,
            captureDate: item.asset.creationDate,
            locationLabel: selectedOption?.label ?? item.locationLabel,
            coordinate: selectedOption?.coordinate ?? item.proposedCoordinate,
            selectedPrecision: selectedOption?.precision ?? item.selectedPrecision,
            suppressedAt: suppressedAt
        )
    }
}

protocol ReviewSuppressionStoring: Sendable {
    func filterVisibleItems(_ items: [ReviewItem]) async -> [ReviewItem]
    func suppress(_ item: ReviewItem) async
    func unsuppress(_ assetIDs: [String]) async
    func suppressedRecords() async -> [LeftBlankPhotoRecord]
}

actor ReviewSuppressionStore: ReviewSuppressionStoring {
    private let defaults: UserDefaults
    private let legacyKey: String
    private let recordsKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let clock: @Sendable () -> Date

    init(
        suiteName: String? = nil,
        key: String = "reviewSuppressedAssetIDs",
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        if let suiteName,
           let customDefaults = UserDefaults(suiteName: suiteName) {
            self.defaults = customDefaults
        } else {
            self.defaults = .standard
        }
        self.legacyKey = key
        self.recordsKey = "\(key).records"
        self.clock = clock
    }

    func filterVisibleItems(_ items: [ReviewItem]) async -> [ReviewItem] {
        let suppressedAssetIDs = suppressedIDs()
        guard !suppressedAssetIDs.isEmpty else { return items }

        return items.filter { suppressedAssetIDs.contains($0.id) == false }
    }

    func suppress(_ item: ReviewItem) async {
        var recordsByAssetID = Dictionary(uniqueKeysWithValues: persistedRecords().map { ($0.assetID, $0) })
        recordsByAssetID[item.id] = LeftBlankPhotoRecord(item: item, suppressedAt: clock())
        persist(Array(recordsByAssetID.values))

        var legacySuppressedAssetIDs = legacySuppressedIDs()
        legacySuppressedAssetIDs.insert(item.id)
        defaults.set(Array(legacySuppressedAssetIDs).sorted(), forKey: legacyKey)
    }

    func suppressedRecords() async -> [LeftBlankPhotoRecord] {
        var recordsByAssetID = Dictionary(uniqueKeysWithValues: persistedRecords().map { ($0.assetID, $0) })

        for assetID in legacySuppressedIDs() where recordsByAssetID[assetID] == nil {
            recordsByAssetID[assetID] = LeftBlankPhotoRecord(assetID: assetID, suppressedAt: .distantPast)
        }

        return sortedRecords(Array(recordsByAssetID.values))
    }

    func unsuppress(_ assetIDs: [String]) async {
        guard !assetIDs.isEmpty else { return }

        let assetIDSet = Set(assetIDs)
        let remainingRecords = persistedRecords().filter { assetIDSet.contains($0.assetID) == false }
        persist(remainingRecords)

        var legacySuppressedAssetIDs = legacySuppressedIDs()
        legacySuppressedAssetIDs.subtract(assetIDSet)
        defaults.set(Array(legacySuppressedAssetIDs).sorted(), forKey: legacyKey)
    }

    private func suppressedIDs() -> Set<String> {
        Set(persistedRecords().map(\.assetID)).union(legacySuppressedIDs())
    }

    private func legacySuppressedIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: legacyKey) ?? [])
    }

    private func persistedRecords() -> [LeftBlankPhotoRecord] {
        guard let data = defaults.data(forKey: recordsKey),
              let records = try? decoder.decode([LeftBlankPhotoRecord].self, from: data) else {
            return []
        }

        return sortedRecords(records)
    }

    private func persist(_ records: [LeftBlankPhotoRecord]) {
        let sortedRecords = sortedRecords(records)
        guard let data = try? encoder.encode(sortedRecords) else { return }
        defaults.set(data, forKey: recordsKey)
    }

    private func sortedRecords(_ records: [LeftBlankPhotoRecord]) -> [LeftBlankPhotoRecord] {
        records.sorted { lhs, rhs in
            if lhs.suppressedAt != rhs.suppressedAt {
                return lhs.suppressedAt > rhs.suppressedAt
            }

            let lhsCaptureDate = lhs.captureDate ?? .distantPast
            let rhsCaptureDate = rhs.captureDate ?? .distantPast
            if lhsCaptureDate != rhsCaptureDate {
                return lhsCaptureDate > rhsCaptureDate
            }

            return lhs.assetID < rhs.assetID
        }
    }
}
