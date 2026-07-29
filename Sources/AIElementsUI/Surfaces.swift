import ShadcnUI
import SwiftUI

#if canImport(WebKit)
import WebKit
#endif

// MARK: - Artifact

/// AI Elements' `Artifact` — a framed panel with a `bg-muted/50` title bar,
/// used to present generated documents and code.
public struct AIArtifact<Content: View, Actions: View>: View {
    private let title: String
    private let description: String?
    private let actions: Actions
    private let content: Content

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        title: String,
        description: String? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.actions = actions()
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ShadcnSeparator()
            VStack(alignment: .leading, spacing: Space.x3) {
                content
            }
            .padding(Space.x4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous)
                .fill(palette.background)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.lg)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous))
        .shadcnShadow(.sm)
    }

    private var header: some View {
        HStack(spacing: Space.x2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.sans(theme.typography.sm, weight: .medium))
                    .foregroundStyle(palette.foreground)
                if let description {
                    Text(description)
                        .font(theme.typography.sans(theme.typography.sm))
                        .foregroundStyle(palette.mutedForeground)
                }
            }
            Spacer(minLength: Space.x4)
            HStack(spacing: Space.x1) {
                actions
            }
        }
        .padding(.horizontal, Space.x4)
        .padding(.vertical, Space.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.muted.opacity(0.5))
    }
}

extension AIArtifact where Actions == EmptyView {
    public init(
        title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, description: description, actions: { EmptyView() }, content: content)
    }
}

/// `ArtifactAction` — a `size-8` ghost icon button in the artifact title bar.
public struct AIArtifactAction: View {
    private let systemImage: String
    private let tooltip: String
    private let action: () -> Void

    @Environment(\.shadcnPalette) private var palette

    public init(systemImage: String, tooltip: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.tooltip = tooltip
        self.action = action
    }

    public var body: some View {
        ShadcnButton(icon: systemImage, variant: .ghost, size: .iconSM, action: action)
            .foregroundStyle(palette.mutedForeground)
            .shadcnTooltip(tooltip)
            .accessibilityLabel(tooltip)
    }
}

// MARK: - Image

/// AI Elements' `Image` — a generated image at `rounded-md` with its intrinsic
/// aspect ratio preserved.
public struct AIGeneratedImage: View {
    private let image: Image
    private let alt: String?

    @Environment(\.shadcnTheme) private var theme

    public init(_ image: Image, alt: String? = nil) {
        self.image = image
        self.alt = alt
    }

    public var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous))
            .accessibilityLabel(alt ?? "Generated image")
    }
}

// MARK: - Inline citation

/// One source behind an inline citation.
public struct AICitationSource: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let url: String
    public let description: String?
    public let quote: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        url: String,
        description: String? = nil,
        quote: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.description = description
        self.quote = quote
    }

    /// Hostname shown on the citation pill.
    var hostname: String {
        URL(string: url)?.host ?? url
    }
}

/// AI Elements' `InlineCitation` — cited text followed by a pill that opens a
/// hover card paging through the sources.
public struct AIInlineCitation: View {
    private let text: String
    private let sources: [AICitationSource]

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var isHovering = false
    @State private var index = 0

    public init(text: String, sources: [AICitationSource]) {
        self.text = text
        self.sources = sources
    }

