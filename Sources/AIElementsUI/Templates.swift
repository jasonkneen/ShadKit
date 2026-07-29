import ShadcnUI
import SwiftUI

/// A `rounded-full` composer pill — the shape ChatGPT and Grok use for their
/// tool row.
public struct AIPromptPillButton: View {
    private let systemImage: String
    private let title: String?
    private let variant: ShadcnButtonVariant
    private let isActive: Bool
    private let action: () -> Void

    @Environment(\.shadcnTheme) private var theme

    public init(
        systemImage: String,
        title: String? = nil,
        variant: ShadcnButtonVariant = .outline,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.variant = variant
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Space.x1_5) {
                ShadcnIconView(systemImage, size: 16)
                if let title {
                    Text(title)
                }
            }
            .padding(.horizontal, title == nil ? 0 : Space.x1)
        }
        .buttonStyle(
            ShadcnButtonStyle(
                variant: isActive ? .secondary : variant,
                size: .small,
                hasIcon: true,
                cornerRadius: theme.radius.full
            )
        )
        .fixedSize()
    }
}

// MARK: - ChatGPT

/// The ChatGPT composer: `rounded-[28px]`, `px-5` textarea, and a row of
/// bordered `rounded-full` pills.
public struct AIChatGPTComposer: View {
    @Binding private var text: String
    private let status: AIPromptStatus
    private let suggestions: [String]
    private let onSubmit: () -> Void
    private let onStop: (() -> Void)?
    private let onSuggestion: (String) -> Void

    @State private var useWebSearch = false
    @State private var useVoice = false
    @State private var showAttachMenu = false

    public init(
        text: Binding<String>,
        status: AIPromptStatus = .ready,
        suggestions: [String] = [],
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        onSuggestion: @escaping (String) -> Void = { _ in }
    ) {
        self._text = text
        self.status = status
        self.suggestions = suggestions
        self.onSubmit = onSubmit
        self.onStop = onStop
        self.onSuggestion = onSuggestion
    }

    public var body: some View {
        VStack(spacing: Space.x4) {
            AIPromptInput(
                text: $text,
                placeholder: "Ask anything",
                status: status,
                style: .pill,
                onSubmit: onSubmit,
                onStop: onStop
            ) {
                ShadcnDropdownMenu(isPresented: $showAttachMenu) {
                    AIPromptPillButton(
                        systemImage: ShadcnIcon.paperclip,
                        title: "Attach"
                    ) {
                        showAttachMenu.toggle()
                    }
                } content: {
                    AIAttachmentMenuItems { showAttachMenu = false }
                }

                AIPromptPillButton(
                    systemImage: ShadcnIcon.globe,
                    title: "Search",
                    isActive: useWebSearch
                ) {
                    useWebSearch.toggle()
                }
            } trailing: {
                AIPromptPillButton(
                    systemImage: ShadcnIcon.audioWaveform,
                    title: "Voice",
                    variant: .secondary,
                    isActive: useVoice
                ) {
                    useVoice.toggle()
                }
            }

            if !suggestions.isEmpty {
                AISuggestions(suggestions, onSelect: onSuggestion)
            }
        }
    }
}

// MARK: - Claude

