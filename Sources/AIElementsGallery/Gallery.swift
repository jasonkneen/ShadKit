import AIElementsUI
import ShadcnUI
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// A browsable showcase of every component in the package.
///
/// Ships as its own library so a consuming app can drop it into a window and
/// compare against the shadcn and AI Elements docs side by side.
public struct ShadcnAIGallery: View {
    @State private var section: GallerySection
    @State private var forcedScheme: ColorScheme?
    @State private var surfaceOpacity: Double
    @State private var glassEnabled: Bool

    private let theme: ShadcnTheme

    /// - Parameters:
    ///   - initialSection: Which page to open on. Handy for screenshot passes.
    ///   - scheme: Force light or dark; `nil` follows the system.
    ///   - surfaceOpacity: Pane fill alpha. Independent of glass.
    ///   - glass: Frosted materials on panels and overlays (native-menu look).
    public init(
        theme: ShadcnTheme = .default,
        initialSection: GallerySection = .aiConversation,
        scheme: ColorScheme? = nil,
        surfaceOpacity: Double = 1,
        glass: Bool = true
    ) {
        self.theme = theme
        self._section = State(initialValue: initialSection)
        self._forcedScheme = State(initialValue: scheme)
        self._surfaceOpacity = State(initialValue: min(max(surfaceOpacity, 0), 1))
        self._glassEnabled = State(initialValue: glass)
    }

    @ViewBuilder
    public var body: some View {
        // Written into the environment rather than expressed as
        // `preferredColorScheme`, which is a preference routed via the window —
        // writing it directly keeps the forced scheme deterministic in a plain
        // NSHostingView.
        if let forcedScheme {
            surface.environment(\.colorScheme, forcedScheme)
        } else {
            surface
        }
    }

    private var showsWallpaper: Bool {
        glassEnabled || surfaceOpacity < 0.999
    }

    private var chrome: some View {
        HStack(spacing: 0) {
            sidebar
            ShadcnSeparator(.vertical)
            detail
        }
        .padding(.top, 28)
        .frame(minWidth: 900, minHeight: 620)
    }

    @ViewBuilder
    private var surface: some View {
        if showsWallpaper {
            chrome
                .shadcnTheme(theme, surfaceOpacity: surfaceOpacity, glass: glassEnabled)
                .background { GalleryWallpaper() }
        } else {
            chrome.shadcnSurface(theme, glass: glassEnabled)
        }
    }

    private var sidebar: some View {
        GallerySidebar(
            section: $section,
            forcedScheme: $forcedScheme,
            surfaceOpacity: $surfaceOpacity,
            glassEnabled: $glassEnabled
        )
        .frame(width: 220)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.x8) {
                section.content
            }
            .padding(Space.x8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sidebar

private struct GallerySidebar: View {
    @Binding var section: GallerySection
    @Binding var forcedScheme: ColorScheme?
    @Binding var surfaceOpacity: Double
    @Binding var glassEnabled: Bool

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.x2) {
                ShadcnIconView(ShadcnIcon.sparkles, size: 16)
                Text("ShadKit")
                    .font(theme.typography.sans(theme.typography.sm, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, Space.x4)
            .padding(.vertical, Space.x3)

            ShadcnSeparator()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.x4) {
                    ForEach(GallerySection.groups, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            ShadcnMenuLabel(group.title)
                            ForEach(group.sections) { entry in
                                GallerySidebarRow(
                                    entry: entry,
                                    isSelected: entry == section
                                ) {
                                    section = entry
                                }
                            }
                        }
                    }
                }
                .padding(Space.x2)
            }

            ShadcnSeparator()

            appearancePicker
                .padding(Space.x3)
        }
        .background(
            ShadcnTranslucentFill(color: palette.sidebar, cornerRadius: 0)
        )
    }

    private var appearancePicker: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            Text("Appearance")
                .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                .foregroundStyle(palette.mutedForeground)

            ShadcnTabs(
                selection: Binding(
                    get: { forcedScheme.map { $0 == .dark ? 2 : 1 } ?? 0 },
                    set: { forcedScheme = $0 == 0 ? nil : ($0 == 1 ? .light : .dark) }
                ),
                items: [(0, "Auto"), (1, "Light"), (2, "Dark")]
            )

            HStack {
                Text("Glass")
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                    .foregroundStyle(palette.mutedForeground)
                Spacer()
                ShadcnSwitch(isOn: $glassEnabled, size: .small)
            }

            VStack(alignment: .leading, spacing: Space.x1) {
                HStack {
                    Text("Opacity")
                        .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                        .foregroundStyle(palette.mutedForeground)
                    Spacer()
                    Text("\(Int((surfaceOpacity * 100).rounded()))%")
                        .font(theme.typography.mono(theme.typography.xs))
                        .foregroundStyle(palette.mutedForeground)
                }
                ShadcnSlider(value: $surfaceOpacity, in: 0.2...1, step: 0.05)
            }
        }
    }
}

