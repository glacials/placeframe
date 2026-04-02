import SwiftUI
import PhotoLocSyncAdapters
import PhotoLocSyncCore

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
                        selectLeaveBlank: { viewModel.selectLeaveBlank(for: $0) },
                        setLocationPrecision: { viewModel.selectLocationPrecision($1, for: $0) },
                        applyChange: viewModel.applyChange(for:),
                        applyChanges: viewModel.applyChanges(for:),
                        skipForNow: viewModel.skipForNow(_:),
                        skipPhotosForNow: viewModel.skipPhotosForNow(_:),
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
                        selectedPhotoIDs: viewModel.selectedPhotoIDs,
                        selectionTargets: viewModel.mapSelectionTargets,
                        thumbnailProvider: viewModel.thumbnailProvider
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
        .sheet(isPresented: $viewModel.isShowingCaptureTimeOffsetSheet) {
            ReviewCaptureTimeOffsetSheet(viewModel: viewModel)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review Proposed Locations")
                .font(.largeTitle.bold())
            Text("Choose the place you want to save for each photo, or mark it to stay blank forever. Review one day at a time, then apply the choices you want to keep.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(ReviewSummaryBadge.badges(for: viewModel.summary), id: \.title) { badge in
                    summaryBadge(badge)
                }
            }

            if viewModel.canAdjustCaptureTimeOffset {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        Label(
                            viewModel.captureTimeOffsetBannerTitle,
                            systemImage: viewModel.captureTimeOffsetNeedsAttention
                                ? "exclamationmark.triangle.fill"
                                : "clock.arrow.circlepath"
                        )
                        .font(.headline)
                        .foregroundStyle(viewModel.captureTimeOffsetNeedsAttention ? Color.orange : Color.primary)

                        Spacer()

                        if viewModel.captureTimeOffsetNeedsAttention {
                            Button {
                                viewModel.presentCaptureTimeOffsetSheet()
                            } label: {
                                Label(viewModel.captureTimeOffsetButtonTitle, systemImage: "clock.arrow.circlepath")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        } else {
                            Button {
                                viewModel.presentCaptureTimeOffsetSheet()
                            } label: {
                                Label(viewModel.captureTimeOffsetButtonTitle, systemImage: "clock.arrow.circlepath")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    HStack(alignment: .center, spacing: 10) {
                        ReviewCaptureTimeOffsetAssumptionBadge(
                            title: "Current assumption",
                            value: viewModel.captureTimeOffsetCurrentAssumptionLabel
                        )

                        if let suggestedAssumption = viewModel.captureTimeOffsetSuggestedAssumptionLabel {
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ReviewCaptureTimeOffsetAssumptionBadge(
                                title: "Preview instead",
                                value: suggestedAssumption
                            )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    viewModel.captureTimeOffsetNeedsAttention ? Color.orange.opacity(0.10) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            viewModel.captureTimeOffsetNeedsAttention ? Color.orange.opacity(0.35) : Color.secondary.opacity(0.14),
                            lineWidth: 1
                        )
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

private struct ReviewCaptureTimeOffsetAssumptionBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ReviewCaptureTimeOffsetSheet: View {
    @ObservedObject var viewModel: ReviewViewModel

    private var currentOption: CaptureTimeOffsetOption? {
        viewModel.currentCaptureTimeOffsetOption
    }

    private var selectedOption: CaptureTimeOffsetOption? {
        viewModel.selectedCaptureTimeOffsetOption
    }

    private var currentPreviewEntries: [ReviewSelection] {
        viewModel.captureTimeOffsetPreviewSelections(for: currentOption)
    }

    private var selectedPreviewEntries: [ReviewSelection] {
        viewModel.captureTimeOffsetPreviewSelections(for: selectedOption)
    }

    private var canApplySelectedOption: Bool {
        selectedOption?.offset != currentOption?.offset && viewModel.isApplyingCaptureTimeOffset == false
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.captureTimeOffsetSheetTitle)
                        .font(.largeTitle.bold())

                    Text(viewModel.captureTimeOffsetSheetSubtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button {
                    viewModel.dismissCaptureTimeOffsetSheet()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close camera time preview")
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Try a Different Assumption")
                            .font(.headline)

                        ForEach(viewModel.captureTimeOffsetOptions) { option in
                            Button {
                                viewModel.selectCaptureTimeOffset(option.offset)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text(viewModel.captureTimeOffsetOptionTitle(for: option))
                                            .font(.headline)

                                        if option.offset == currentOption?.offset {
                                            ReviewCaptureTimeOffsetTag(title: "Current")
                                        }

                                        if option.offset == viewModel.recommendedCaptureTimeOffsetOption?.offset {
                                            ReviewCaptureTimeOffsetTag(title: "Recommended")
                                        }
                                    }

                                    Text(viewModel.captureTimeOffsetOptionSummary(for: option))
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)

                                    Text(viewModel.captureTimeOffsetComparisonText(for: option))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.secondary.opacity(0.06))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            option.offset == selectedOption?.offset ? Color.accentColor : Color.secondary.opacity(0.16),
                                            lineWidth: option.offset == selectedOption?.offset ? 2 : 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let selectedOption, selectedOption.offset != currentOption?.offset {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preview")
                                .font(.headline)

                            Text(viewModel.captureTimeOffsetComparisonText(for: selectedOption))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(alignment: .top, spacing: 16) {
                                ReviewCaptureTimeOffsetPreviewPane(
                                    title: viewModel.captureTimeOffsetPreviewTitle(for: currentOption ?? selectedOption),
                                    entries: currentPreviewEntries,
                                    thumbnailProvider: viewModel.thumbnailProvider
                                )

                                ReviewCaptureTimeOffsetPreviewPane(
                                    title: viewModel.captureTimeOffsetPreviewTitle(for: selectedOption),
                                    entries: selectedPreviewEntries,
                                    thumbnailProvider: viewModel.thumbnailProvider
                                )
                            }
                        }
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            HStack(spacing: 16) {
                Button("Close") {
                    viewModel.dismissCaptureTimeOffsetSheet()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("Only this day's matches change when you apply a new assumption.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await viewModel.applySelectedCaptureTimeOffset()
                    }
                } label: {
                    Label(
                        viewModel.captureTimeOffsetApplyButtonTitle(for: selectedOption),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canApplySelectedOption)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .frame(minWidth: 980, minHeight: 720, alignment: .topLeading)
    }
}

private struct ReviewCaptureTimeOffsetPreviewPane: View {
    let title: String
    let entries: [ReviewSelection]
    let thumbnailProvider: PhotoThumbnailProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            ReviewMapView(
                entries: entries,
                selectedPhotoIDs: [],
                selectionTargets: [],
                thumbnailProvider: thumbnailProvider
            )
                .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 280)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct ReviewCaptureTimeOffsetTag: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}
