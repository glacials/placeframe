import Combine
import Foundation

enum LocationLabelingPreference: String, CaseIterable, Identifiable, Sendable {
    case localCoordinatesOnly
    case allowAppleGeocoding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localCoordinatesOnly:
            "Keep Coordinates Local"
        case .allowAppleGeocoding:
            "Allow Apple Geocoding"
        }
    }

    var summary: String {
        switch self {
        case .localCoordinatesOnly:
            "Show coordinates only. Imported timeline coordinates stay local unless another feature independently needs network access."
        case .allowAppleGeocoding:
            "Look up rich place labels like street, city, and country names. Apple receives coordinates for those label lookups."
        }
    }
}

@MainActor
final class LocationLabelingSettings: ObservableObject {
    @Published private(set) var choice: LocationLabelingPreference?

    private let defaults: UserDefaults
    private let key: String

    init(
        suiteName: String? = nil,
        key: String = "locationLabelingPreference"
    ) {
        if let suiteName,
           let customDefaults = UserDefaults(suiteName: suiteName) {
            self.defaults = customDefaults
        } else {
            self.defaults = .standard
        }
        self.key = key
        self.choice = defaults.string(forKey: key).flatMap(LocationLabelingPreference.init(rawValue:))
    }

    var needsExplicitChoice: Bool {
        choice == nil
    }

    func effectiveChoice() -> LocationLabelingPreference {
        choice ?? .localCoordinatesOnly
    }

    func setChoice(_ choice: LocationLabelingPreference) {
        self.choice = choice
        defaults.set(choice.rawValue, forKey: key)
    }
}
