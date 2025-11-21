import SwiftUI
import SwiftData

struct MacProject: Identifiable, Equatable {
    let id: UUID
    var name: String
    var emoji: String

    init(id: UUID = UUID(), name: String, emoji: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
    }

    init(record: ProjectRecord) {
        self.init(id: record.id, name: record.name, emoji: record.emoji)
    }
}

struct MacHomeView: View {
    enum TaskFilter: Equatable {
        case all
        case inbox
        case project(UUID)

        var title: String {
            switch self {
            case .all: return "Todos"
            case .inbox: return "Inbox"
            case .project: return "Proyecto"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var projectRecords: [ProjectRecord]
    @Query private var taskRecords: [TaskRecord]
    @State private var selection: TaskFilter = .all
    @State private var showingAddProject = false
    @State private var persistenceError: PersistenceError?

    init() {
        _projectRecords = Query(
            sort: [
                SortDescriptor(\.name, order: .forward)
            ]
        )
        _taskRecords = Query(
            sort: [
                SortDescriptor(\.dueDate, order: .forward)
            ]
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            projectsRow

            Divider()

            tasksSection
        }
        .padding(24)
        .frame(minWidth: 900, minHeight: 560)
        .sheet(isPresented: $showingAddProject) {
            MacAddProjectView { name, emoji in
                if let newId = addProject(name: name, emoji: emoji) {
                    selection = .project(newId)
                }
            }
            .frame(minWidth: 360, minHeight: 280)
        }
        .alert("No pudimos guardar tus cambios", isPresented: .init(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: {
            if let message = persistenceError?.message {
                Text(message)
            }
        }
        .onChange(of: projectRecords.map(\.id)) { ids in
            guard case let .project(id) = selection, !ids.contains(id) else { return }
            selection = .all
        }
    }

    private var projectsRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    StoryItem(
                        title: "Nuevo",
                        emoji: "＋",
                        isSelected: false
                    ) {
                        showingAddProject = true
                    }

                    StoryItem(
                        title: "Todos",
                        emoji: "⭐️",
                        isSelected: selection == .all
                    ) {
                        selection = .all
                    }

                    if hasInboxTasks {
                        StoryItem(
                            title: "Inbox",
                            emoji: "📥",
                            isSelected: selection == .inbox
                        ) {
                            selection = .inbox
                        }
                    }

                    ForEach(projects) { project in
                        ProjectStoryItem(
                            project: project,
                            isSelected: selection == .project(project.id)
                        ) {
                            toggleSelection(for: project.id)
                        }
                    }
                }
                .padding(.vertical, 0)
                .padding(.leading, 4)
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sectionTitle)
                .font(.title3)
                .bold()

            if filteredTasks.isEmpty {
                ContentUnavailableView(
                    "Sin tareas",
                    systemImage: "checkmark.circle",
                    description: Text("Crea tareas en tu iPhone/iPad y se sincronizarán aquí automáticamente.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(filteredTasks) { task in
                            MacTaskRow(
                                task: task,
                                project: resolvedProject(for: task),
                                onToggleDone: { toggleCompletion(for: task) }
                            )
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var projects: [MacProject] {
        projectRecords
            .sorted(by: projectSortComparator)
            .map(MacProject.init(record:))
    }

    private var filteredTasks: [TaskRecord] {
        let base = taskRecords.filter { !$0.isDone }
        switch selection {
        case .all:
            return base
        case .inbox:
            return base.filter { $0.projectId == nil }
        case let .project(id):
            return base.filter { $0.projectId == id }
        }
    }

    private var hasInboxTasks: Bool {
        taskRecords.contains { !$0.isDone && $0.projectId == nil }
    }

    private var sectionTitle: String {
        switch selection {
        case .all:
            return "Tasks"
        case .inbox:
            return "Inbox"
        case let .project(id):
            return projectRecords.first(where: { $0.id == id })?.name ?? "Proyecto"
        }
    }

    private func toggleSelection(for projectID: UUID) {
        if selection == .project(projectID) {
            selection = .all
        } else {
            selection = .project(projectID)
        }
    }

    @discardableResult
    private func addProject(name: String, emoji: String) -> UUID? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedEmoji.isEmpty else { return nil }
        let nextSortOrder = (projectRecords.compactMap { $0.sortOrder }.max() ?? -1) + 1
        let record = ProjectRecord(name: trimmedName, emoji: trimmedEmoji, sortOrder: nextSortOrder)
        modelContext.insert(record)
        do {
            try modelContext.save()
            return record.id
        } catch {
            modelContext.delete(record)
            persistenceError = PersistenceError(message: error.localizedDescription)
            return nil
        }
    }

    private func toggleCompletion(for task: TaskRecord) {
        let previousDone = task.isDone
        let previousCompletedAt = task.completedAt
        task.isDone.toggle()
        task.completedAt = task.isDone ? Date() : nil
        do {
            try modelContext.save()
        } catch {
            task.isDone = previousDone
            task.completedAt = previousCompletedAt
            persistenceError = PersistenceError(message: error.localizedDescription)
        }
    }

    private func resolvedProject(for task: TaskRecord) -> ProjectItem? {
        if let id = task.projectId, let record = projectRecords.first(where: { $0.id == id }) {
            return ProjectItem(record: record)
        }
        return task.projectSnapshot
    }

    private func projectSortComparator(_ lhs: ProjectRecord, _ rhs: ProjectRecord) -> Bool {
        switch (lhs.sortOrder, rhs.sortOrder) {
        case let (l?, r?): return l < r
        case (nil, nil): return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case (nil, _?): return false
        case (_?, nil): return true
        }
    }

    private struct PersistenceError: Identifiable {
        let id = UUID()
        let message: String
    }
}

private struct MacTaskRow: View {
    let task: TaskRecord
    let project: ProjectItem?
    var onToggleDone: () -> Void

    private static let dueFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleDone) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(task.isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isDone, color: .secondary)

                HStack(spacing: 8) {
                    Label {
                        Text(Self.dueFormatter.string(from: task.dueDate))
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if let tag = task.tag, !tag.isEmpty {
                        Label(tag, systemImage: "tag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let project {
                    Label {
                        Text(project.name)
                    } icon: {
                        Text(project.emoji)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

private extension ProjectItem {
    init(record: ProjectRecord) {
        self.init(
            id: record.id,
            name: record.name,
            emoji: record.emoji,
            colorName: record.colorName,
            sortOrder: record.sortOrder,
            tags: record.tags
        )
    }
}
