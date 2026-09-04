import ShadcnUI
import SwiftUI

/// `state` for an ``AIAttachmentChip``. Mirrors legion's `Attachment`
/// `data-state`: `idle` gets a dashed border, `error` a danger-tinted one,
/// and `uploading`/`processing` swap the leading icon for a spinner.
public enum AIAttachmentChipState: String, Sendable, CaseIterable {
    case idle
    case uploading
    case processing
    case error
    case done
}

/// The composer's pending-attachment chip — a ~224pt-wide horizontal
/// `rounded-xl border` row: a small leading icon/thumbnail, a filename +
/// byte-size (or error text) column, and a remove button.
///
/// Ported from legion's `Attachment size="sm"` + `AttachmentMedia` /
/// `AttachmentContent` / `AttachmentActions`
/// (packages/ui/src/components/ui/attachment.tsx), as used by
/// `PendingAttachmentItem` in src/components/chat/composer.tsx. This is
/// distinct from ``AIMessageAttachment``, which is the 96x96 tile used for
/// attachments already inline in a sent message — that one is unchanged.
public struct AIAttachmentChip: View {
    private let filename: String
    private let byteSize: Int?
    private let image: Image?
    private let state: AIAttachmentChipState
    private let errorText: String?
    private let onRemove: (() -> Void)?

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    public init(
        filename: String,
        byteSize: Int? = nil,
        image: Image? = nil,
        state: AIAttachmentChipState = .done,
        errorText: String? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.filename = filename
        self.byteSize = byteSize
        self.image = image
        self.state = state
        self.errorText = errorText
        self.onRemove = onRemove
    }

    private var description: String {
        if state == .error, let errorText {
            return errorText
        }
        if let byteSize {
            return Self.formatBytes(byteSize)
        }
        return ""
    }

    private var borderColor: Color {
        switch state {
        case .error: AITailwindColor.red600.opacity(0.3)
        case .idle: palette.border
        default: palette.border
        }
    }

    public var body: some View {
        HStack(spacing: Space.x2_5) {
            media
            VStack(alignment: .leading, spacing: 0) {
                Text(filename)
                    .font(theme.typography.sans(theme.typography.xs, weight: .medium))
                    .foregroundStyle(palette.foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !description.isEmpty {
                    Text(description)
                        .font(theme.typography.sans(theme.typography.xs))
                        .foregroundStyle(
                            state == .error
                                ? AITailwindColor.red600.opacity(0.8)
                                : palette.mutedForeground
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, Space.x0_5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if let onRemove {
                ShadcnButton(icon: ShadcnIcon.xMark, variant: .ghost, size: .iconXS, action: onRemove)
                    .accessibilityLabel("Remove \(filename)")
            }
        }
        .padding(.horizontal, Space.x2)
        .padding(.vertical, Space.x1_5)
        .frame(width: 224)
        .background(palette.card)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .strokeBorder(
                    borderColor,
                    style: StrokeStyle(lineWidth: 1, dash: state == .idle ? [4, 3] : [])
                )
        )
    }

    @ViewBuilder
    private var media: some View {
        ZStack {
            (state == .error ? AITailwindColor.red600.opacity(0.1) : palette.muted)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous))

            switch state {
            case .uploading, .processing:
                ProgressView()
                    .controlSize(.small)
            case .error:
                ShadcnIconView(ShadcnIcon.alertTriangle, size: 14)
                    .foregroundStyle(AITailwindColor.red600)
            default:
                if let image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.lg, style: .continuous))
                } else {
                    ShadcnIconView(ShadcnIcon.file, size: 14)
                        .foregroundStyle(palette.mutedForeground)
                }
            }
        }
        .frame(width: 32, height: 32)
    }

    /// Mirrors legion's `formatBytes` (src/lib/format.ts): binary units,
    /// one decimal place above the first step.
    static func formatBytes(_ size: Int) -> String {
        guard size > 0 else { return "0 B" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        let exponent = min(units.count - 1, Int(log(Double(size)) / log(1024)))
        let value = Double(size) / pow(1024, Double(exponent))
        let formatted = exponent == 0 ? "\(Int(value))" : String(format: "%.1f", value)
        return "\(formatted) \(units[exponent])"
    }
}
