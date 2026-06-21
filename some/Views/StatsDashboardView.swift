import SwiftUI

struct StatsDashboardView: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                StatPanel(title: "全部记录", value: "\(store.activeCount)", systemImage: "tray.full")
                StatPanel(title: "标签数", value: "\(store.activeTags.count)", systemImage: "tag")
                StatPanel(title: "今日记录", value: "\(store.todayCount)", systemImage: "sun.max")
                StatPanel(title: "置顶记录", value: "\(store.pinnedCount)", systemImage: "pin")
            }

            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "记录热力", systemImage: "square.grid.3x3")
                MemoHeatmap(stats: store.dailyStats())
                    .frame(height: 112)
            }
            .padding(16)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.border, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "高频标签", systemImage: "number")
                if topTags.isEmpty {
                    EmptyStateView(title: "还没有标签", subtitle: "用 #标签 开始沉淀主题。")
                } else {
                    ForEach(topTags) { item in
                        HStack {
                            Text("#\(item.tag)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.primaryText)
                            Spacer()
                            Text("\(item.count)")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.accentGreen)
                        }
                        .padding(14)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var topTags: [TagUsage] {
        let pairs = store.activeMemos.flatMap(\.tags)
        let grouped = Dictionary(grouping: pairs, by: { $0 })
        return grouped
            .map { TagUsage(tag: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
                }
                return $0.count > $1.count
            }
            .prefix(8)
            .map { $0 }
    }
}

private struct TagUsage: Identifiable {
    let tag: String
    let count: Int

    var id: String { tag }
}

private struct StatPanel: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentGreen)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primaryText)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

private struct MemoHeatmap: View {
    let stats: [DailyMemoStat]
    private let rows = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        GeometryReader { geometry in
            let cell = max(8, min(14, (geometry.size.height - 24) / 7))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, spacing: 4) {
                    ForEach(stats) { stat in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color(for: stat.count))
                            .frame(width: cell, height: cell)
                            .accessibilityLabel("\(DateFormatters.compactDay.string(from: stat.date)) \(stat.count) 条")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0:
            return Color.subtleSurface
        case 1:
            return Color.greenTint
        case 2:
            return Color.accentGreen.opacity(0.55)
        case 3...4:
            return Color.accentGreen.opacity(0.78)
        default:
            return Color.accentGreen
        }
    }
}
