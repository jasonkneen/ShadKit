import Foundation

/// A filter chip in the conversation picker — one agent's space, a league,
/// or the workspace's own chats.
public struct AIConversationScope: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// One row in the Chat conversation picker.
public struct AIConversationEntry: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var updatedAt: Date
    public var snippet: String
    public var searchText: String
    public var isArchived: Bool
    /// Which scope this conversation belongs to; nil means "all".
    public var scopeID: String?

    public init(
        id: String,
        title: String,
        updatedAt: Date,
        snippet: String = "",
        searchText: String = "",
        isArchived: Bool = false,
        scopeID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.snippet = snippet
        self.searchText = searchText
        self.isArchived = isArchived
        self.scopeID = scopeID
    }
}

public enum AIConversationTab: String, CaseIterable, Sendable {
    case recents
    case archived
}

public enum AIConversationRange: String, CaseIterable, Sendable {
    case any
    case today
    case week
}

public enum AIConversationQuery {
    public static let pageSize = 25

    public static func filtered(
        _ items: [AIConversationEntry],
        tab: AIConversationTab,
        range: AIConversationRange,
        search: String,
        scopeID: String? = nil,
        now: Date = Date(),
        limit: Int = pageSize
    ) -> [AIConversationEntry] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let ranked = items
            .filter { item in
                switch tab {
                case .recents: !item.isArchived
                case .archived: item.isArchived
                }
            }
            .filter { item in
                guard let scopeID else { return true }
                return item.scopeID == scopeID
            }
            .filter { item in
                switch range {
                case .any: true
                case .today: item.updatedAt >= startOfToday
                case .week: item.updatedAt >= weekAgo
                }
            }
            .filter { item in
                guard !needle.isEmpty else { return true }
                return item.title.localizedCaseInsensitiveContains(needle)
                    || item.snippet.localizedCaseInsensitiveContains(needle)
                    || item.searchText.localizedCaseInsensitiveContains(needle)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        return Array(ranked.prefix(max(limit, 0)))
    }

    public static func relativeTime(from date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 45 { return "just now" }
        if seconds < 90 { return "1 min ago" }
        if seconds < 3600 {
            return "\(Int((seconds / 60).rounded())) min ago"
        }
        if seconds < 5400 { return "1 hour ago" }
        if seconds < 86_400 {
            return "\(Int((seconds / 3600).rounded())) hours ago"
        }
        if seconds < 172_800 { return "yesterday" }
        if seconds < 604_800 {
            return "\(Int((seconds / 86_400).rounded())) days ago"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
