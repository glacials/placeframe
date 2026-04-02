import SwiftUI

private enum ProcessingPalette {
    static let ink = Color(red: 0.11, green: 0.16, blue: 0.22)
    static let inkSecondary = Color(red: 0.3, green: 0.37, blue: 0.44)
    static let inkTertiary = Color(red: 0.45, green: 0.51, blue: 0.58)
    static let teal = Color(red: 0.07, green: 0.55, blue: 0.59)
    static let tealSoft = Color(red: 0.42, green: 0.74, blue: 0.76)
    static let warm = Color(red: 0.94, green: 0.56, blue: 0.28)
    static let backgroundTop = Color(red: 0.84, green: 0.9, blue: 0.98)
    static let backgroundCenter = Color(red: 0.82, green: 0.93, blue: 0.94)
    static let backgroundBottom = Color(red: 0.95, green: 0.9, blue: 0.82)
    static let glass = Color(red: 0.97, green: 0.98, blue: 1).opacity(0.84)
    static let glassStrong = Color(red: 0.98, green: 0.99, blue: 1).opacity(0.94)
    static let glassCool = Color(red: 0.91, green: 0.98, blue: 0.98).opacity(0.94)
    static let glassWarm = Color(red: 1, green: 0.96, blue: 0.9).opacity(0.96)
    static let heroTop = Color(red: 0.96, green: 0.98, blue: 1).opacity(0.9)
    static let heroBottom = Color(red: 0.92, green: 0.96, blue: 0.95).opacity(0.94)
    static let mapTop = Color(red: 0.87, green: 0.96, blue: 0.97)
    static let mapBottom = Color(red: 0.83, green: 0.93, blue: 0.94)
    static let tileShade = Color(red: 1, green: 1, blue: 1).opacity(0.32)
    static let stroke = Color(red: 0.42, green: 0.59, blue: 0.66).opacity(0.26)
    static let strongStroke = Color(red: 0.22, green: 0.52, blue: 0.59).opacity(0.32)
    static let shadow = Color.black.opacity(0.1)
}

struct ProcessingView: View {
    let viewModel: ProcessingViewModel

    var body: some View {
        ZStack {
            ProcessingBackdropView()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    ProcessingHeroScene(viewModel: viewModel)
                        .frame(height: 360)
                    stageGrid
                    trustGrid
                }
                .frame(maxWidth: 1_020)
                .padding(36)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Label(viewModel.eyebrow, systemImage: viewModel.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ProcessingPalette.inkSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(ProcessingPalette.glassWarm)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(ProcessingPalette.stroke, lineWidth: 1)
                        )

                    Text(viewModel.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ProcessingPalette.ink)

                    Text(viewModel.subtitle)
                        .font(.title3)
                        .foregroundStyle(ProcessingPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 20)

                VStack(alignment: .trailing, spacing: 10) {
                    Text("\(Int((viewModel.progressValue * 100).rounded()))% to review")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(ProcessingPalette.inkSecondary)
                    ProgressView(value: viewModel.progressValue)
                        .frame(width: 220)
                        .tint(ProcessingPalette.teal)
                }
                .padding(.top, 4)
            }

            Text(viewModel.assurance)
                .font(.headline)
                .foregroundStyle(ProcessingPalette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(ProcessingPalette.glassStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(ProcessingPalette.stroke, lineWidth: 1)
                )
                .shadow(color: ProcessingPalette.shadow.opacity(0.7), radius: 18, y: 10)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                ForEach(viewModel.detailPills, id: \.self) { pill in
                    Text(pill)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ProcessingPalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(ProcessingPalette.glassStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(ProcessingPalette.stroke, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var stageGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
            ForEach(viewModel.steps) { step in
                ProcessingStageCard(step: step)
            }
        }
    }

    private var trustGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
            ProcessingTrustCard(
                title: "Real stage reporting",
                subtitle: "The animation changes only when the actual pipeline moves to the next phase.",
                systemImage: "waveform.path.ecg.rectangle"
            )
            ProcessingTrustCard(
                title: "Read-only until review",
                subtitle: "This pass prepares suggestions and local review context. It does not write metadata yet.",
                systemImage: "lock.shield.fill"
            )
            ProcessingTrustCard(
                title: "Manual approval stays in front",
                subtitle: "The next screen is the review workspace, where you stay in control of every change.",
                systemImage: "checkmark.shield"
            )
        }
    }
}

