import SwiftUI

struct ImportView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ImportViewModel

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            wizardCard
                .padding(24)
        }
        .background(viewModel.isDropTargeted ? Color.accentColor.opacity(0.04) : Color.clear)
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

    private var wizardCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                Text("Photo Location Sync")
                    .font(.headline)

                Spacer(minLength: 0)

                Text(viewModel.stepCounterText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.currentStep.prompt)
                .font(.system(.title3, design: .rounded, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Back") {
                    viewModel.goBack()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.canGoBack == false)

                Button("Next") {
                    viewModel.handlePrimaryAction()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(maxWidth: 520, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    viewModel.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.16),
                    lineWidth: viewModel.isDropTargeted ? 2 : 1
                )
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.14), value: viewModel.currentStep)
        .animation(.easeInOut(duration: 0.14), value: viewModel.isDropTargeted)
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
