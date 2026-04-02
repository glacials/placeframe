import SwiftUI

struct LocationLabelingSettingsView: View {
    @ObservedObject var settings: LocationLabelingSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Labels")
                        .font(.largeTitle.bold())
                    Text("Choose whether Photo Location Sync should keep labels as coordinates or ask Apple to turn those coordinates into rich place names.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(LocationLabelingPreference.allCases) { preference in
                        LocationLabelingChoiceCard(
                            title: preference.title,
                            summary: preference.summary,
                            isSelected: settings.choice == preference,
                            actionTitle: settings.choice == preference ? "Selected" : "Use This Option"
                        ) {
                            settings.setChoice(preference)
                        }
                    }
                }

                GroupBox("Notes") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("- You can change this at any time.")
                        Text("- The setting affects future timeline imports and any location matching that is re-run later.")
                        Text("- Review map tiles and iCloud-backed photo previews are controlled separately from rich place-label lookups.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 720, minHeight: 440)
    }
}

struct LocationLabelingConsentView: View {
    let choose: (LocationLabelingPreference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose How Place Labels Work")
                    .font(.largeTitle.bold())
                Text("Rich address labels like street, city, and country names require Apple geocoding. That sends the matched coordinates to Apple for lookup. If you prefer, the app can keep labels local and show coordinates instead.")
                    .foregroundStyle(.secondary)
                Text("You can change this later in Settings.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(LocationLabelingPreference.allCases) { preference in
                    LocationLabelingChoiceCard(
                        title: preference.title,
                        summary: preference.summary,
                        isSelected: false,
                        actionTitle: preference == .allowAppleGeocoding ? "Allow Rich Place Labels" : "Keep Coordinates Local"
                    ) {
                        choose(preference)
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 420, alignment: .topLeading)
    }
}

private struct LocationLabelingChoiceCard: View {
    let title: String
    let summary: String
    let isSelected: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)

                        if isSelected {
                            Label("Current", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                    }

                    Text(summary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if isSelected {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
                .disabled(true)
            } else {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.14), lineWidth: isSelected ? 2 : 1)
        }
    }
}
