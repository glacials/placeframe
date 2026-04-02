import SwiftUI

private enum ProcessingPalette {
    static let ink = Color(red: 0.96, green: 0.97, blue: 1)
    static let inkSecondary = Color(red: 0.72, green: 0.77, blue: 0.84)
    static let inkTertiary = Color(red: 0.52, green: 0.58, blue: 0.67)
    static let accent = Color(red: 0.26, green: 0.79, blue: 0.9)
    static let accentSoft = accent.opacity(0.16)
    static let warm = Color(red: 0.98, green: 0.68, blue: 0.36)
    static let success = Color(red: 0.38, green: 0.82, blue: 0.58)

    static let backgroundTop = Color(red: 0.07, green: 0.08, blue: 0.13)
    static let backgroundMiddle = Color(red: 0.03, green: 0.04, blue: 0.07)
    static let backgroundBottom = Color(red: 0.01, green: 0.02, blue: 0.04)

    static let panel = Color(red: 0.08, green: 0.1, blue: 0.15).opacity(0.82)
    static let panelStrong = Color(red: 0.09, green: 0.11, blue: 0.17).opacity(0.94)
    static let panelSoft = Color.white.opacity(0.04)
    static let panelStroke = Color.white.opacity(0.1)
    static let panelStrokeStrong = accent.opacity(0.45)
    static let shadow = Color.black.opacity(0.38)

    static let gridPlaceholder = Color.white.opacity(0.035)
    static let gridPlaceholderStroke = Color.white.opacity(0.055)
    static let gridShadow = Color.black.opacity(0.28)
}

struct ProcessingView: View {
    let viewModel: ProcessingViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ProcessingBackdropView(viewModel: viewModel)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard
                    stageGrid
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(32)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Label(viewModel.eyebrow, systemImage: viewModel.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ProcessingPalette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ProcessingPalette.accentSoft)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(ProcessingPalette.panelStrokeStrong, lineWidth: 1)
                    )

                Spacer(minLength: 20)

                VStack(alignment: .trailing, spacing: 10) {
                    Text("\(Int((viewModel.progressValue * 100).rounded()))% to review")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(ProcessingPalette.inkSecondary)
                    ProgressView(value: viewModel.progressValue)
                        .frame(width: 220)
                        .tint(ProcessingPalette.accent)
                }
            }

            Text(viewModel.title)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(ProcessingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.subtitle)
                .font(.title3)
                .foregroundStyle(ProcessingPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(viewModel.detailPills, id: \.self) { pill in
                    Text(pill)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ProcessingPalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(ProcessingPalette.panelSoft)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(ProcessingPalette.panelStroke, lineWidth: 1)
                        )
                }
            }

            Text(viewModel.assurance)
                .font(.callout)
                .foregroundStyle(ProcessingPalette.inkSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ProcessingPalette.panelStroke, lineWidth: 1)
                )
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ProcessingPalette.panelStrong,
                            ProcessingPalette.panel
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(ProcessingPalette.panelStroke, lineWidth: 1)
        )
        .shadow(color: ProcessingPalette.shadow, radius: 22, y: 16)
    }

    private var stageGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
            ForEach(viewModel.steps) { step in
                ProcessingStageCard(step: step)
            }
        }
    }
}

private struct ProcessingBackdropView: View {
    let viewModel: ProcessingViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ProcessingPalette.backgroundTop,
                    ProcessingPalette.backgroundMiddle,
                    ProcessingPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ProcessingPhotoGridWall(viewModel: viewModel)

            RadialGradient(
                colors: [
                    ProcessingPalette.accent.opacity(0.18),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 360
            )
            .offset(x: 80, y: -40)

            RadialGradient(
                colors: [
                    ProcessingPalette.warm.opacity(0.12),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 320
            )
            .offset(x: -40, y: 40)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.38),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.6),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct ProcessingPhotoGridWall: View {
    let viewModel: ProcessingViewModel

    @State private var animatedVisibleTileCount: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { proxy in
                let tiles = ProcessingPhotoGridLayout.make(in: proxy.size)
                let time = context.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(tiles) { tile in
                        ProcessingPhotoGridTile(
                            tile: tile,
                            animatedVisibleTileCount: animatedVisibleTileCount,
                            time: time
                        )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .onAppear {
            animateVisibleTiles()
        }
        .onChange(of: viewModel.stageKey) { _, _ in
            animateVisibleTiles()
        }
    }

    private func animateVisibleTiles() {
        withAnimation(.easeOut(duration: 2.6)) {
            animatedVisibleTileCount = CGFloat(viewModel.visibleTileCount)
        }
    }
}

private struct ProcessingPhotoGridTile: View {
    let tile: ProcessingPhotoGridTileDescriptor
    let animatedVisibleTileCount: CGFloat
    let time: TimeInterval

    var body: some View {
        let reveal = revealProgress
        let drift = CGFloat(sin((time * 0.22) + Double(tile.id) * 0.37)) * 1.2 * reveal

        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ProcessingPalette.gridPlaceholder)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ProcessingPalette.gridPlaceholderStroke, lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: tile.palette,
                        startPoint: tile.startPoint,
                        endPoint: tile.endPoint
                    )
                )
                .overlay(photoLayers)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .opacity(0.1 + (reveal * 0.5))
                .scaleEffect(0.9 + (reveal * 0.1))
                .blur(radius: (1 - reveal) * 4)
                .shadow(color: ProcessingPalette.gridShadow.opacity(0.8 * reveal), radius: 10, y: 6)
        }
        .frame(width: tile.frame.width, height: tile.frame.height)
        .position(x: tile.frame.midX, y: tile.frame.midY + drift)
    }

    private var photoLayers: some View {
        ZStack {
            Circle()
                .fill(tile.palette.last?.opacity(0.34) ?? Color.clear)
                .frame(width: tile.frame.width * 0.84, height: tile.frame.height * 0.84)
                .blur(radius: 12)
                .offset(tile.glowOffset)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.04),
                    Color.black.opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(Color.black.opacity(0.18))
                .frame(height: tile.frame.height * 0.34)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var revealProgress: CGFloat {
        clamp(
            (animatedVisibleTileCount - CGFloat(tile.revealRank) + 1) / 2.6,
            lower: 0,
            upper: 1
        )
    }
}