private struct GallerySidebarRow: View {
    let entry: GallerySection
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.x2) {
                ShadcnIconView(entry.systemImage, size: 14)
                Text(entry.title)
                    .font(theme.typography.sans(theme.typography.sm))
                Spacer(minLength: 0)
            }
            .foregroundStyle(
                isSelected ? palette.sidebarAccentForeground : palette.sidebarForeground
            )
            .padding(.horizontal, Space.x2)
            .padding(.vertical, Space.x1_5)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                    .fill(
                        isSelected
                            ? palette.sidebarAccent
                            : (isHovering ? palette.sidebarAccent.opacity(0.5) : .clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.shadcnBare)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Section list

public enum GallerySection: String, Identifiable, CaseIterable, Sendable {
    case tokens
    case buttons
    case badges
    case forms
    case cards
    case overlays
    case glass
    case aiConversation
    case aiPrompt
    case aiThinking
    case aiTooling
    case aiContent
    case aiWorkflow
    case aiTemplates
    case aiChatbot
    case canvas
    case assistantPanel
    case diff

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .tokens: "Design tokens"
        case .buttons: "Button"
        case .badges: "Badge"
        case .forms: "Form controls"
        case .cards: "Card & feedback"
        case .overlays: "Overlays"
        case .glass: "Glass"
        case .aiConversation: "Conversation"
        case .aiPrompt: "Prompt input"
        case .aiThinking: "Reasoning"
        case .aiTooling: "Tool & Task"
        case .aiContent: "Response & Code"
        case .aiWorkflow: "Plan & Queue"
        case .aiTemplates: "Composer templates"
        case .aiChatbot: "Chatbot block"
        case .canvas: "Canvas"
        case .assistantPanel: "Assistant panel"
        case .diff: "Diff"
        }
    }

    var systemImage: String {
        switch self {
        case .tokens: "paintpalette"
        case .buttons: "rectangle.and.hand.point.up.left"
        case .badges: "capsule"
        case .forms: "textformat"
        case .cards: "square.on.square"
        case .overlays: "rectangle.stack"
        case .glass: "cube.transparent"
        case .aiConversation: "bubble.left.and.bubble.right"
        case .aiPrompt: "text.cursor"
        case .aiThinking: ShadcnIcon.brain
        case .aiTooling: ShadcnIcon.wrench
        case .aiContent: ShadcnIcon.terminal
        case .aiWorkflow: ShadcnIcon.listTodo
        case .aiTemplates: "square.grid.2x2"
        case .aiChatbot: "sparkle.magnifyingglass"
        case .canvas: "point.topleft.down.to.point.bottomright.curvepath"
        case .assistantPanel: "sidebar.right"
        case .diff: "plusminus"
        }
    }

    static let groups: [(title: String, sections: [GallerySection])] = [
        ("shadcn/ui", [.tokens, .buttons, .badges, .forms, .cards, .overlays, .glass]),
        ("AI Elements", [.aiConversation, .aiPrompt, .aiThinking, .aiTooling, .aiContent, .aiWorkflow]),
        ("Templates", [.aiTemplates, .aiChatbot]),
        ("Canvas", [.canvas]),
        ("Infinitty", [.assistantPanel, .diff]),
    ]

    @ViewBuilder
    var content: some View {
        switch self {
        case .tokens: TokensDemo()
        case .buttons: ButtonsDemo()
        case .badges: BadgesDemo()
        case .forms: FormsDemo()
        case .cards: CardsDemo()
        case .overlays: OverlaysDemo()
        case .glass: GlassDemo()
        case .aiConversation: ConversationDemo()
        case .aiPrompt: PromptDemo()
        case .aiThinking: ThinkingDemo()
        case .aiTooling: ToolingDemo()
        case .aiContent: ContentDemo()
        case .aiWorkflow: WorkflowDemo()
        case .aiTemplates: TemplatesDemo()
        case .aiChatbot: ChatbotDemo()
        case .canvas: CanvasDemo()
        case .assistantPanel: PanelDemo()
        case .diff: DiffDemo()
        }
    }
}

// MARK: - Shared section chrome

struct GalleryHeading: View {
    let title: String
    let subtitle: String

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x1_5) {
            Text(title)
                .font(theme.typography.sans(theme.typography.xl2, weight: .semibold))
                .tracking(-0.5)
            Text(subtitle)
                .font(theme.typography.sans(theme.typography.sm))
                .foregroundStyle(palette.mutedForeground)
        }
    }
}

struct GalleryBlock<Content: View>: View {
    let title: String
    let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            Text(title)
                .font(theme.typography.sans(theme.typography.sm, weight: .medium))
                .foregroundStyle(palette.mutedForeground)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Distinctive plate behind translucent chrome so frost is obvious even on a
/// dark desktop. Not used when opacity is 1.
struct GalleryWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.32, blue: 0.52),
                    Color(red: 0.07, green: 0.12, blue: 0.28),
                    Color(red: 0.16, green: 0.10, blue: 0.30),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.cyan.opacity(0.28))
                .frame(width: 480, height: 480)
                .blur(radius: 40)
                .offset(x: -220, y: -90)
            Circle()
                .fill(Color.blue.opacity(0.22))
                .frame(width: 560, height: 560)
                .blur(radius: 50)
                .offset(x: 260, y: 180)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 24)
                .offset(x: 80, y: -220)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

#if canImport(AppKit)
/// Puts a gallery in a window that composites against the desktop, matching
/// Infinitty's translucent Settings/Chat chrome.
public enum ShadcnGalleryWindow {
    public static func install(_ gallery: some View, in window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = ShadcnWindowTransparency.translucentBacking
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        window.isMovableByWindowBackground = true

        let host = NSHostingView(rootView: AnyView(gallery))
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        let bounds = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 1180, height: 800)
        window.contentView = ShadcnWindowTransparency.wrap(
            host, frame: bounds, cornerRadius: 0, glass: true)
        ShadcnWindowTransparency.apply(to: window)
    }
}
#endif

