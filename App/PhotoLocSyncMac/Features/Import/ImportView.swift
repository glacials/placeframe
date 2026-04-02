import SwiftUI

struct ImportView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ImportViewModel

    var body: some View {
        ZStack {
            ImportViewBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    wizardCard
                    PrivacySummaryBox()
                }
                .padding(32)
                .frame(maxWidth: 940, maxHeight: .infinity, alignment: .top)
            }
        }
        .background(viewModel.isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .fileImporter(
            isPresented: $viewModel.isFileImporterPresented,
            allowedContentTypes: DocumentTypes.timelineImportTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.handleImportResult(.success(url))
                }
            case .failure(let error):
                viewModel.handleImportResult(.failure(error))
            }
        }
        .onDrop(of: ["public.file-url"], isTargeted: $viewModel.isDropTargeted) { providers in
            viewModel.handleDroppedProviders(providers)
        }
        .background {
            keyboardShortcuts
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photo Location Sync")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Bring your Timeline export onto this Mac")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Start with a quick export walkthrough, then upload the JSON once it is ready. Nothing is written to Photos until you review and approve suggestions.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var wizardCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Setup wizard")
                        .font(.headline)
                    Text("Step \(viewModel.currentStep.rawValue + 1) of \(ImportWizardStep.allCases.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                ImportWizardProgressView(currentStep: viewModel.currentStep)
            }

            ZStack {
                switch viewModel.currentStep {
                case .export:
                    ExportWizardStepView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .upload:
                    UploadWizardStepView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(
                    viewModel.isDropTargeted ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.45),
                    style: StrokeStyle(lineWidth: viewModel.isDropTargeted ? 2 : 1)
                )
        }
        .shadow(color: Color.black.opacity(0.08), radius: 28, x: 0, y: 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: viewModel.currentStep)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isDropTargeted)
    }

    private var keyboardShortcuts: some View {
        VStack {
            Button("Import Timeline") {
                viewModel.presentImporter()
            }
            .keyboardShortcut("i", modifiers: [])
            .disabled(appState.isShowingKeyboardShortcuts || viewModel.isFileImporterPresented)

            Button("Open Timeline Importer") {
                viewModel.presentImporter()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(appState.isShowingKeyboardShortcuts || viewModel.isFileImporterPresented)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}

private extension ImportWizardStep {
    var shortTitle: String {
        switch self {
        case .export:
            return "Export"
        case .upload:
            return "Upload"
        }
    }
}

private struct ImportWizardProgressView: View {
    let currentStep: ImportWizardStep

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ImportWizardStep.allCases) { step in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.14))
                            .frame(width: 24, height: 24)
                        Text("\(step.rawValue + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(step == currentStep ? Color.white : Color.primary)
                    }

                    Text(step.shortTitle)
                        .font(.subheadline.weight(step == currentStep ? .semibold : .regular))
                        .foregroundStyle(step == currentStep ? Color.primary : Color.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    step == currentStep ? Color.white.opacity(0.82) : Color.white.opacity(0.42),
                    in: Capsule()
                )
            }
        }
    }
}

private struct ExportWizardStepView: View {
    @ObservedObject var viewModel: ImportViewModel

    var body: some View {
        ImportWizardStepLayout {
            ExportTimelineArtwork()
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                stepHeader(
                    eyebrow: "Step 1",
                    title: "Export your Timeline from Google Maps",
                    subtitle: "This is the only part that happens on your iPhone. Once the JSON is on your Mac, the rest of the flow stays here."
                )

                VStack(alignment: .leading, spacing: 12) {
                    WizardDetailRow(
                        systemImage: "iphone",
                        title: "Open Google Maps and go to Your Timeline",
                        detail: "Use the iPhone that already has your location history."
                    )
                    WizardDetailRow(
                        systemImage: "square.and.arrow.up",
                        title: "Choose Export Timeline data",
                        detail: "Google Maps will create a JSON export for you."
                    )
                    WizardDetailRow(
                        systemImage: "laptopcomputer.and.arrow.down",
                        title: "Move that export onto this Mac",
                        detail: "AirDrop it, save it to Downloads, or place it anywhere easy to find."
                    )
                }

                Text("The file you want is usually named `location-history.json`.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("I’ve moved the export to this Mac") {
                    viewModel.advanceToUpload()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                WizardSkipButton {
                    viewModel.skipCurrentStep()
                }
            }
        }
    }

    private func stepHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct UploadWizardStepView: View {
    @ObservedObject var viewModel: ImportViewModel

    var body: some View {
        ImportWizardStepLayout {
            UploadTimelineArtwork()
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                stepHeader(
                    eyebrow: "Step 2",
                    title: "Upload `location-history.json`",
                    subtitle: "Choose the export from Finder or drag it straight onto this window. The file is read locally and turned into review suggestions before anything can be written."
                )

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Ready when you are")
                            .font(.headline)
                    }

                    Text("Browse to the file you just moved over, or drop it onto the upload target below.")
                        .foregroundStyle(.secondary)
                }

                UploadDropTarget(
                    isTargeted: viewModel.isDropTargeted,
                    openImporter: viewModel.presentImporter
                )

                WizardSkipButton {
                    viewModel.skipCurrentStep()
                }
            }
        }
    }

    private func stepHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ImportWizardStepLayout<Artwork: View, Content: View>: View {
    let artwork: Artwork
    let content: Content

    init(@ViewBuilder artwork: () -> Artwork, @ViewBuilder content: () -> Content) {
        self.artwork = artwork()
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 28) {
                artwork
                    .frame(width: 320, height: 250)

                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 24) {
                artwork
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)

                content
            }
        }
    }
}