private struct ProcessingBackdropView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ProcessingPalette.backgroundTop,
                    ProcessingPalette.backgroundCenter,
                    ProcessingPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(ProcessingPalette.warm.opacity(0.24))
                .frame(width: 380, height: 380)
                .blur(radius: 36)
                .offset(x: -280, y: -220)

            Circle()
                .fill(ProcessingPalette.teal.opacity(0.2))
                .frame(width: 420, height: 420)
                .blur(radius: 42)
                .offset(x: 300, y: 200)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(ProcessingPalette.glass.opacity(0.6))
                .frame(width: 520, height: 280)
                .rotationEffect(.degrees(-12))
                .offset(x: 240, y: -180)
        }
        .ignoresSafeArea()
    }
}

private struct ProcessingHeroScene: View {
    let viewModel: ProcessingViewModel

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { proxy in
                let size = proxy.size
                let time = context.date.timeIntervalSinceReferenceDate

                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ProcessingPalette.heroTop,
                                    ProcessingPalette.heroBottom
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(ProcessingPalette.stroke, lineWidth: 1)

                    ProcessingMapScene(viewModel: viewModel, time: time)
                        .frame(width: size.width * 0.36, height: size.height * 0.76)
                        .position(x: size.width * 0.75, y: size.height * 0.5)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.11, green: 0.62, blue: 0.65).opacity(0.12),
                                    Color(red: 0.98, green: 0.73, blue: 0.45).opacity(0.26),
                                    Color(red: 0.11, green: 0.62, blue: 0.65).opacity(0.12)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: size.width * 0.3, height: 12)
                        .position(x: size.width * 0.5, y: size.height * 0.56)
                        .opacity(0.2 + (viewModel.tilePlacementProgress * 0.65))

                    ForEach(ProcessingHeroLayout.tiles) { tile in
                        ProcessingPhotoTile(
                            tile: tile,
                            viewModel: viewModel,
                            containerSize: size,
                            time: time
                        )
                    }

                    sceneLabels(size: size)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: ProcessingPalette.shadow, radius: 28, y: 18)
            }
        }
    }

    @ViewBuilder
    private func sceneLabels(size: CGSize) -> some View {
        Text(viewModel.contactSheetHeadline)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ProcessingPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(ProcessingPalette.glassWarm)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(ProcessingPalette.stroke, lineWidth: 1)
            )
            .position(x: size.width * 0.18, y: size.height * 0.11)

        Text(viewModel.mapHeadline)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ProcessingPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(ProcessingPalette.glassCool)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(ProcessingPalette.stroke, lineWidth: 1)
            )
            .position(x: size.width * 0.73, y: size.height * 0.11)
    }
}

private struct ProcessingMapScene: View {
    let viewModel: ProcessingViewModel
    let time: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ProcessingPalette.mapTop,
                                ProcessingPalette.mapBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(ProcessingPalette.stroke, lineWidth: 1)
                    )

                ProcessingMapGrid()
                    .stroke(ProcessingPalette.teal.opacity(0.22), lineWidth: 1)
                    .padding(18)

                ProcessingRouteShape()
                    .trim(from: 0, to: viewModel.routeProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                ProcessingPalette.warm,
                                ProcessingPalette.teal
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
                    .padding(28)

                ForEach(Array(ProcessingHeroLayout.pins.enumerated()), id: \.offset) { index, point in
                    let isVisible = index < viewModel.visiblePinCount
                    let phase = pulse(for: index)

                    ZStack {
                        Circle()
                            .stroke(ProcessingPalette.teal.opacity(0.22), lineWidth: 2)
                            .frame(width: 22 + (phase * 24), height: 22 + (phase * 24))
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(
                                ProcessingPalette.warm,
                                Color.white
                            )
                            .shadow(color: ProcessingPalette.shadow.opacity(0.8), radius: 6, y: 3)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.65)
                    .position(x: point.x * size.width, y: point.y * size.height)
                }

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ProcessingPalette.glassStrong)
                    .frame(width: size.width * 0.62, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(ProcessingPalette.stroke, lineWidth: 1)
                    )
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.symbolName)
                                .foregroundStyle(ProcessingPalette.teal)
                            Text(viewModel.mapHeadline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ProcessingPalette.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                    )
                    .position(x: size.width * 0.5, y: size.height * 0.12)
            }
            .opacity(0.3 + (viewModel.mapRevealProgress * 0.7))
            .scaleEffect(0.9 + (viewModel.mapRevealProgress * 0.1))
            .shadow(color: ProcessingPalette.shadow, radius: 18, y: 12)
        }
    }

    private func pulse(for index: Int) -> CGFloat {
        guard index < viewModel.visiblePinCount else { return 0 }
        let phase = (sin((time * 1.3) + Double(index)) + 1) / 2
        return CGFloat(phase)
    }
}

