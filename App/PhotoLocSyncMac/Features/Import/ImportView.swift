import SwiftUI

struct ImportView: View {
    @ObservedObject var viewModel: ImportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photo Location Sync")
                    .font(.largeTitle.bold())
                Text("Import a Google Maps Timeline export, match it to Apple Photos that are missing GPS metadata, review the suggestions, then write only after explicit confirmation.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            GroupBox("How to export from Google Maps") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. On your iPhone, open Google Maps.")
                    Text("2. Open Your Timeline.")
                    Text("3. Export Timeline data.")
                    Text("4. AirDrop the file to your Mac or save it somewhere accessible.")
                    Text("5. Import the exported location-history.json here.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 16) {
                Button("Import Timeline Export") {
                    viewModel.presentImporter()
                }
                .buttonStyle(.borderedProminent)

                Text("You can also drag a valid location-history.json file onto this window.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(32)
        .background(viewModel.isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(viewModel.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(12)
        }
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
    }
}
