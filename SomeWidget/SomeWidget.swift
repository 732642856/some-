import SwiftUI
import WidgetKit

struct SomeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SomeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SomeWidgetEntry {
        SomeWidgetEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SomeWidgetEntry) -> Void) {
        completion(SomeWidgetEntry(date: Date(), snapshot: WidgetSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SomeWidgetEntry>) -> Void) {
        let date = Date()
        let entry = SomeWidgetEntry(date: date, snapshot: WidgetSnapshotStore.read())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: date) ?? date.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct SomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SomeWidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SomeWidgetPalette.blush,
                    SomeWidgetPalette.mist,
                    SomeWidgetPalette.lilac
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            content
                .padding(14)
        }
        .widgetURL(SomeWidgetLinks.home)
    }

    @ViewBuilder
    private var content: some View {
        if family == .systemMedium {
            mediumContent
        } else {
            smallContent
        }
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Spacer(minLength: 4)
            Text(entry.snapshot.recentItems.first?.title ?? "写下这一刻")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(SomeWidgetPalette.ink)
                .lineLimit(3)
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                countPill(value: entry.snapshot.todayCount, label: "今日")
                countPill(value: entry.snapshot.activeCount, label: "全部")
            }
        }
    }

    private var mediumContent: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                header
                HStack(spacing: 8) {
                    quickLink("记录", systemImage: "square.and.pencil", url: SomeWidgetLinks.home)
                    quickLink("专注", systemImage: "moon.stars", url: SomeWidgetLinks.zen)
                    quickLink("搜索", systemImage: "magnifyingglass", url: SomeWidgetLinks.search)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    countPill(value: entry.snapshot.todayCount, label: "今日")
                    countPill(value: entry.snapshot.activeCount, label: "全部")
                }
            }
            .frame(maxWidth: 118, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.snapshot.recentItems.prefix(3)) { item in
                    Link(destination: SomeWidgetLinks.openMemo(item.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(SomeWidgetPalette.ink)
                                .lineLimit(2)
                            if let tag = item.tags.first {
                                Text("#\(tag)")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(SomeWidgetPalette.subtle)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(SomeWidgetPalette.card.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                if entry.snapshot.recentItems.isEmpty {
                    Text("还没有记录")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(SomeWidgetPalette.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SomeWidgetPalette.accent)
            Text("some")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(SomeWidgetPalette.ink)
        }
    }

    private func countPill(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
        }
        .foregroundColor(SomeWidgetPalette.ink)
        .frame(width: 44, height: 36, alignment: .center)
        .background(SomeWidgetPalette.card.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func quickLink(_ title: String, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SomeWidgetPalette.accent)
                .frame(width: 26, height: 26)
                .background(SomeWidgetPalette.card.opacity(0.72))
                .clipShape(Circle())
                .accessibilityLabel(title)
        }
    }
}

@main
struct SomeQuickWidget: Widget {
    let kind = WidgetSnapshotStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SomeWidgetProvider()) { entry in
            SomeWidgetView(entry: entry)
        }
        .configurationDisplayName("some")
        .description("查看最近记录，快速回到记录和专注入口。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private enum SomeWidgetLinks {
    static let home = URL(string: "some://home")!
    static let zen = URL(string: "some://zen")!
    static let search = URL(string: "some://search")!

    static func openMemo(_ id: UUID) -> URL {
        URL(string: "some://open?id=\(id.uuidString)") ?? home
    }
}

private enum SomeWidgetPalette {
    static let blush = Color(red: 0.99, green: 0.94, blue: 0.96)
    static let mist = Color(red: 0.89, green: 0.96, blue: 0.98)
    static let lilac = Color(red: 0.93, green: 0.91, blue: 0.99)
    static let card = Color(red: 1.00, green: 0.99, blue: 0.98)
    static let ink = Color(red: 0.25, green: 0.29, blue: 0.35)
    static let subtle = Color(red: 0.47, green: 0.53, blue: 0.60)
    static let accent = Color(red: 0.43, green: 0.57, blue: 0.72)
}

private extension WidgetSnapshot {
    static let sample = WidgetSnapshot(
        generatedAt: Date(),
        activeCount: 36,
        todayCount: 3,
        recentItems: [
            WidgetSnapshotItem(
                id: UUID(),
                title: "午后灵感：把今天拍到的颜色放进手帐",
                createdAt: Date(),
                updatedAt: Date(),
                tags: ["灵感"]
            ),
            WidgetSnapshotItem(
                id: UUID(),
                title: "工作日志：整理素材库导入反馈",
                createdAt: Date(),
                updatedAt: Date(),
                tags: ["工作"]
            )
        ]
    )
}
