import SwiftUI

struct ReviewView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @StateObject private var quickLookController = ReviewQuickLookController()
    private let mapPaneLeadingInset: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            dayPager

            if let currentDaySection = viewModel.currentDaySection {
                HSplitView {
                    ReviewListView(
                        entries: currentDaySection.entries,
                        selectedPhotoIDs: viewModel.selectedPhotoIDs,
                        thumbnailProvider: viewModel.thumbnailProvider,
                        selectPhoto: viewModel.selectPhoto(_:mode:),
                        setLocationPrecision: { viewModel.selectLocationPrecision($1, for: $0) },
                        applyChange: viewModel.applyChange(for:),
                        applyChanges: viewModel.applyChanges(for:),
                        skipForNow: viewModel.skipForNow(_:),
                        skipPhotosForNow: viewModel.skipPhotosForNow(_:),
                        dismissPermanently: viewModel.dismissPermanently(_:),
                        dismissPhotosPermanently: viewModel.dismissPhotosPermanently(_:),
                        copyLocation: viewModel.copyLocation(for:),
                        pasteLocation: { viewModel.pasteLocation(into: $0) },
                        canPasteLocation: { viewModel.canPasteLocation(into: $0) },
                        deletePhoto: viewModel.deletePhoto(_:),
                        showOnMap: viewModel.showOnMap(_:),
                        quickLook: { item, sourceView, transitionImage in
                            quickLookController.quickLook(
                                item,
                                using: viewModel.thumbnailProvider,
                                sourceView: sourceView,
                                transitionImage: transitionImage
                            )
                        },
                        captureDateText: viewModel.formattedCaptureDate(for:),
                        timeDeltaText: viewModel.formattedTimeDelta(for:)
                    )
                    .frame(minWidth: 440, idealWidth: 640, maxHeight: .infinity, alignment: .topLeading)

                    ReviewMapView(
                        entries: currentDaySection.entries,
                        selectionTargets: viewModel.mapSelectionTargets
                    )
                        .padding(.leading, mapPaneLeadingInset)
                        .frame(minWidth: 320, idealWidth: 420, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    viewModel.summary.unmatched > 0 ? "No Timeline Matches" : "No Review Items",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(viewModel.emptyStateDescription)
                )
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background {
            selectAllShortcut
        }
        .alert(item: $viewModel.presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review Proposed Locations")
                .font(.largeTitle.bold())
            Text("Each card shows what Apple Photos has now and what Apply will save from the timeline match. Review one day at a time and choose the place you want to save before applying it.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(ReviewSummaryBadge.badges(for: viewModel.summary), id: \.title) { badge in
                    summaryBadge(badge)
                }
            }
        }
    }

    private var dayPager: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.goToPreviousDay()
            } label: {
                Label("Previous Day", systemImage: "chevron.left")
            }
            .disabled(!viewModel.canGoToPreviousDay || viewModel.isApplyingCurrentDay)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentDaySection?.title ?? "No Day Selected")
                    .font(.title3.weight(.semibold))
                Text(viewModel.currentDaySection?.subtitle ?? "0 photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Day \(min(viewModel.currentDayIndex + 1, max(viewModel.daySections.count, 1))) of \(max(viewModel.daySections.count, 1))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let currentDaySection = viewModel.currentDaySection {
                    Text("Apply All writes all \(currentDaySection.entries.count) photos shown for this day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    await viewModel.applyCurrentDay()
                }
            } label: {
                Label(viewModel.isApplyingCurrentDay ? "Applying All..." : "Apply All", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canApplyCurrentDay)

            Button {
                viewModel.goToNextDay()
            } label: {
                Label("Next Day", systemImage: "chevron.right")
            }
            .disabled(!viewModel.canGoToNextDay || viewModel.isApplyingCurrentDay)
        }
    }

    private var footer: some View {
        HStack {
            Button("Back to Import") {
                viewModel.cancel()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    private var selectAllShortcut: some View {
        Button("Select All Photos on Current Day") {
            viewModel.selectAllPhotosOnCurrentDay()
        }
        .keyboardShortcut("a", modifiers: .command)
        .disabled(viewModel.currentDaySection == nil)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func summaryBadge(_ badge: ReviewSummaryBadge) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(badge.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help(badge.helpText)
                    .accessibilityLabel("\(badge.title) description")
            }
            Text("\(badge.value)")
                .font(.title3.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
