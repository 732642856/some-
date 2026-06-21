import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

struct SectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(Color.primaryText)
    }
}
