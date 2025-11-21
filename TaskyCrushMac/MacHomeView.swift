import SwiftUI

struct MacProject: Identifiable, Equatable {
    let id: UUID
    var name: String
    var emoji: String

    init(id: UUID = UUID(), name: String, emoji: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
    }
}

struct MacHomeView: View {
    @State private var projects: [MacProject] = [
        MacProject(name: "Inbox", emoji: "📥"),
        MacProject(name: "Design", emoji: "🎨"),
        MacProject(name: "Dev", emoji: "💻"),
        MacProject(name: "Personal", emoji: "🌿")
    ]
    @State private var selectedProjectID: UUID? = nil
    @State private var showingAddProject = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Tus proyectos")
                .font(.title2)
                .bold()
                .padding(.horizontal, 4)

            projectsRow

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 480)
        .sheet(isPresented: $showingAddProject) {
            MacAddProjectView { name, emoji in
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty, !emoji.isEmpty else { return }
                let newProject = MacProject(name: trimmedName, emoji: emoji)
                projects.append(newProject)
                selectedProjectID = newProject.id
            }
            .frame(minWidth: 360, minHeight: 280)
        }
    }

    private var projectsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                StoryItem(
                    title: "New",
                    emoji: "＋",
                    isSelected: false
                ) {
                    showingAddProject = true
                }

                ForEach(projects) { project in
                    ProjectStoryItem(
                        project: project,
                        isSelected: selectedProjectID == project.id,
                        onTap: {
                            toggleSelection(for: project)
                        }
                    )
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 4)
        }
    }

    private func toggleSelection(for project: MacProject) {
        if selectedProjectID == project.id {
            selectedProjectID = nil
        } else {
            selectedProjectID = project.id
        }
    }
}
