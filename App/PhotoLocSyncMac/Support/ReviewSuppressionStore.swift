import Foundation
import PhotoLocSyncCore

protocol ReviewSuppressionStoring: Sendable {
    func filterVisibleItems(_ items: [ReviewItem]) async -> [ReviewItem]
    func suppress(_ assetID: String) async
}

actor ReviewSuppressionStore: ReviewSuppressionStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        suiteName: String? = nil,
        key: String = "reviewSuppressedAssetIDs"
    ) {
        if let suiteName,
           let customDefaults = UserDefaults(suiteName: suiteName) {
            self.defaults = customDefaults
        } else {
            self.defaults = .standard
        }
        self.key = key
    }

    func filterVisibleItems(_ items: [ReviewItem]) async -> [ReviewItem] {
        let suppressedAssetIDs = suppressedIDs()
        guard !suppressedAssetIDs.isEmpty else { return items }

        return items.filter { suppressedAssetIDs.contains($0.id) == false }
    }

    func suppress(_ assetID: String) async {
        var suppressedAssetIDs = suppressedIDs()
        suppressedAssetIDs.insert(assetID)
        defaults.set(Array(suppressedAssetIDs).sorted(), forKey: key)
    }

    private func suppressedIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }
}
