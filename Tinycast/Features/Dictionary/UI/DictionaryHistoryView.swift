import SwiftUI

struct DictionaryHistoryList: View {
    @Environment(\.metrics) private var metrics
    let results: [DictionaryHistoryEntry]
    let selectedID: DictionaryHistoryEntry.ID?
    let scroll: ScrollIntent
    let onSelect: (DictionaryHistoryEntry) -> Void
    let onActivate: () -> Void
    let onActions: (DictionaryHistoryEntry) -> Void

    private enum Row: Identifiable {
        case header(String)
        case entry(DictionaryHistoryEntry)

        var id: String {
            switch self {
            case .header(let title): "header-" + title
            case .entry(let entry): entry.id.uuidString
            }
        }
    }

    private var rows: [Row] {
        var rows: [Row] = []
        var currentBucket: DateBucket?
        for entry in results {
            let bucket = DateBucket(for: entry.createdAt)
            if bucket != currentBucket {
                rows.append(.header(bucket.title))
                currentBucket = bucket
            }
            rows.append(.entry(entry))
        }
        return rows
    }

    var body: some View {
        let rows = rows
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        switch row {
                        case .header(let title):
                            SectionHeader(title: title, isFirst: row.id == rows.first?.id)
                        case .entry(let entry):
                            DictionaryHistoryRow(entry: entry, selected: entry.id == selectedID)
                                .selectionFrame(entry.id == selectedID)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(entry) }
                                .simultaneousGesture(
                                    TapGesture(count: 2).onEnded {
                                        onSelect(entry)
                                        onActivate()
                                    }
                                )
                                .onRightClick { onActions(entry) }
                        }
                    }
                }
                .padding(.horizontal, metrics.spacing.md)
                .padding(.top, metrics.spacing.xs)
                .padding(.bottom, metrics.spacing.md)
                .hideNativeScrollers()
                .scrollOriginAnchor()
            }
            .edgeDissolve()
            .thinScrollbar()
            .scrollFollowsSelection(
                scroll, row: selectedID?.uuidString,
                atOrigin: selectedID != nil && selectedID == results.first?.id, proxy: proxy)
        }
    }
}

private struct DictionaryHistoryRow: View {
    @Environment(\.metrics) private var metrics
    let entry: DictionaryHistoryEntry
    let selected: Bool
    @State private var hovered = false

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            RoundedRectangle(cornerRadius: metrics.radius.thumbnail, style: .continuous)
                .fill(Theme.Colors.controlSurface)
                .frame(width: metrics.size.rowIcon, height: metrics.size.rowIcon)
                .overlay(
                    Image(systemName: "book.closed")
                        .font(.system(size: 12))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary))
            Text(entry.term)
                .font(metrics.typography.rowTitle.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: metrics.spacing.xl)
            Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                .font(metrics.typography.keyCap)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.vertical, metrics.spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous).fill(fill)
        )
        .armedHover($hovered)
    }
}
