import SwiftUI

/// SF Symbol stand-ins for the Lucide icons shadcn and AI Elements ship with.
///
/// Kept in one place so a consumer can swap the whole icon set, and so ported
/// components can name the icon the React source named.
public enum ShadcnIcon {
    public static let chevronDown = "chevron.down"
    public static let chevronUp = "chevron.up"
    public static let chevronLeft = "chevron.left"
    public static let chevronRight = "chevron.right"
    public static let chevronsUpDown = "chevron.up.chevron.down"
    public static let check = "checkmark"
    public static let checkCircle = "checkmark.circle"
    public static let xMark = "xmark"
    public static let xCircle = "xmark.circle"
    public static let circle = "circle"
    public static let circleFilled = "circle.fill"
    public static let clock = "clock"
    public static let brain = "brain"
    public static let wrench = "wrench.adjustable"
    public static let search = "magnifyingglass"
    public static let copy = "doc.on.doc"
    public static let book = "book"
    public static let arrowDown = "arrow.down"
    public static let arrowUp = "arrow.up"
    public static let arrowUpRight = "arrow.up.right"
    public static let paperclip = "paperclip"
    public static let globe = "globe"
    public static let refresh = "arrow.clockwise"
    public static let externalLink = "arrow.up.forward.app"
    public static let sparkles = "sparkles"
    public static let send = "arrow.up"
    public static let square = "square.fill"
    public static let microphone = "mic"
    public static let plus = "plus"
    public static let image = "photo"
    public static let file = "doc"
    public static let lightbulb = "lightbulb"
    public static let dotsHorizontal = "ellipsis"
    public static let trash = "trash"
    public static let pencil = "pencil"
    public static let play = "play.fill"
    public static let pause = "pause.fill"
    public static let thumbsUp = "hand.thumbsup"
    public static let thumbsDown = "hand.thumbsdown"
    public static let alertTriangle = "exclamationmark.triangle"
    public static let info = "info.circle"
    public static let listTodo = "checklist"
    public static let gitBranch = "arrow.triangle.branch"
    public static let database = "cylinder.split.1x2"
    public static let cpu = "cpu"
    public static let terminal = "terminal"
    public static let folder = "folder"
    public static let link = "link"
    public static let shield = "checkmark.shield"
    public static let audioWaveform = "waveform"
    public static let settings2 = "slider.horizontal.3"
    public static let screenShare = "rectangle.on.rectangle"
    public static let camera = "camera"
    public static let bookmark = "bookmark"
}

/// An icon sized and weighted to sit where a Lucide glyph would.
///
/// Lucide draws on a 24pt grid with a 2pt stroke, which reads a little heavier
/// than SF Symbols at `.regular`, so this leans on `.medium`.
public struct ShadcnIconView: View {
    private let systemName: String
    private let size: CGFloat
    private let weight: Font.Weight

    public init(_ systemName: String, size: CGFloat = 16, weight: Font.Weight = .medium) {
        self.systemName = systemName
        self.size = size
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.86, weight: weight))
            .frame(width: size, height: size)
    }
}
