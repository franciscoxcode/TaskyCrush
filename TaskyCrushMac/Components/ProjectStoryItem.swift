import SwiftUI

struct ProjectStoryItem: View {
    let project: MacProject
    let isSelected: Bool
    var dimmed: Bool = false
    var hasActiveForScope: Bool = false
    var onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Text(project.emoji)
                        .font(.system(size: 20))
                }
                .frame(width: 48, height: 48)
                .overlay(
                    Circle().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if isSelected {
                            Circle()
                                .strokeBorder(
                                    AngularGradient(
                                        gradient: Gradient(colors: [Color.yellow, Color.green, Color.yellow]),
                                        center: .center
                                    ),
                                    lineWidth: 4
                                )
                        } else if hasActiveForScope {
                            Circle()
                                .strokeBorder(
                                    AngularGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple, Color.blue]),
                                        center: .center
                                    ),
                                    lineWidth: 4
                                )
                        }
                    }
                )
                .padding(.top, 2)

                let chipBg = (colorScheme == .dark) ? Color.white.opacity(0.92) : Color.black
                let chipFg = (colorScheme == .dark) ? Color.black : Color.white
                Text(project.name)
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
            .opacity((dimmed && !isSelected) ? 0.45 : 1)
        }
        .buttonStyle(.plain)
    }
}
