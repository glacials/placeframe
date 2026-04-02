import SwiftUI

enum PhotoLocSyncShortcutHelpContext {
    case `import`
    case review(canAdjustCaptureTimeOffset: Bool)
    case processing
    case failed
}

private struct KeyboardShortcutSection: Identifiable {
    let title: String
    let items: [KeyboardShortcutItem]

    var id: String { title }
}

private struct KeyboardShortcutItem: Identifiable {
    let id: String
    let title: String
    let note: String?
    let keys: [String]

    init(_ title: String, note: String? = nil, keys: [String]) {
        self.id = "\(title)-\(keys.joined(separator: "+"))"
        self.title = title
        self.note = note
        self.keys = keys
    }
}

struct PhotoLocSyncKeyboardShortcutsOverlay: View {
    let context: PhotoLocSyncShortcutHelpContext
    let dismiss: () -> Void

    private var sections: [KeyboardShortcutSection] {
        var sections = [
            KeyboardShortcutSection(
                title: "Global",
                items: [
                    KeyboardShortcutItem("Show or hide shortcuts", keys: ["?"])
                ]
            )
        ]

        switch context {
        case .import:
            sections.append(
                KeyboardShortcutSection(
                    title: "Import",
                    items: [
                        KeyboardShortcutItem("Import timeline JSON", note: "Works from the import screen.", keys: ["I"]),
                        KeyboardShortcutItem("Open importer", note: "Native Mac open shortcut.", keys: ["⌘", "O"]),
                        KeyboardShortcutItem("Import timeline JSON", note: "Default action on the import screen.", keys: ["↩"])
                    ]
                )
            )
        case .review(let canAdjustCaptureTimeOffset):
            var reviewItems = [
                KeyboardShortcutItem("Move selection down", keys: ["J"]),
                KeyboardShortcutItem("Move selection up", keys: ["K"]),
                KeyboardShortcutItem("Open Quick Look", keys: ["Space"]),
                KeyboardShortcutItem("Apply focused photo", keys: ["↩"]),
                KeyboardShortcutItem("Open save-location menu", keys: ["L"]),
                KeyboardShortcutItem("Apply every photo in the current day", keys: ["⇧", "A"]),
                KeyboardShortcutItem("Go to next day", keys: ["N"]),
                KeyboardShortcutItem("Go to previous day", keys: ["P"]),
                KeyboardShortcutItem("Select every photo in the current day", keys: ["⌘", "A"]),
                KeyboardShortcutItem("Undo", note: "Native macOS undo.", keys: ["⌘", "Z"]),
                KeyboardShortcutItem("Redo", note: "Native macOS redo.", keys: ["⇧", "⌘", "Z"]),
                KeyboardShortcutItem("Return to import", note: "Shows a confirmation dialog first.", keys: ["Esc"])
            ]

            if canAdjustCaptureTimeOffset {
                reviewItems.insert(
                    KeyboardShortcutItem("Compare camera time assumptions", keys: ["T"]),
                    at: 8
                )
            }

            sections.append(
                KeyboardShortcutSection(
                    title: "Review",
                    items: reviewItems
                )
            )

            if canAdjustCaptureTimeOffset {
                sections.append(
                    KeyboardShortcutSection(
                        title: "Camera Time Sheet",
                        items: [
                            KeyboardShortcutItem("Move selection down", keys: ["J"]),
                            KeyboardShortcutItem("Move selection up", keys: ["K"]),
                            KeyboardShortcutItem("Apply selected assumption", keys: ["↩"]),
                            KeyboardShortcutItem("Close the sheet", keys: ["Esc"])
                        ]
                    )
                )
            }
        case .processing:
            sections.append(
                KeyboardShortcutSection(
                    title: "Processing",
                    items: [
                        KeyboardShortcutItem("Show or hide shortcuts", note: "Processing has no other direct actions.", keys: ["?"])
                    ]
                )
            )
        case .failed:
            sections.append(
                KeyboardShortcutSection(
                    title: "Error",
                    items: [
                        KeyboardShortcutItem("Show or hide shortcuts", keys: ["?"])
                    ]
                )
            )
        }

        return sections
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keyboard Shortcuts")
                            .font(.largeTitle.bold())
                        Text("Navigate the current screen without tabbing through controls.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(section.title)
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(section.items) { item in
                                        HStack(alignment: .center, spacing: 16) {
                                            HStack(spacing: 6) {
                                                ForEach(item.keys, id: \.self) { key in
                                                    ShortcutKeyCap(label: key)
                                                }
                                            }
                                            .frame(minWidth: 130, alignment: .leading)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.body.weight(.medium))
                                                if let note = item.note {
                                                    Text(note)
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            Spacer(minLength: 0)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
            .padding(28)
            .frame(width: 760, height: 620, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
            .background {
                VStack {
                    Button("Hide Keyboard Shortcuts") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

private struct ShortcutKeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
    }
}
