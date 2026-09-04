import ShadcnUI
import SwiftUI

/// A workspace or a directory-browser row: a local folder, flagged when it's
/// a git checkout so the picker can swap icons.
public struct AIWorkspaceEntry: Identifiable, Equatable, Sendable {
    public var name: String
    public var path: String
    public var isGit: Bool

    public var id: String { path }

    public init(name: String, path: String, isGit: Bool = false) {
        self.name = name
        self.path = path
        self.isGit = isGit
    }
}

/// One directory listing: where it is, its parent (nil at the root), and the
/// folders inside it.
public struct AIWorkspaceBrowse: Equatable, Sendable {
    public var path: String
    public var parent: String?
    public var entries: [AIWorkspaceEntry]

    public init(path: String, parent: String?, entries: [AIWorkspaceEntry]) {
        self.path = path
        self.parent = parent
        self.entries = entries
    }
}

/// Ports `workspace-picker.tsx`: a pill trigger showing the current
/// workspace, opening a dialog with a path field, a recents list, and a
/// directory browser. The host owns lookup, persistence, and validation —
/// this view only takes data in and reports choices/browse requests out.
public struct AIWorkspacePicker: View {
    @Binding private var isPresented: Bool
    private let current: AIWorkspaceEntry?
    private let recents: [AIWorkspaceEntry]
    private let browse: AIWorkspaceBrowse?
    private let isBusy: Bool
    private let errorMessage: String?
    private let onChoose: (String) -> Void
    private let onBrowse: (String) -> Void

    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    @State private var path: String = ""

    public init(
        isPresented: Binding<Bool>,
        current: AIWorkspaceEntry?,
        recents: [AIWorkspaceEntry] = [],
        browse: AIWorkspaceBrowse? = nil,
        isBusy: Bool = false,
        errorMessage: String? = nil,
        onChoose: @escaping (String) -> Void,
        onBrowse: @escaping (String) -> Void
    ) {
        self._isPresented = isPresented
        self.current = current
        self.recents = recents
        self.browse = browse
        self.isBusy = isBusy
        self.errorMessage = errorMessage
        self.onChoose = onChoose
        self.onBrowse = onBrowse
    }

    private var triggerLabel: String { current?.name ?? "This app" }

    public var body: some View {
        Button {
            path = current?.path ?? ""
            isPresented = true
        } label: {
            HStack(spacing: Space.x1_5) {
                Image(systemName: current?.isGit == true ? "arrow.triangle.branch" : ShadcnIcon.folder)
                    .font(.system(size: 11))
                Text(triggerLabel)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(palette.mutedForeground)
            .padding(.horizontal, Space.x2)
            .padding(.vertical, 2)
            .background(Capsule().fill(palette.secondary))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 192)
        .help(current?.path ?? "Choose a local repo")
        .shadcnDialog(isPresented: $isPresented, width: 512) {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            VStack(alignment: .leading, spacing: Space.x1) {
                ShadcnCardTitle("Workspace")
                ShadcnCardDescription(
                    "Seats read and edit this folder — files, git, and @ mentions. Pick a local repo on this machine."
                )
            }

            HStack(spacing: Space.x2) {
                ShadcnTextField("/Users/you/src/the-repo", text: $path, onSubmit: { onChoose(path) })
                ShadcnButton("Open", size: .medium) { onChoose(path) }
                    .disabled(isBusy || path.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.destructive)
            }

            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: Space.x1) {
                    Text("RECENT")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.mutedForeground)

                    VStack(spacing: 2) {
                        ForEach(recents) { entry in
                            recentRow(entry)
                        }
                    }
                }
            }

            if let browse {
                browsePane(browse)
            }
        }
    }

    private func recentRow(_ entry: AIWorkspaceEntry) -> some View {
        Button { onChoose(entry.path) } label: {
            HStack(spacing: Space.x2) {
                Image(systemName: entry.isGit ? "arrow.triangle.branch" : ShadcnIcon.folder)
                Text(entry.name).font(theme.typography.sans(theme.typography.sm)).fontWeight(.medium)
                Spacer(minLength: Space.x2)
                Text(entry.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.mutedForeground)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: 160, alignment: .trailing)
            }
            .padding(.horizontal, Space.x2)
            .padding(.vertical, Space.x1_5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.foreground)
    }

    private func browsePane(_ browse: AIWorkspaceBrowse) -> some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            HStack(spacing: Space.x1) {
                Button { if let parent = browse.parent { onBrowse(parent) } } label: {
                    Image(systemName: ShadcnIcon.chevronLeft)
                }
                .buttonStyle(.plain)
                .disabled(browse.parent == nil)

                Button { onBrowse("") } label: {
                    Image(systemName: "house")
                }
                .buttonStyle(.plain)

                Text(browse.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.mutedForeground)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ShadcnButton("Use this folder", variant: .secondary, size: .small) { onChoose(browse.path) }
            }

            Group {
                if browse.entries.isEmpty {
                    Text("No folders here.")
                        .font(theme.typography.sans(theme.typography.sm))
                        .foregroundStyle(palette.mutedForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.x4)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(browse.entries) { entry in
                                Button {
                                    path = entry.path
                                    onBrowse(entry.path)
                                } label: {
                                    HStack(spacing: Space.x2) {
                                        Image(systemName: entry.isGit ? "arrow.triangle.branch" : ShadcnIcon.folder)
                                            .foregroundStyle(palette.mutedForeground)
                                        Text(entry.name)
                                            .font(theme.typography.sans(theme.typography.sm))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if entry.isGit {
                                            Text("git")
                                                .font(.system(size: 11))
                                                .foregroundStyle(palette.mutedForeground)
                                        }
                                    }
                                    .padding(.horizontal, Space.x2_5)
                                    .padding(.vertical, Space.x1_5)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture(count: 2).onEnded { onChoose(entry.path) })
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 224)
            .shadcnBorder(palette.border, cornerRadius: theme.radius.lg)
        }
    }
}
