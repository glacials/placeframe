import PhotoLocSyncCore
import SwiftUI

enum ReviewSuggestionStatusTone {
    case green
    case orange
    case secondary

    var color: Color {
        switch self {
        case .green: .green
        case .orange: .orange
        case .secondary: .secondary
        }
    }

    var backgroundColor: Color {
        color.opacity(0.12)
    }
}

extension MatchDisposition {
    var reviewStatusTitle: String {
        switch self {
        case .autoSuggested: "Auto-suggested"
        case .ambiguous: "Needs review"
        case .unmatched: "No match"
        }
    }

    var reviewStatusSymbolName: String {
        switch self {
        case .autoSuggested: "checkmark.seal"
        case .ambiguous: "questionmark.circle"
        case .unmatched: "xmark.circle"
        }
    }

    var reviewStatusTone: ReviewSuggestionStatusTone {
        switch self {
        case .autoSuggested: .green
        case .ambiguous: .orange
        case .unmatched: .secondary
        }
    }

    var reviewStatusLegendDescription: String {
        switch self {
        case .autoSuggested:
            "Strong enough time match that the app prefilled the location. Usually within 15 minutes, or inside a stationary visit."
        case .ambiguous:
            "A nearby timeline match was found, but it was loose enough that you should double-check it. Usually within 60 minutes."
        case .unmatched:
            "No nearby timeline evidence was usable, or there was a large gap in timeline coverage, so the photo is left out of review."
        }
    }
}

struct ReviewSuggestionStatusDescriptor {
    let title: String
    let symbolName: String
    let tone: ReviewSuggestionStatusTone
    let shortDescription: String

    init(item: ReviewItem) {
        title = Self.title(for: item)
        tone = item.disposition.reviewStatusTone

        switch item.disposition {
        case .autoSuggested:
            symbolName = item.confidence == .excellent ? "checkmark.seal.fill" : item.disposition.reviewStatusSymbolName
            switch item.confidence {
            case .excellent:
                shortDescription = "Strong enough time match that the app prefilled this location."
            case .acceptable:
                shortDescription = "Close enough in time that the app prefilled this location."
            case .maybe:
                shortDescription = "The app still found enough timeline evidence to prefill this location."
            case .rejected:
                shortDescription = "The app found enough timeline evidence to prefill this location."
            }
        case .ambiguous:
            symbolName = item.disposition.reviewStatusSymbolName
            shortDescription = "A nearby timeline match was found, but it was loose enough that you should verify it before writing."
        case .unmatched:
            symbolName = item.disposition.reviewStatusSymbolName
            shortDescription = "The timeline did not have a usable match for this photo."
        }
    }

    private static func title(for item: ReviewItem) -> String {
        guard let timeDelta = item.timeDelta else {
            return item.disposition.reviewStatusTitle
        }

        let minuteOffset = Int((abs(timeDelta) / 60).rounded())
        return "\(minuteOffset) min"
    }
}

struct ReviewSuggestionStatusHelpView: View {
    let currentDisposition: MatchDisposition

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why this color?")
                .font(.headline)

            Text("The badge shows how many minutes the Google Timeline suggestion differs from the camera timestamp. Its color explains whether that timing was strong enough to prefill the location or loose enough that you should double-check it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(MatchDisposition.allCases, id: \.self) { disposition in
                HStack(alignment: .top, spacing: 10) {
                    Text(disposition.reviewStatusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(disposition.reviewStatusTone.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(disposition.reviewStatusTone.backgroundColor, in: Capsule())

                    Text(disposition.reviewStatusLegendDescription)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                    if disposition == currentDisposition {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
            }

            Text("Nothing is written until you click This Looks Correct.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 320, alignment: .leading)
    }
}
