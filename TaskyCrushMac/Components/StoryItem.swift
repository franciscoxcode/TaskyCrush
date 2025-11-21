import SwiftUI

struct StoryItem: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    var selectedRingGradient: AngularGradient? = nil
    var onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Text(emoji).font(.system(size: 20))
                }
                .frame(width: selectedRingGradient != nil ? 48 : 46, height: selectedRingGradient != nil ? 48 : 46)
                .overlay(
                    Circle().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if isSelected, let gradient = selectedRingGradient {
                            Circle().strokeBorder(gradient, lineWidth: 4)
                        } else {
                            Circle().stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                        }
                    }
                )
                .padding(.top, selectedRingGradient != nil ? 2 : 0)

                let chipBg = (colorScheme == .dark) ? Color.white.opacity(0.92) : Color.black
                let chipFg = (colorScheme == .dark) ? Color.black : Color.white
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? chipFg : Color.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Group {
                            if isSelected {
                                Capsule().fill(chipBg)
                            } else {
                                Capsule().fill(Color.clear)
                            }
                        }
                    )
                    .overlay(
                        Group {
                            if isSelected {
                                Capsule().stroke(Color.secondary.opacity(0.25))
                            }
                        }
                    )
                    .clipShape(Capsule())
                    .lineLimit(1)
                    .frame(width: 64)
            }
        }
        .buttonStyle(.plain)
    }
}