private struct ProcessingPhotoTile: View {
    let tile: ProcessingPhotoTileLayout
    let viewModel: ProcessingViewModel
    let containerSize: CGSize
    let time: TimeInterval

    var body: some View {
        let visibility = tileVisibility
        let migration = tileMigration
        let bob = CGFloat(sin((time * 0.9) + Double(tile.id))) * 5 * (1 - migration)
        let position = CGPoint(
            x: mix(tile.start.x, tile.end.x, migration) * containerSize.width,
            y: (mix(tile.start.y, tile.end.y, migration) * containerSize.height) + bob
        )
        let width = tile.size.width * containerSize.width
        let height = tile.size.height * containerSize.height

        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tile.color.opacity(0.98),
                        ProcessingPalette.tileShade
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(tileOverlay(migration: migration))
            .frame(width: width, height: height)
            .scaleEffect(0.8 + (visibility * 0.2))
            .rotationEffect(.degrees(mix(tile.rotation, tile.rotation * 0.2, migration)))
            .opacity(max(0.06, visibility))
            .shadow(color: ProcessingPalette.shadow.opacity(0.9), radius: 12, y: 8)
            .position(position)
    }

    @ViewBuilder
    private func tileOverlay(migration: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.white.opacity(0.56), lineWidth: 1)
            .overlay(
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: migration > 0.55 ? "mappin.and.ellipse" : "photo.on.rectangle.angled")
                            .font(.headline.weight(.semibold))
                        Spacer(minLength: 0)
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 16, height: 16)
                    }

                    Spacer(minLength: 0)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.46))
                        .frame(width: 46, height: 8)
                }
                .foregroundStyle(ProcessingPalette.ink.opacity(0.78))
                .padding(14)
            )
    }

    private var tileVisibility: CGFloat {
        if tile.id < viewModel.visibleTileCount {
            return 1
        }

        let overflow = CGFloat(tile.id - viewModel.visibleTileCount + 1)
        return max(0, 0.25 - (overflow * 0.08))
    }

    private var tileMigration: CGFloat {
        let stagger = CGFloat(tile.id) * 0.06
        return clamp(CGFloat(viewModel.tilePlacementProgress) - stagger, lower: 0, upper: 1)
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
    }

    private var symbolColor: Color {
        switch step.state {
        case .complete:
            Color(red: 0.08, green: 0.52, blue: 0.35)
        case .current:
            ProcessingPalette.teal
        case .upcoming:
            ProcessingPalette.inkTertiary
        }
    }

    private var cardBackground: AnyShapeStyle {
        switch step.state {
        case .complete:
            AnyShapeStyle(ProcessingPalette.glassStrong)
        case .current:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        ProcessingPalette.glassCool,
                        ProcessingPalette.glassStrong
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .upcoming:
            AnyShapeStyle(ProcessingPalette.glass.opacity(0.78))
        }
    }

    private var cardStroke: Color {
        switch step.state {
        case .complete:
            ProcessingPalette.stroke
        case .current:
            ProcessingPalette.strongStroke
        case .upcoming:
            ProcessingPalette.stroke.opacity(0.8)
        }
    }
}

private struct ProcessingTrustCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ProcessingPalette.warm)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ProcessingPalette.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(ProcessingPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ProcessingPalette.glassStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ProcessingPalette.stroke, lineWidth: 1)
        )
        .shadow(color: ProcessingPalette.shadow.opacity(0.55), radius: 14, y: 8)
    }
}

private struct ProcessingMapGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        for fraction in stride(from: 0.18, through: 0.82, by: 0.16) {
            let y = rect.minY + (rect.height * fraction)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: y),
                control1: CGPoint(x: rect.minX + (rect.width * 0.22), y: y - 10),
                control2: CGPoint(x: rect.maxX - (rect.width * 0.22), y: y + 10)
            )
        }

        for fraction in stride(from: 0.18, through: 0.82, by: 0.16) {
            let x = rect.minX + (rect.width * fraction)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addCurve(
                to: CGPoint(x: x, y: rect.maxY),
                control1: CGPoint(x: x - 8, y: rect.minY + (rect.height * 0.24)),
                control2: CGPoint(x: x + 8, y: rect.maxY - (rect.height * 0.24))
            )
        }

        return path
    }
}

