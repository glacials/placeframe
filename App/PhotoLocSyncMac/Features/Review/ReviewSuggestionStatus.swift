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

struct ReviewSuggestionStatusHelpContent {
    let badgeText: String
    let minuteExplanation: String
    let directionExplanation: String
    let colorExplanation: String

    init(item: ReviewItem) {
        let status = ReviewSuggestionStatusDescriptor(item: item)
        badgeText = status.title

        if let timeDelta = item.timeDelta {
            let minuteOffset = Int((abs(timeDelta) / 60).rounded())
            let minuteNoun = minuteOffset == 1 ? "minute" : "minutes"
            minuteExplanation = "This \(status.title) badge means the matched Google Timeline point is \(minuteOffset) \(minuteNoun) away from the photo's camera timestamp."
            directionExplanation = "The badge uses the absolute gap only. A positive drift means the matched timeline point was after the photo, and a negative drift means it was before."
        } else {
            minuteExplanation = "No usable Google Timeline point was close enough to calculate a minute gap for this photo."
            directionExplanation = "When a timeline point is missing or falls inside a large coverage gap, the app cannot show a minute badge."
        }

        switch item.disposition {
        case .autoSuggested:
            colorExplanation = "Green means the timing was strong enough that the app prefilled the location for you."
        case .ambiguous:
            colorExplanation = "Yellow means a nearby timeline point was found, but the timing was loose enough that you should verify it before applying."
        case .unmatched:
            colorExplanation = "Gray means the timeline did not have a usable nearby match for this photo."
        }
    }
}

struct ReviewSuggestionStatusHelpView: View {
    let item: ReviewItem

    var body: some View {
        let status = ReviewSuggestionStatusDescriptor(item: item)
        let content = ReviewSuggestionStatusHelpContent(item: item)

        VStack(alignment: .leading, spacing: 12) {
            Text("What does this minute badge mean?")
                .font(.headline)

            Label(content.badgeText, systemImage: status.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.tone.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(status.tone.backgroundColor, in: Capsule())

            Text(content.minuteExplanation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Text(content.directionExplanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(content.colorExplanation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Text("Nothing is written until you click Apply.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 320, alignment: .leading)
    }
}
