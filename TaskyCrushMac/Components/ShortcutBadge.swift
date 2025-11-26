import SwiftUI

struct ShortcutBadge: View {
    let number: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("\(number)")
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.85) : Color.white)
            )
            .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
            .overlay(
                Capsule().stroke(Color.primary.opacity(0.12))
            )
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
}