    private var pillLabel: String {
        guard let first = sources.first else { return "unknown" }
        return sources.count > 1
            ? "\(first.hostname) +\(sources.count - 1)"
            : first.hostname
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.x1) {
            Text(text)
                .font(theme.typography.sans(theme.typography.sm))
                .background(isHovering ? palette.accent : .clear)

            ShadcnHoverCard(width: 320) {
                ShadcnBadge(pillLabel, variant: .secondary)
            } content: {
                card
            }
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    @ViewBuilder
    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            // `bg-secondary rounded-t-md p-2` pager bar.
            HStack(spacing: Space.x2) {
                Button {
                    index = index > 0 ? index - 1 : sources.count - 1
                } label: {
                    ShadcnIconView(ShadcnIcon.chevronLeft, size: 16)
                        .foregroundStyle(palette.mutedForeground)
                }
                .buttonStyle(.shadcnBare)
                .accessibilityLabel("Previous source")

                Spacer(minLength: 0)

                Text("\(index + 1)/\(sources.count)")
                    .font(theme.typography.sans(theme.typography.xs))
                    .foregroundStyle(palette.mutedForeground)

                Button {
                    index = index < sources.count - 1 ? index + 1 : 0
                } label: {
                    ShadcnIconView(ShadcnIcon.chevronRight, size: 16)
                        .foregroundStyle(palette.mutedForeground)
                }
                .buttonStyle(.shadcnBare)
                .accessibilityLabel("Next source")
            }
            .padding(Space.x2)
            .background(palette.secondary)

            if sources.indices.contains(index) {
                let source = sources[index]
                VStack(alignment: .leading, spacing: Space.x2) {
                    Text(source.title)
                        .font(theme.typography.sans(theme.typography.sm, weight: .medium))
                        .lineLimit(1)
                    Text(source.url)
                        .font(theme.typography.sans(theme.typography.xs))
                        .foregroundStyle(palette.mutedForeground)
                        .lineLimit(1)
                    if let description = source.description {
                        Text(description)
                            .font(theme.typography.sans(theme.typography.sm))
                            .foregroundStyle(palette.mutedForeground)
                            .lineLimit(3)
                    }
                    if let quote = source.quote {
                        HStack(alignment: .top, spacing: Space.x3) {
                            Rectangle()
                                .fill(palette.muted)
                                .frame(width: 2)
                            Text(quote)
                                .font(theme.typography.sans(theme.typography.sm))
                                .italic()
                                .foregroundStyle(palette.mutedForeground)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Space.x4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // The panel supplies its own padding; the card must not add more.
        .padding(-Space.x4)
    }
}

// MARK: - Web preview

/// A console line surfaced by `AIWebPreview`.
public struct AIWebPreviewLog: Identifiable, Sendable {
    public enum Level: Sendable {
        case log
        case warn
        case error
    }

    public let id = UUID()
    public let level: Level
    public let message: String
    public let timestamp: Date

    public init(level: Level, message: String, timestamp: Date = Date()) {
        self.level = level
        self.message = message
        self.timestamp = timestamp
    }
}

/// AI Elements' `WebPreview` — a chrome-in-a-box browser with a URL bar and a
/// collapsible console.
public struct AIWebPreview: View {
    @Binding private var url: String
    private let logs: [AIWebPreviewLog]

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var draftURL: String = ""
    @State private var loadedURL: URL?

    public init(url: Binding<String>, logs: [AIWebPreviewLog] = []) {
        self._url = url
        self.logs = logs
    }

    public var body: some View {
        VStack(spacing: 0) {
            navigation
            ShadcnSeparator()
            body_
            ShadcnSeparator()
            console
        }
        .background(
            RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous)
                .fill(palette.card)
        )
        .shadcnBorder(palette.border, cornerRadius: theme.radius.lg)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous))
        .onAppear {
            draftURL = url
            loadedURL = URL(string: url)
        }
    }

    private var navigation: some View {
        HStack(spacing: Space.x1) {
            ShadcnButton(icon: ShadcnIcon.chevronLeft, variant: .ghost, size: .iconSM) {}
                .shadcnTooltip("Back")
            ShadcnButton(icon: ShadcnIcon.chevronRight, variant: .ghost, size: .iconSM) {}
                .shadcnTooltip("Forward")
            ShadcnButton(icon: ShadcnIcon.refresh, variant: .ghost, size: .iconSM) {
                loadedURL = URL(string: url)
            }
            .shadcnTooltip("Reload")

            ShadcnTextField("Enter URL...", text: $draftURL) {
                url = draftURL
                loadedURL = URL(string: draftURL)
            }
        }
        .padding(Space.x2)
    }

    @ViewBuilder
    private var body_: some View {
        #if canImport(WebKit)
        AIWebView(url: loadedURL)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    private var console: some View {
        ShadcnDisclosure(defaultOpen: false) { isOpen in
            HStack {
                Text("Console")
                    .font(theme.typography.mono(theme.typography.sm, weight: .medium))
                Spacer()
                ShadcnDisclosureChevron(isOpen: isOpen)
            }
            .padding(Space.x4)
            .contentShape(Rectangle())
        } content: {
            VStack(alignment: .leading, spacing: Space.x1) {
                if logs.isEmpty {
                    Text("No console output")
                        .font(theme.typography.mono(theme.typography.sm))
                        .foregroundStyle(palette.mutedForeground)
                } else {
                    ForEach(logs) { log in
                        HStack(alignment: .top, spacing: Space.x2) {
                            Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                .foregroundStyle(palette.mutedForeground)
                            Text(log.message)
                                .foregroundStyle(color(for: log.level))
                        }
                        .font(theme.typography.mono(theme.typography.xs))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.x4)
            .padding(.bottom, Space.x4)
        }
        .background(palette.muted.opacity(0.5))
    }

    private func color(for level: AIWebPreviewLog.Level) -> Color {
        switch level {
        case .log: palette.foreground
        case .warn: AITailwindColor.yellow600
        case .error: palette.destructive
        }
    }
}

#if canImport(WebKit)
#if canImport(AppKit)
import AppKit

/// Minimal `WKWebView` bridge standing in for the original's sandboxed iframe.
struct AIWebView: NSViewRepresentable {
    let url: URL?

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url, webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}
#elseif canImport(UIKit)
import UIKit

struct AIWebView: UIViewRepresentable {
    let url: URL?

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url, webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}
#endif
#endif
