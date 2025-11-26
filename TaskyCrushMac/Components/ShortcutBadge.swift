import SwiftUI

struct ShortcutBadge: View {
    let number: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("\(number)")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.75) : Color.white.opacity(0.9))
            )
            .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
            .overlay(
                Capsule().stroke(Color.primary.opacity(0.1))
            )
    }
}
