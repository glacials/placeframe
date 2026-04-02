import SwiftUI

struct PrivacySummaryBox: View {
    let showDetails: () -> Void

    var body: some View {
        GroupBox("Privacy") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photo Location Sync keeps your imported timeline data and match decisions on your Mac by default. Rich place labels are optional because Apple geocoding needs coordinates for those lookups.")
                    .font(.headline)

                Text("Matching runs on this Mac. Rich place labels are optional and require Apple geocoding if you enable them in Settings, while the review map may load Apple map tiles and iCloud Photos may download preview images when needed.")
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

                    Text("Photo Location Sync is designed to keep your imported timeline data and location matching on your Mac by default. Rich place labels are a separate opt-in because Apple geocoding needs those coordinates for lookup.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                GroupBox("What stays on this Mac") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("- Your Google Maps Timeline import is parsed locally.")
                        Text("- Timeline matching always runs locally.")
                        Text("- If you choose coordinate-only labels, the app keeps location labels local too.")
                        Text("- The app does not use analytics, crash reporting, or other telemetry services.")
                        Text("- Approved location writes happen in your local Photos library first.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("Optional network-backed features") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Photo Location Sync does not upload your imported timeline file or match results.")
                        Text("If you enable rich place labels in Settings, Apple geocoding receives coordinates so it can return address and place names.")
                        Text("If you open the review map, Apple map tiles may load for the visible region.")
                        Text("If a requested photo preview is only stored in iCloud Photos, Apple Photos may download that asset so the app can display it.")
                        Text("If you press Apply and iCloud Photos is enabled for your library, Apple may separately sync those approved Photos changes.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("What the app still avoids") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("- The app does not send your imported timeline file, match results, analytics, or crash reports to third-party services.")
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
