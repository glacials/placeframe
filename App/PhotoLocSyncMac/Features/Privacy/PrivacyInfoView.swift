import SwiftUI

struct PrivacySummaryBox: View {
    let showDetails: () -> Void

    var body: some View {
        GroupBox("Privacy") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photo Location Sync keeps your imported timeline data, coordinates, and match decisions on your Mac. The app does not send that location data to external servers.")
                    .font(.headline)

                Text("Matching and coordinate labeling run on this Mac. If you open the review map, Apple map tiles may load, and if a photo is only available from iCloud Photos, Apple Photos may download it so the app can display a preview.")
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

                    Text("Photo Location Sync is designed to keep your imported timeline data and location matching on your Mac. The app does not upload that location data to external APIs.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                GroupBox("What stays on this Mac") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("- Your Google Maps Timeline import is parsed locally.")
                        Text("- Timeline matching and coordinate formatting run locally.")
                        Text("- The app does not use online geocoding, analytics, crash reporting, or other telemetry services.")
                        Text("- Approved location writes happen in your local Photos library first.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("When network access can happen") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Photo Location Sync itself does not upload your timeline data or coordinates.")
                        Text("If you open the review map, Apple map tiles may load for the visible region.")
                        Text("If a requested photo preview is only stored in iCloud Photos, Apple Photos may download that asset so the app can display it.")
                        Text("If you press Apply and iCloud Photos is enabled for your library, Apple may separately sync those approved Photos changes.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("What the app still avoids") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("- The app does not use online geocoding, analytics, crash reporting, or other telemetry services.")
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
