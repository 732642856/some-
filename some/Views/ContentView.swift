import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: MemoStore
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        HeaderView()
                        HomeModePicker()

                        switch store.homeMode {
                        case .timeline:
                            QuickCaptureView()
                            TagFilterView()
                            MemoListView(memos: store.filteredMemos, emptyTitle: "还没有匹配的闪念")
                        case .ai:
                            AIWorkspaceView()
                        case .review:
                            ReviewView()
                        case .stats:
                            StatsDashboardView()
                        case .archive:
                            TagFilterView()
                            MemoListView(memos: store.archivedMemos, emptyTitle: "归档里还没有内容")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("some")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $store.searchText, prompt: "搜索内容、#标签或 is:pinned")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let memo = store.memos.first(where: { $0.id == id }) {
                    MemoDetailView(memo: memo)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(headerTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primaryText)

            HStack(spacing: 10) {
                StatBadge(title: "记录", value: "\(store.activeCount)", systemImage: "tray.full")
                StatBadge(title: "今日", value: "\(store.todayCount)", systemImage: "sun.max")
                StatBadge(title: "归档", value: "\(store.archivedCount)", systemImage: "archivebox")
            }
        }
        .padding(.top, 6)
    }

    private var headerTitle: String {
        switch store.homeMode {
        case .timeline: return "今天先记下来"
        case .ai: return "让 AI 帮你排版"
        case .review: return "让旧念头冒泡"
        case .stats: return "看见记录习惯"
        case .archive: return "暂时收进抽屉"
        }
    }
}

private struct StatBadge: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentGreen)
            Text(title)
                .foregroundStyle(Color.secondaryText)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(Color.primaryText)
        }
        .font(.footnote)
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(Color.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

private struct HomeModePicker: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MemoHomeMode.allCases) { mode in
                Button {
                    store.homeMode = mode
                    if mode == .review, store.reviewMemo == nil {
                        store.pickRandomReviewMemo()
                    }
                } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(store.homeMode == mode ? Color.accentGreen : Color.clear)
                        .foregroundStyle(store.homeMode == mode ? Color.white : Color.secondaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.title)
            }
        }
        .padding(4)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

private struct MemoListView: View {
    let memos: [Memo]
    let emptyTitle: String

    var body: some View {
        if memos.isEmpty {
            EmptyStateView(title: emptyTitle)
                .padding(.top, 12)
        } else {
            ForEach(memos) { memo in
                NavigationLink(value: memo.id) {
                    MemoRowView(memo: memo)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
