import SwiftUI

struct TagFilterView: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        if !store.allTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TagChip(title: "全部", isSelected: store.selectedTag == nil) {
                        store.clearTagFilter()
                    }

                    ForEach(store.allTags, id: \.self) { tag in
                        TagChip(title: "#\(tag)", isSelected: store.selectedTag == tag) {
                            store.selectedTag = tag
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct TagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primaryText)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(isSelected ? Color.accentGreen : Color.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
