import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReviewSummaryPanel(summary: store.reviewSummary)

            if !store.reviewBacklogMemos.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "旧记录回看", systemImage: "clock.arrow.circlepath")

                    ForEach(store.reviewBacklogMemos) { memo in
                        NavigationLink(value: memo.id) {
                            MemoRowView(memo: memo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !store.onThisDayMemos.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "历史今天", systemImage: "calendar.badge.clock")

                    ForEach(store.onThisDayMemos.prefix(3)) { memo in
                        NavigationLink(value: memo.id) {
                            MemoRowView(memo: memo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(title: "随机回顾", systemImage: "shuffle")
                    Spacer()
                    Button {
                        store.pickRandomReviewMemo()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentGreen)
                    .background(Color.greenTint)
                    .clipShape(Circle())
                    .accessibilityLabel("换一条")
                }

                if let memo = store.reviewMemo {
                    NavigationLink(value: memo.id) {
                        MemoRowView(memo: memo)
                    }
                    .buttonStyle(.plain)
                } else {
                    EmptyStateView(title: "暂无可回顾内容", subtitle: "先记录几条，再回来随机翻翻。")
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "标签入口", systemImage: "tag")

                if store.nestedTagRoots.isEmpty {
                    EmptyStateView(title: "还没有标签", subtitle: "在记录里输入 #标签 或 #项目/子类。")
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(store.nestedTagRoots, id: \.self) { tag in
                            Button {
                                store.selectedTag = tag
                                store.homeMode = .timeline
                            } label: {
                                Text("#\(tag)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.accentGreen)
                                    .padding(.horizontal, 12)
                                    .frame(height: 32)
                                    .background(Color.greenTint)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

private struct ReviewSummaryPanel: View {
    let summary: MemoReviewSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "今日回顾", systemImage: "sparkles")

            HStack(spacing: 10) {
                ReviewMetric(title: "今日", value: "\(summary.todayCount)")
                ReviewMetric(title: "连续", value: "\(summary.currentStreakDays)")
                ReviewMetric(title: "可回顾", value: "\(summary.reviewableCount)")
            }

            Text(summary.prompt)
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

private struct ReviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primaryText)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(Color.primaryText)
    }
}
