import PhotoLocSyncCore
import SwiftUI

struct ApplyResultView: View {
    let summary: ApplySummary
    let onStartOver: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Apply Complete")
                .font(.largeTitle.bold())

            HStack(spacing: 16) {
                metric(title: "Updated", value: summary.updated, color: .green)
                metric(title: "Skipped", value: summary.skipped, color: .secondary)
                metric(title: "Failed", value: summary.failed, color: .red)
            }

            if !summary.failures.isEmpty {
                GroupBox("Failures") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(summary.failures) { failure in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(failure.assetID)
                                    .font(.headline)
                                Text(failure.message ?? "Unknown failure")
                                    .foregroundStyle(.secondary)
                            }
                            if failure.id != summary.failures.last?.id {
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button("Start Over") {
                onStartOver()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(32)
    }

    private func metric(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text("\(value)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}
