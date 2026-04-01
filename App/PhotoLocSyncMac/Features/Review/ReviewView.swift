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
                    ReviewGridView(
                        entries: currentDaySection.entries,
                        selectedPhotoIDs: viewModel.selectedPhotoIDs,
                        thumbnailProvider: viewModel.thumbnailProvider,
                        selectPhoto: viewModel.selectPhoto(_:mode:),
                        applyChange: viewModel.applyChange(for:),
                        skipForNow: viewModel.skipForNow(_:),
                        dismissPermanently: viewModel.dismissPermanently(_:),
                        copyLocation: viewModel.copyLocation(for:),
                        pasteLocation: viewModel.pasteLocation(into:),
                        canPasteLocation: viewModel.canPasteLocation(into:),
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
            Text("Review one day at a time. Nothing is written to Apple Photos until you press Apply on a photo or Apply Day.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                summaryBadge(title: "Photos", value: "\(viewModel.summary.totalAssets)")
                summaryBadge(title: "Auto", value: "\(viewModel.summary.autoSuggested)")
                summaryBadge(title: "Ambiguous", value: "\(viewModel.summary.ambiguous)")
                summaryBadge(title: "No match", value: "\(viewModel.summary.unmatched)")
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

            Text("Day \(min(viewModel.currentDayIndex + 1, max(viewModel.daySections.count, 1))) of \(max(viewModel.daySections.count, 1))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await viewModel.applyCurrentDay()
                }
            } label: {
                Label(viewModel.isApplyingCurrentDay ? "Applying..." : "Apply Day", systemImage: "checkmark.circle")
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
            Button("Cancel") {
                viewModel.cancel()
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("Use each photo's buttons to apply it, skip it for this session, or hide it from future reviews.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

    private func summaryBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