private struct WizardDetailRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct UploadDropTarget: View {
    let isTargeted: Bool
    let openImporter: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                .font(.system(size: 36))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.primary)

            Button("Choose location-history.json") {
                openImporter()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)

            Text("or drag the file anywhere onto this card")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.5))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.28),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [8, 6])
                )
        }
    }
}

private struct WizardSkipButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("I already have my `location-history.json` file")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct ImportViewBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.98, blue: 0.96),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.95, green: 0.94, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: 360, height: 360)
                .blur(radius: 60)
                .offset(x: -260, y: -220)

            Circle()
                .fill(Color.orange.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 260, y: -60)

            Circle()
                .fill(Color.teal.opacity(0.1))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: 220, y: 220)
        }
        .ignoresSafeArea()
    }
}

private struct ExportTimelineArtwork: View {
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let travel = CGFloat(sin(time * 1.6)) * 18
            let bob = CGFloat(cos(time * 1.2)) * 6
            let pulse = 0.92 + CGFloat((sin(time * 2.2) + 1) * 0.06)

            ZStack {
                artworkBackground

                HStack(alignment: .bottom, spacing: 22) {
                    TimelinePhone()
                        .offset(y: 6)

                    VStack(spacing: 12) {
                        Image(systemName: "arrow.right")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.accentColor.opacity(0.7))
                            .offset(x: 4, y: bob)

                        FloatingTimelineFile()
                            .scaleEffect(pulse)
                            .offset(x: travel, y: -18 + bob)
                    }

                    TimelineLaptop()
                }
            }
        }
    }

    private var artworkBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.82),
                        Color.accentColor.opacity(0.08),
                        Color.orange.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            }
    }
}

private struct UploadTimelineArtwork: View {
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let drop = CGFloat((sin(time * 2.0) + 1) / 2)
            let fileOffset = -46 + (drop * 18)
            let arrowScale = 0.92 + (drop * 0.18)
            let glowOpacity = 0.1 + (drop * 0.12)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.84),
                                Color.teal.opacity(0.08),
                                Color.accentColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                    }

                Circle()
                    .fill(Color.accentColor.opacity(glowOpacity))
                    .frame(width: 170, height: 170)
                    .blur(radius: 26)

                VStack(spacing: 12) {
                    FloatingTimelineFile()
                        .offset(y: fileOffset)

                    Image(systemName: "arrow.down")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                        .scaleEffect(arrowScale)

                    UploadTray()
                }
            }
        }
    }
}

private struct TimelinePhone: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color(red: 0.12, green: 0.14, blue: 0.2))
            .frame(width: 116, height: 206)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .padding(7)
                    .overlay {
                        VStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.black.opacity(0.12))
                                .frame(width: 34, height: 5)
                                .padding(.top, 10)

                            TimelineMapCard()
                                .padding(.horizontal, 10)

                            Spacer(minLength: 0)
                        }
                    }
            }
    }
}

private struct TimelineMapCard: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.9, green: 0.95, blue: 0.92))

                Path { path in
                    path.move(to: CGPoint(x: 18, y: geometry.size.height - 26))
                    path.addCurve(
                        to: CGPoint(x: geometry.size.width - 18, y: 28),
                        control1: CGPoint(x: geometry.size.width * 0.32, y: geometry.size.height * 0.62),
                        control2: CGPoint(x: geometry.size.width * 0.65, y: geometry.size.height * 0.26)
                    )
                }
                .stroke(Color.accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

                Circle()
                    .fill(Color.orange)
                    .frame(width: 16, height: 16)
                    .offset(x: -26, y: 28)

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                    .offset(x: 30, y: -26)
            }
        }
        .frame(height: 138)
    }
}

private struct TimelineLaptop: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.18, green: 0.22, blue: 0.3))
                .frame(width: 140, height: 98)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .padding(7)
                        .overlay {
                            VStack(spacing: 10) {
                                HStack(spacing: 6) {
                                    Circle().fill(Color.red.opacity(0.65)).frame(width: 7, height: 7)
                                    Circle().fill(Color.orange.opacity(0.75)).frame(width: 7, height: 7)
                                    Circle().fill(Color.green.opacity(0.75)).frame(width: 7, height: 7)
                                    Spacer()
                                }
                                .padding(.top, 12)
                                .padding(.horizontal, 12)

                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.16))
                                    .overlay {
                                        Image(systemName: "tray.and.arrow.down.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 12)
                            }
                        }
                }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.84, green: 0.87, blue: 0.91))
                .frame(width: 176, height: 16)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                }
                .offset(y: -2)
        }
    }
}

private struct FloatingTimelineFile: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(Color.accentColor)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("location-history.json")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("Timeline export")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 6)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 88, height: 6)
        }
        .padding(14)
        .frame(width: 164, alignment: .leading)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

private struct UploadTray: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.18, green: 0.22, blue: 0.3))
                .frame(width: 170, height: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.84, green: 0.87, blue: 0.91))
                .frame(width: 116, height: 18)
                .offset(y: -2)
        }
    }
}
