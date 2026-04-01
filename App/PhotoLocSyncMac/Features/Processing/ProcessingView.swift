import SwiftUI

struct ProcessingView: View {
    let viewModel: ProcessingViewModel

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text(viewModel.title)
                .font(.title2.bold())
            Text(viewModel.subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
