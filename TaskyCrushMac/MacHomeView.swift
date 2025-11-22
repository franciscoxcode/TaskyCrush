import SwiftUI
import SwiftData
import AppKit

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

    enum DateShortcut: CaseIterable, Identifiable {
        case pickDate
        case anytime
        case today
        case tomorrow
        case weekend

        var id: Self { self }

        var title: String {
            switch self {
            case .pickDate: return "Pick Date"
            case .anytime: return "Anytime"
            case .today: return "Today"
            case .tomorrow: return "Tomorrow"
            case .weekend: return "Weekend"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var projectRecords: [ProjectRecord]
    @Query private var taskRecords: [TaskRecord]
    @State private var selection: TaskFilter = .all
    @State private var showingAddProject = false
    @State private var editingProject: MacProject?
    @State private var persistenceError: PersistenceError?
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var dateShortcut: DateShortcut = .today
    @State private var selectedNoteTaskId: UUID? = nil

    private static let noteHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

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

            if dateShortcut == .pickDate {
                HStack(alignment: .top, spacing: 4) {
                    calendarView

                    tasksSection
                        .frame(maxWidth: .infinity)
                        .padding(.leading, 16)
                }
            } else {
                tasksSection
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(minWidth: 900, minHeight: 560)
        .sheet(isPresented: $showingAddProject) {
            MacAddProjectView { name, emoji in
                if let newId = addProject(name: name, emoji: emoji) {
                    selection = .project(newId)
                }
            }
        }
        .sheet(item: $editingProject) { project in
            MacEditProjectView(project: project) { name, emoji in
                updateProject(id: project.id, name: name, emoji: emoji)
            } onDelete: {
                deleteProject(id: project.id)
            }
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
        .onChange(of: displayedTasks.map(\.id)) { ids in
            guard let selectedId = selectedNoteTaskId else { return }
            if !ids.contains(selectedId) {
                selectedNoteTaskId = nil
            }
        }
    }

    private var projectsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .onSecondaryClick {
                            editingProject = project
                        }
                    }
                }
                .padding(.vertical, 0)
                .padding(.leading, 4)
            }

            dateShortcutsRow
        }
    }

    private var dateShortcutsRow: some View {
        HStack(spacing: 12) {
            ForEach(DateShortcut.allCases) { shortcut in
                Button {
                    if shortcut == .pickDate, dateShortcut == .pickDate {
                        dateShortcut = .today
                    } else {
                        dateShortcut = shortcut
                    }
                } label: {
                    Text(shortcut.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(shortcut == dateShortcut ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 4)
        .padding(.top, 8)
    }

    private var calendarView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendario")
                .font(.title3)
                .bold()

            DatePicker(
                "Selecciona una fecha",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .scaleEffect(1.05, anchor: .topLeading)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            tasksHeader

            if displayedTasks.isEmpty {
                ContentUnavailableView(
                    "Sin tareas",
                    systemImage: "checkmark.circle",
                    description: Text("Crea tareas en tu iPhone/iPad y se sincronizarán aquí automáticamente.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                tasksColumns
            }
        }
    }

    @ViewBuilder
    private var tasksHeader: some View {
        if let noteTask = selectedNoteTask {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    sectionHeaderStack
                        .frame(minWidth: 320, maxWidth: .infinity, alignment: .leading)

                    noteHeader(for: noteTask)
                        .frame(minWidth: 320, maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeaderStack
                    noteHeader(for: noteTask)
                }
            }
        } else {
            sectionHeaderStack
        }
    }

    private var sectionHeaderStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sectionTitle)
                .font(.title3)
                .bold()

            Text(dateSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func noteHeader(for task: TaskRecord) -> some View {
        let project = resolvedProject(for: task)
        return VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.headline)
                .multilineTextAlignment(.leading)

            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 12) {
                    Label {
                        Text(Self.noteHeaderDateFormatter.string(from: task.dueDate))
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    noteProjectLabel(for: project)
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedNoteTaskId = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close note column")
            }
        }
    }

    @ViewBuilder
    private func noteProjectLabel(for project: ProjectItem?) -> some View {
        if let project {
            Label {
                Text(project.name)
            } icon: {
                Text(project.emoji)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } else {
            Label("No project", systemImage: "tray")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var tasksColumns: some View {
        if let noteTask = selectedNoteTask {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    taskListView()
                        .frame(minWidth: 320, maxWidth: .infinity, alignment: .topLeading)

                    noteSidebarView(for: noteTask)
                        .frame(minWidth: 320, maxWidth: .infinity, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 16) {
                    taskListView()

                    noteSidebarView(for: noteTask)
                }
            }
        } else {
            taskListView()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func taskListView() -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(displayedTasks) { task in
                    taskCard(for: task)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func noteSidebarView(for task: TaskRecord) -> some View {
        MacNoteSidebar(
            task: task,
            onAutoSave: { text in saveNote(for: task, text: text) }
        )
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.05))
        )
        .id(task.id)
    }

    private func taskCard(for task: TaskRecord) -> some View {
        let isSelected = task.id == selectedNoteTaskId
        return MacTaskRow(
            task: task,
            project: resolvedProject(for: task),
            onToggleDone: { toggleCompletion(for: task) }
        )
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { handleTaskSelection(task) }
    }

    private var selectedNoteTask: TaskRecord? {
        guard let id = selectedNoteTaskId else { return nil }
        return displayedTasks.first(where: { $0.id == id })
    }

    private func handleTaskSelection(_ task: TaskRecord) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedNoteTaskId == task.id {
                selectedNoteTaskId = nil
            } else {
                selectedNoteTaskId = task.id
            }
        }
    }

    private func saveNote(for task: TaskRecord, text: String) {
        let previousMarkdown = task.noteMarkdown
        let previousUpdatedAt = task.noteUpdatedAt
        task.noteMarkdown = text
        task.noteUpdatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            task.noteMarkdown = previousMarkdown
            task.noteUpdatedAt = previousUpdatedAt
            persistenceError = PersistenceError(message: error.localizedDescription)
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

    private var displayedTasks: [TaskRecord] {
        let calendar = Calendar.current
        switch dateShortcut {
        case .anytime:
            return filteredTasks
        case .today:
            let today = calendar.startOfDay(for: Date())
            return filteredTasks.filter { calendar.isDate($0.dueDate, inSameDayAs: today) }
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) else {
                return []
            }
            return filteredTasks.filter { calendar.isDate($0.dueDate, inSameDayAs: tomorrow) }
        case .weekend:
            return filteredTasks.filter { calendar.isDateInWeekend($0.dueDate) }
        case .pickDate:
            return filteredTasks.filter { calendar.isDate($0.dueDate, inSameDayAs: selectedDate) }
        }
    }

    private var dateSubtitle: String {
        let calendar = Calendar.current
        switch dateShortcut {
        case .anytime:
            return "Anytime"
        case .today:
            let today = calendar.startOfDay(for: Date())
            return today.formatted(date: .complete, time: .omitted)
        case .tomorrow:
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) {
                return tomorrow.formatted(date: .complete, time: .omitted)
            }
            return "Tomorrow"
        case .weekend:
            return "Weekend"
        case .pickDate:
            return selectedDate.formatted(date: .complete, time: .omitted)
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

    private func updateProject(id: UUID, name: String, emoji: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedEmoji.isEmpty else { return }
        guard let record = projectRecords.first(where: { $0.id == id }) else { return }
        let previousName = record.name
        let previousEmoji = record.emoji
        record.name = trimmedName
        record.emoji = trimmedEmoji
        do {
            try modelContext.save()
        } catch {
            record.name = previousName
            record.emoji = previousEmoji
            persistenceError = PersistenceError(message: error.localizedDescription)
        }
    }

    private func deleteProject(id: UUID) {
        guard let record = projectRecords.first(where: { $0.id == id }) else { return }
        let affectedTasks = taskRecords.filter { $0.projectId == id && !$0.isDone }
        let previousAssignments = affectedTasks.map { ($0, $0.projectId, $0.tag) }
        modelContext.delete(record)
        for task in affectedTasks {
            task.projectId = nil
            task.tag = nil
        }
        do {
            try modelContext.save()
            if selection == .project(id) {
                selection = .all
            }
        } catch {
            if record.modelContext == nil {
                modelContext.insert(record)
            }
            for (task, previousProjectId, previousTag) in previousAssignments {
                task.projectId = previousProjectId
                task.tag = previousTag
            }
            persistenceError = PersistenceError(message: error.localizedDescription)
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

private struct MacNoteSidebar: View {
    let task: TaskRecord
    var onAutoSave: (String) -> Void

    @State private var text: String = ""
    @State private var lastSavedText: String = ""
    @State private var lastSavedAt: Date?
    @State private var isSaving: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08))
                    )
                    .frame(minHeight: 260)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Type your note here…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 6) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                Text(statusDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { syncFromTask() }
        .onChange(of: task.id) { _ in syncFromTask() }
        .onChange(of: task.noteMarkdown ?? "") { _ in syncFromTask() }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            autoSaveIfNeeded()
        }
        .onDisappear { autoSaveIfNeeded() }
    }

    private var statusDetailText: String {
        if isSaving { return "Saving…" }
        if text != lastSavedText { return "Unsaved changes" }
        if let saved = lastSavedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Updated \(formatter.localizedString(for: saved, relativeTo: Date()))"
        }
        return "No previous updates"
    }

    private func syncFromTask() {
        let current = task.noteMarkdown ?? ""
        text = current
        lastSavedText = current
        lastSavedAt = task.noteUpdatedAt
    }

    private func autoSaveIfNeeded() {
        guard text != lastSavedText else { return }
        isSaving = true
        onAutoSave(text)
        lastSavedText = text
        lastSavedAt = Date()
        isSaving = false
    }
}

private extension View {
    func onSecondaryClick(perform action: @escaping () -> Void) -> some View {
        modifier(SecondaryClickModifier(action: action))
    }
}

private struct SecondaryClickModifier: ViewModifier {
    var action: () -> Void

    func body(content: Content) -> some View {
        content.overlay(SecondaryClickCaptureView(onSecondaryClick: action))
    }
}

private struct SecondaryClickCaptureView: NSViewRepresentable {
    var onSecondaryClick: () -> Void

    func makeNSView(context: Context) -> SecondaryClickCatcherView {
        let view = SecondaryClickCatcherView()
        view.action = onSecondaryClick
        return view
    }

    func updateNSView(_ nsView: SecondaryClickCatcherView, context: Context) {
        nsView.action = onSecondaryClick
    }
}

private final class SecondaryClickCatcherView: NSView {
    var action: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = window?.currentEvent else { return nil }
        switch event.type {
        case .rightMouseDown, .otherMouseDown:
            return self
        default:
            return nil
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        action?()
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
