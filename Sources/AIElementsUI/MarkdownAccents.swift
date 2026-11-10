import SwiftUI

/// Optional accent colours for ``AIResponse``'s markdown.
///
/// By default a reply is drawn entirely in `foreground` / `mutedForeground`,
/// which on a dark surface reads as one flat white. A host that wants some
/// colour sets this once, high in the tree, with
/// ``SwiftUI/View/aiMarkdownAccents(_:)``. Every field is optional, and an
/// unset field keeps the stock colour. User bubbles never take accents.
public struct AIMarkdownAccents: Equatable, Sendable {
    /// Heading text (`#` … `######`).
    public var heading: Color?
    /// `**bold**` runs.
    public var strong: Color?
    /// List bullets and ordinals.
    public var marker: Color?
    /// The leading bar of a block quote.
    public var quote: Color?
    /// Inline `code` that is not a file reference.
    public var code: Color?
    /// Hyperlinks.
    public var link: Color?
    /// The glyph on a file-reference chip.
    public var fileGlyph: Color?

    public init(
        heading: Color? = nil,
        strong: Color? = nil,
        marker: Color? = nil,
        quote: Color? = nil,
        code: Color? = nil,
        link: Color? = nil,
        fileGlyph: Color? = nil
    ) {
        self.heading = heading
        self.strong = strong
        self.marker = marker
        self.quote = quote
        self.code = code
        self.link = link
        self.fileGlyph = fileGlyph
    }

    /// Applies the run-level accents (bold, inline code, links) to an
    /// inline-markdown string. Runs that already carry a colour are left alone.
    func applyingRunAccents(to text: AttributedString) -> AttributedString {
        guard strong != nil || code != nil || link != nil else { return text }
        var result = text
        for run in text.runs {
            guard run.foregroundColor == nil else { continue }
            let intent = run.inlinePresentationIntent
            let color: Color?
            if run.link != nil {
                color = link
            } else if intent?.contains(.code) == true {
                color = code
            } else if intent?.contains(.stronglyEmphasized) == true {
                color = strong
            } else {
                color = nil
            }
            if let color { result[run.range].foregroundColor = color }
        }
        return result
    }
}

private struct AIMarkdownAccentsKey: EnvironmentKey {
    static let defaultValue: AIMarkdownAccents? = nil
}

extension EnvironmentValues {
    /// Accent colours ``AIResponse`` paints its markdown with. `nil` keeps the
    /// stock monochrome rendering.
    public var aiMarkdownAccents: AIMarkdownAccents? {
        get { self[AIMarkdownAccentsKey.self] }
        set { self[AIMarkdownAccentsKey.self] = newValue }
    }
}

extension View {
    /// Sets the accent colours assistant markdown is drawn with.
    public func aiMarkdownAccents(_ accents: AIMarkdownAccents?) -> some View {
        environment(\.aiMarkdownAccents, accents)
    }
}
