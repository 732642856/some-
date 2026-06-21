import SwiftUI

struct EmptyStateView: View {
    var title = "还没有匹配的闪念"
    var subtitle = "换个关键词，或者先写下一条。"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.accentGreen)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}
