import AIElementsUI
import ShadcnUI
import SwiftUI

/// The surfaces that used to paint black over wallpaper: selects, menus,
/// cards, dialogs, the conversation picker, and a Settings-like layout.
struct GlassDemo: View {
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnSurfaceOpacity) private var surfaceOpacity

    @State private var provider: String? = "auto"
    @State private var effort: String? = "auto"
    @State private var showMenu = false
    @State private var showPopover = false
    @State private var showDialog = false
    @State private var query = ""
    @State private var activeThread = "1"

    private let threads: [AIConversationEntry] = [
        AIConversationEntry(
            id: "1", title: "Glass chrome",
            updatedAt: Date().addingTimeInterval(-360),
            snippet: "Menus should frost, not paint black."),
        AIConversationEntry(
            id: "2", title: "Settings window",
            updatedAt: Date().addingTimeInterval(-7200),
            snippet: "Titlebar, sidebar and cards share one glass."),
        AIConversationEntry(
            id: "3", title: "Conversation picker",
            updatedAt: Date().addingTimeInterval(-86400),
            snippet: "NSPopover samples the desktop.", isArchived: false),
    ]

    var body: some View {
        Group {
        GalleryHeading(
            title: "Glass",
            subtitle: "Toggle Glass in the sidebar. On: macOS Liquid Glass (same material as system menus). Off: flat fills."
        )

        Text("Surface opacity \(Int((surfaceOpacity * 100).rounded()))%")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(palette.mutedForeground)

        GalleryBlock("Selects (Chat composer)") {
            HStack(spacing: Space.x3) {
                ShadcnSelect(
                    "Provider",
                    selection: $provider,
                    width: 180,
                    isCompact: true,
                    options: [
                        ShadcnSelectOption(value: "auto", label: "Auto", systemImage: "sparkles"),
                        ShadcnSelectOption(value: "claude", label: "Claude", systemImage: "brain"),
                        ShadcnSelectOption(value: "codex", label: "Codex", systemImage: "chevron.left.forwardslash.chevron.right"),
                    ]
                )
                ShadcnSelect(
                    "Effort",
                    selection: $effort,
                    width: 160,
                    startsOpen: true,
                    isCompact: true,
                    edge: .bottom,
                    options: [
                        ShadcnSelectOption(
                            value: "auto", label: "Auto",
                            systemImage: "cellularbars", symbolVariableValue: 0.5),
                        ShadcnSelectOption(
                            value: "none", label: "None",
                            systemImage: "cellularbars", symbolVariableValue: 0),
                        ShadcnSelectOption(
                            value: "low", label: "Low",
                            systemImage: "cellularbars", symbolVariableValue: 0.25),
                        ShadcnSelectOption(
                            value: "high", label: "High",
                            systemImage: "cellularbars", symbolVariableValue: 1),
                    ]
                )
            }
            .padding(.bottom, 220)
        }

        GalleryBlock("Menu, popover, dialog") {
            HStack(spacing: Space.x3) {
                ShadcnDropdownMenu(isPresented: $showMenu) {
                    ShadcnButton("Open menu", variant: .outline) { showMenu.toggle() }
                } content: {
                    ShadcnMenuLabel("Pane")
                    ShadcnMenuItem("Rename Panel…") {}
                    ShadcnMenuSeparator()
                    ShadcnMenuItem("New Chat") {}
                    ShadcnMenuItem("Browser") {}
                    ShadcnMenuItem("Files") {}
                    ShadcnMenuSeparator()
                    ShadcnMenuItem("Opacity") {}
                }

                ShadcnPopover(isPresented: $showPopover) {
                    ShadcnButton("Open popover", variant: .outline) { showPopover.toggle() }
                } content: {
                    VStack(alignment: .leading, spacing: Space.x2) {
                        ShadcnCardTitle("History")
                        ShadcnCardDescription("Frosted over the wallpaper, not a black card.")
                    }
                }

                ShadcnButton("Open dialog", variant: .outline) { showDialog = true }
            }
            .padding(.bottom, 160)
        }

        GalleryBlock("Card, field, alert") {
            VStack(alignment: .leading, spacing: Space.x4) {
                ShadcnCard {
                    ShadcnCardHeader {
                        ShadcnCardTitle("Settings")
                        ShadcnCardDescription("The same chrome Infinitty Settings uses.")
                    }
                    ShadcnCardContent {
                        ShadcnTextField("Search conversations", text: $query)
                    }
                    ShadcnCardFooter {
                        ShadcnButton("Save", size: .small) {}
                        ShadcnButton("Cancel", variant: .outline, size: .small) {}
                    }
                }
                .frame(maxWidth: 460)

                ShadcnAlert(systemImage: ShadcnIcon.info) {
                    ShadcnAlertTitle("Glass, not a slab")
                    ShadcnAlertDescription(
                        "If this card is black, surface opacity is not reaching the fill.")
                }
                .frame(maxWidth: 460)
            }
        }

        #if canImport(AppKit)
        GalleryBlock("Conversation picker") {
            AIConversationPickerView(
                threads: threads,
                activeId: activeThread,
                onSelect: { activeThread = $0 },
                onNew: {},
                onArchive: { _ in }
            )
        }
        #endif
        }
        .shadcnDialog(isPresented: $showDialog, width: 420) {
            ShadcnCardTitle("Confirm")
            ShadcnCardDescription("Dialogs use the same translucent fill as menus.")
            HStack {
                Spacer()
                ShadcnButton("Close", variant: .outline, size: .small) { showDialog = false }
            }
        }
    }
}