/// The Claude composer: a `bg-card rounded-md` shell with icon-only tools and
/// the model picker on the right.
public struct AIClaudeComposer: View {
    @Binding private var text: String
    private let status: AIPromptStatus
    private let models: [(value: String, label: String)]
    @Binding private var model: String?
    private let onSubmit: () -> Void
    private let onStop: (() -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @State private var showAttachMenu = false

    public init(
        text: Binding<String>,
        status: AIPromptStatus = .ready,
        model: Binding<String?>,
        models: [(value: String, label: String)],
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil
    ) {
        self._text = text
        self.status = status
        self._model = model
        self.models = models
        self.onSubmit = onSubmit
        self.onStop = onStop
    }

    public var body: some View {
        AIPromptInput(
            text: $text,
            placeholder: "Reply to Claude...",
            status: status,
            style: AIPromptInputStyle(
                background: palette.card,
                textFieldHorizontalPadding: Space.x3,
                usesLargeText: true
            ),
            onSubmit: onSubmit,
            onStop: onStop
        ) {
            ShadcnDropdownMenu(isPresented: $showAttachMenu) {
                ShadcnButton(
                    icon: ShadcnIcon.plus,
                    variant: .outline,
                    size: .iconSM
                ) {
                    showAttachMenu.toggle()
                }
                .accessibilityLabel("Add attachment")
            } content: {
                AIAttachmentMenuItems { showAttachMenu = false }
            }

            ShadcnButton(icon: ShadcnIcon.settings2, variant: .outline, size: .iconSM) {}
                .accessibilityLabel("Settings")
        } trailing: {
            ShadcnSelect("Model", selection: $model, width: 190, options: models)
        }
    }
}

// MARK: - Grok

/// The Grok composer: pill shell, a segmented DeepSearch control, and a Think
/// toggle.
public struct AIGrokComposer: View {
    @Binding private var text: String
    private let status: AIPromptStatus
    private let models: [(value: String, label: String)]
    @Binding private var model: String?
    private let onSubmit: () -> Void
    private let onStop: (() -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var useDeepSearch = false
    @State private var useThink = false
    @State private var showAttachMenu = false
    @State private var showDepthMenu = false

    public init(
        text: Binding<String>,
        status: AIPromptStatus = .ready,
        model: Binding<String?>,
        models: [(value: String, label: String)],
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil
    ) {
        self._text = text
        self.status = status
        self._model = model
        self.models = models
        self.onSubmit = onSubmit
        self.onStop = onStop
    }

    public var body: some View {
        AIPromptInput(
            text: $text,
            placeholder: "How can Grok help?",
            status: status,
            style: .pill,
            onSubmit: onSubmit,
            onStop: onStop
        ) {
            ShadcnDropdownMenu(isPresented: $showAttachMenu) {
                AIPromptPillButton(systemImage: ShadcnIcon.paperclip) {
                    showAttachMenu.toggle()
                }
                .accessibilityLabel("Attach")
            } content: {
                AIAttachmentMenuItems { showAttachMenu = false }
            }

            deepSearchGroup

            AIPromptPillButton(
                systemImage: ShadcnIcon.lightbulb,
                title: "Think",
                isActive: useThink
            ) {
                useThink.toggle()
            }
        } trailing: {
            ShadcnSelect("Model", selection: $model, width: 150, options: models)
        }
    }

    /// `rounded-full border` wrapping a labelled toggle and a chevron, split by
    /// a hairline — Grok's search-depth control.
    private var deepSearchGroup: some View {
        HStack(spacing: 0) {
            Button {
                useDeepSearch.toggle()
            } label: {
                HStack(spacing: Space.x1_5) {
                    ShadcnIconView(ShadcnIcon.search, size: 16)
                    Text("DeepSearch")
                }
                .padding(.horizontal, Space.x2_5)
                .frame(height: 32)
                .background(useDeepSearch ? palette.secondary : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.shadcnBare)

            Rectangle()
                .fill(palette.border)
                .frame(width: 1, height: 32)

            ShadcnDropdownMenu(isPresented: $showDepthMenu, alignment: .trailing) {
                Button {
                    showDepthMenu.toggle()
                } label: {
                    ShadcnIconView(ShadcnIcon.chevronDown, size: 16)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.shadcnBare)
            } content: {
                ShadcnMenuItem("DeepSearch") { showDepthMenu = false }
                ShadcnMenuItem("DeeperSearch") { showDepthMenu = false }
            }
        }
        .font(theme.typography.sans(theme.typography.sm, weight: .medium))
        .foregroundStyle(palette.foreground)
        .clipShape(Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(palette.border, lineWidth: 1))
        .fixedSize()
    }
}

/// The shared "upload file / photo / screenshot / camera" menu the three
/// templates all hang off their attach button.
struct AIAttachmentMenuItems: View {
    let onSelect: () -> Void

    var body: some View {
        ShadcnMenuItem("Upload file", systemImage: ShadcnIcon.file, action: onSelect)
        ShadcnMenuItem("Upload photo", systemImage: ShadcnIcon.image, action: onSelect)
        ShadcnMenuItem("Take screenshot", systemImage: ShadcnIcon.screenShare, action: onSelect)
        ShadcnMenuItem("Take photo", systemImage: ShadcnIcon.camera, action: onSelect)
    }
}