private struct ProcessingRouteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let points = [
            CGPoint(x: 0.16, y: 0.76),
            CGPoint(x: 0.29, y: 0.58),
            CGPoint(x: 0.36, y: 0.65),
            CGPoint(x: 0.5, y: 0.35),
            CGPoint(x: 0.64, y: 0.48),
            CGPoint(x: 0.77, y: 0.24),
            CGPoint(x: 0.86, y: 0.42)
        ]
        let scaled = points.map { point in
            CGPoint(x: rect.minX + (point.x * rect.width), y: rect.minY + (point.y * rect.height))
        }

        guard let first = scaled.first else { return path }

        path.move(to: first)
        for index in 1..<scaled.count {
            let previous = scaled[index - 1]
            let point = scaled[index]
            let control1 = CGPoint(x: previous.x + ((point.x - previous.x) * 0.45), y: previous.y - 18)
            let control2 = CGPoint(x: previous.x + ((point.x - previous.x) * 0.7), y: point.y + 18)
            path.addCurve(to: point, control1: control1, control2: control2)
        }

        return path
    }
}

private struct ProcessingPhotoTileLayout: Identifiable {
    let id: Int
    let start: CGPoint
    let end: CGPoint
    let size: CGSize
    let rotation: Double
    let color: Color
}

private enum ProcessingHeroLayout {
    static let tiles: [ProcessingPhotoTileLayout] = [
        ProcessingPhotoTileLayout(
            id: 0,
            start: CGPoint(x: 0.15, y: 0.36),
            end: CGPoint(x: 0.62, y: 0.64),
            size: CGSize(width: 0.16, height: 0.28),
            rotation: -14,
            color: Color(red: 0.99, green: 0.8, blue: 0.64)
        ),
        ProcessingPhotoTileLayout(
            id: 1,
            start: CGPoint(x: 0.28, y: 0.29),
            end: CGPoint(x: 0.7, y: 0.43),
            size: CGSize(width: 0.16, height: 0.24),
            rotation: 10,
            color: Color(red: 0.79, green: 0.92, blue: 0.96)
        ),
        ProcessingPhotoTileLayout(
            id: 2,
            start: CGPoint(x: 0.28, y: 0.54),
            end: CGPoint(x: 0.8, y: 0.29),
            size: CGSize(width: 0.16, height: 0.26),
            rotation: 8,
            color: Color(red: 0.93, green: 0.85, blue: 0.98)
        ),
        ProcessingPhotoTileLayout(
            id: 3,
            start: CGPoint(x: 0.17, y: 0.63),
            end: CGPoint(x: 0.84, y: 0.44),
            size: CGSize(width: 0.15, height: 0.24),
            rotation: -7,
            color: Color(red: 0.87, green: 0.95, blue: 0.83)
        ),
        ProcessingPhotoTileLayout(
            id: 4,
            start: CGPoint(x: 0.41, y: 0.37),
            end: CGPoint(x: 0.69, y: 0.71),
            size: CGSize(width: 0.14, height: 0.23),
            rotation: -10,
            color: Color(red: 0.99, green: 0.88, blue: 0.73)
        ),
        ProcessingPhotoTileLayout(
            id: 5,
            start: CGPoint(x: 0.4, y: 0.6),
            end: CGPoint(x: 0.76, y: 0.56),
            size: CGSize(width: 0.15, height: 0.26),
            rotation: 12,
            color: Color(red: 0.82, green: 0.89, blue: 0.99)
        ),
        ProcessingPhotoTileLayout(
            id: 6,
            start: CGPoint(x: 0.23, y: 0.18),
            end: CGPoint(x: 0.68, y: 0.21),
            size: CGSize(width: 0.14, height: 0.22),
            rotation: -4,
            color: Color(red: 0.96, green: 0.83, blue: 0.86)
        ),
        ProcessingPhotoTileLayout(
            id: 7,
            start: CGPoint(x: 0.39, y: 0.18),
            end: CGPoint(x: 0.58, y: 0.4),
            size: CGSize(width: 0.14, height: 0.22),
            rotation: 6,
            color: Color(red: 0.82, green: 0.97, blue: 0.93)
        )
    ]

    static let pins: [CGPoint] = [
        CGPoint(x: 0.25, y: 0.65),
        CGPoint(x: 0.38, y: 0.5),
        CGPoint(x: 0.52, y: 0.32),
        CGPoint(x: 0.63, y: 0.56),
        CGPoint(x: 0.77, y: 0.23),
        CGPoint(x: 0.83, y: 0.43)
    ]
}

private func mix(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
    start + ((end - start) * progress)
}

private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
}
