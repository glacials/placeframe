import SwiftUI

struct PrivacySummaryBox: View {
    let showDetails: () -> Void

    var body: some View {
        GroupBox("Privacy") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photo Location Sync is local-only by default. The app does not send your timeline file, coordinates, thumbnails, or other personal data to any external server.")
                    .font(.headline)

                Text("Matching, coordinate labeling, and the review plot all run on this Mac. If a photo is only available from iCloud, the app leaves its preview unavailable instead of fetching it over the network.")
                    .foregroundStyle(.secondary)

                Text("When you click Apply, the app writes the approved metadata into Apple Photos locally. If you use iCloud Photos, Apple may sync those approved library changes outside this app.")
                    .foregroundStyle(.secondary)

                Button("View Privacy Details") {
                    showDetails()
                }
                .buttonStyle(.link)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }
}

struct PrivacyInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Privacy & Data Handling")
                        .font(.largeTitle.bold())

                    Text("Photo Location Sync is designed to keep your timeline data and photo metadata on your Mac. The app does not perform outbound API calls with your personal data.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                GroupBox("What stays on this Mac") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("- Your Google Maps Timeline import is parsed locally.")
                        Text("- Timeline matching, coordinate formatting, and review plotting run locally.")
                        Text("- Photo previews use only locally available Photos assets.")
                        Text("- The app does not use online geocoding, map tiles, analytics, crash reporting, or other telemetry services.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("When data can leave your Mac") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Photo Location Sync itself does not upload your data.")
                        Text("If you press Apply, the app writes approved location metadata into Apple Photos on-device.")
                        Text("If iCloud Photos is enabled for your library, Apple may separately sync those approved Photos changes. That sync is outside Photo Location Sync.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
