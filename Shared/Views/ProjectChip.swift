import SwiftUI

struct ProjectChip: View {
    let project: ProjectItem
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(project.emoji)
                Text(project.name)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .overlay(
                Capsule().stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3))
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct NewProjectChip: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("+ Project")
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .overlay(
                    Capsule().stroke(Color.secondary.opacity(0.3))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct NewTagChip: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("+ Tag")
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .overlay(
                    Capsule().stroke(Color.secondary.opacity(0.3))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? color.opacity(0.2) : Color.clear)
                .overlay(
                    Capsule().stroke(isSelected ? color : Color.secondary.opacity(0.3))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