private struct ProcessingStageCard: View {
    let step: ProcessingProgressStep

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: step.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(symbolColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.headline)
                    .foregroundStyle(ProcessingPalette.ink)
                Text(step.phase.eyebrow)
                    .font(.subheadline)
                    .foregroundStyle(ProcessingPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .shadow(color: ProcessingPalette.shadow.opacity(0.6), radius: 12, y: 8)
    }

    private var symbolColor: Color {
        switch step.state {
        case .complete:
            ProcessingPalette.success
        case .current:
            ProcessingPalette.accent
        case .upcoming:
            ProcessingPalette.inkTertiary
        }
    }

    private var cardBackground: AnyShapeStyle {
        switch step.state {
        case .complete:
            AnyShapeStyle(ProcessingPalette.panelStrong)
        case .current:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        ProcessingPalette.accentSoft.opacity(0.9),
                        ProcessingPalette.panelStrong
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .upcoming:
            AnyShapeStyle(ProcessingPalette.panel)
        }
    }

    private var cardStroke: Color {
        switch step.state {
        case .complete:
            ProcessingPalette.panelStroke
        case .current:
            ProcessingPalette.panelStrokeStrong
        case .upcoming:
            ProcessingPalette.panelStroke
        }
    }
}

private struct ProcessingPhotoGridTileDescriptor: Identifiable {
    let id: Int
    let frame: CGRect
    let palette: [Color]
    let revealRank: Int
    let glowOffset: CGSize
    let startPoint: UnitPoint
    let endPoint: UnitPoint
}

private enum ProcessingPhotoGridLayout {
    static func make(in size: CGSize) -> [ProcessingPhotoGridTileDescriptor] {
        let gap: CGFloat = 6
        let estimate = max(58, min(94, size.width / 11))
        let columns = max(8, Int((size.width - gap) / (estimate + gap)))
        let tile = floor((size.width - (CGFloat(columns + 1) * gap)) / CGFloat(columns))
        let rows = max(7, Int((size.height - gap) / (tile + gap)))
        let total = columns * rows

        return (0..<total).map { index in
            let row = index / columns
            let column = index % columns
            let originX = gap + CGFloat(column) * (tile + gap)
            let originY = gap + CGFloat(row) * (tile + gap)
            let variant = index % 4

            return ProcessingPhotoGridTileDescriptor(
                id: index,
                frame: CGRect(x: originX, y: originY, width: tile, height: tile),
                palette: palettes[index % palettes.count],
                revealRank: ((index * 37) + (row * 11) + (column * 3)) % total,
                glowOffset: glowOffsets[variant],
                startPoint: variant.isMultiple(of: 2) ? .topLeading : .bottomLeading,
                endPoint: variant.isMultiple(of: 3) ? .bottomTrailing : .topTrailing
            )
        }
    }

    private static let glowOffsets: [CGSize] = [
        CGSize(width: -18, height: -14),
        CGSize(width: 16, height: -10),
        CGSize(width: -10, height: 18),
        CGSize(width: 18, height: 12)
    ]

    private static let palettes: [[Color]] = [
        [
            Color(red: 0.2, green: 0.33, blue: 0.58),
            Color(red: 0.56, green: 0.74, blue: 0.88),
            Color(red: 0.9, green: 0.77, blue: 0.5)
        ],
        [
            Color(red: 0.46, green: 0.2, blue: 0.38),
            Color(red: 0.84, green: 0.52, blue: 0.56),
            Color(red: 0.98, green: 0.76, blue: 0.48)
        ],
        [
            Color(red: 0.18, green: 0.4, blue: 0.34),
            Color(red: 0.46, green: 0.72, blue: 0.52),
            Color(red: 0.88, green: 0.86, blue: 0.54)
        ],
        [
            Color(red: 0.16, green: 0.26, blue: 0.52),
            Color(red: 0.42, green: 0.58, blue: 0.88),
            Color(red: 0.83, green: 0.88, blue: 0.95)
        ],
        [
            Color(red: 0.38, green: 0.19, blue: 0.18),
            Color(red: 0.74, green: 0.42, blue: 0.28),
            Color(red: 0.95, green: 0.72, blue: 0.47)
        ],
        [
            Color(red: 0.18, green: 0.34, blue: 0.44),
            Color(red: 0.36, green: 0.62, blue: 0.68),
            Color(red: 0.72, green: 0.87, blue: 0.82)
        ],
        [
            Color(red: 0.24, green: 0.21, blue: 0.45),
            Color(red: 0.54, green: 0.44, blue: 0.76),
            Color(red: 0.87, green: 0.75, blue: 0.92)
        ],
        [
            Color(red: 0.22, green: 0.19, blue: 0.13),
            Color(red: 0.58, green: 0.45, blue: 0.28),
            Color(red: 0.85, green: 0.82, blue: 0.62)
        ]
    ]
}

private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
}
