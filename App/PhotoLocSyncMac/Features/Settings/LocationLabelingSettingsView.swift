import SwiftUI

struct LocationLabelingSettingsView: View {
    @ObservedObject var settings: LocationLabelingSettings

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: richPlaceLabelsBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rich Place Labels")
                        .font(.headline)
                    Text("Use Apple to turn coordinates into place names. Apple receives anonymized coordinates for those lookups.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 160, alignment: .topLeading)
    }

    private var richPlaceLabelsBinding: Binding<Bool> {
        Binding(
            get: {
                settings.effectiveChoice() == .allowAppleGeocoding
            },
            set: { isEnabled in
                settings.setChoice(isEnabled ? .allowAppleGeocoding : .localCoordinatesOnly)
            }
        )
    }
}

struct LocationLabelingConsentView: View {
    let choose: (LocationLabelingPreference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Enable Rich Place Labels?")
                    .font(.largeTitle.bold())
                Text("Should Photo Location Sync display human-readable place names? This requires sending anonymized coordinates to the Apple Maps API.")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Example") {
                HStack(spacing: 12) {
                    Text("37.33, -122.03")
                        .font(.system(.body, design: .monospaced))
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Text("Cupertino, California")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(LocationLabelingPreference.allCases) { preference in
                    LocationLabelingChoiceCard(
                        title: preference.title,
                        summary: preference.summary,
                        isSelected: false,
                        actionTitle: preference == .allowAppleGeocoding ? "Enable Rich Labels" : "Keep Coordinates Local"
                    ) {
                        choose(preference)
                    }
                }
            }

            Text("You can change this later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
