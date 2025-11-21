//
//  ContentView.swift
//  CodexTestingApp
//
//  Created by Francisco Jean on 15/09/25.
//

import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPresentingAdd = false
    @State private var isPresentingManageProjects = false
    @State private var editingTask: TaskItem?
    @State private var editingProject: ProjectItem?
    @State private var userPoints: Int = 0
    @State private var showingCompletedSheet = false
    @State private var pendingDeleteTask: TaskItem? = nil
    @State private var pendingRescheduleTask: TaskItem? = nil
    @State private var pendingMoveTask: TaskItem? = nil
    @State private var rescheduleDate: Date = TaskItem.defaultDueDate()
    // Prompt for newly generated next occurrence
    @State private var pendingNextOccurrence: TaskItem? = nil
    enum TaskFilter: Equatable {
        case none
        case inbox
        case project(ProjectItem.ID)
    }
    @State private var selectedFilter: TaskFilter = .none
    // New project popup state
    @State private var showingAddProject = false
    @State private var newProjectName: String = ""
    @State private var newProjectEmoji: String = ""
    @State private var newProjectColor: Color? = nil
    @State private var showingEmojiPicker = false
    @State private var isPickingForEdit = false
    // Secondary date scope filter
    enum DateScope: Equatable {
        case anytime
        case today
        case tomorrow
        case weekend
        case custom(Date)
    }
    @State private var dateScope: DateScope = .today
    @State private var showScopeDatePicker = false
    @State private var scopeCustomDate: Date = TaskItem.defaultDueDate()
    // Anchor to trigger recalculation on day/phase changes
    @State private var timeAnchor: Date = Date()
    // Edit project popup state
    @State private var editProjectName: String = ""
    @State private var editProjectEmoji: String = ""
    @State private var editProjectColor: Color? = nil
    @FocusState private var isEditProjectNameFocused: Bool
    @FocusState private var isNewProjectNameFocused: Bool
    // Pending hide window for recently completed tasks
    @State private var pendingHideUntil: [UUID: Date] = [:]
    // Currently focused task note in the side column
    @State private var selectedNoteTaskId: TaskItem.ID? = nil
    // Fallback sheet note editor for compact layouts
    @State private var openNoteTask: TaskItem? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                mainContent
                FloatingAddButton {
                    isPresentingAdd = true
                }
                .padding(.trailing, 36)
                .padding(.bottom, 4)
            }
        }
    }

    // Extract main content to reduce generic depth
    private var mainContent: some View {
        VStack(spacing: 6) {
                TopBarButtons(
                    onReset: {
                        viewModel.resetAndSeedSampleData()
                        userPoints = 0
                        UserDefaults.standard.set(0, forKey: "userPoints")
                    }
                )

                TitleRow(
                    points: userPoints,
                    onManage: { isPresentingManageProjects = true }
                ) { showingCompletedSheet = true }

                // Row 3: projects bar
                StoriesBar(projects: viewModel.projects, hasInbox: hasInbox, selectedFilter: $selectedFilter, onNew: {
                    showingAddProject = true
                }, tasks: viewModel.tasks, dateScope: dateScope, onProjectLongPress: { project in
                    editingProject = project
                    editProjectName = project.name
                    editProjectEmoji = project.emoji
                    editProjectColor = colorFromName(project.colorName)
                })

                DateScopeBar(dateScope: $dateScope, showScopeDatePicker: $showScopeDatePicker, scopeCustomDate: $scopeCustomDate)

                if shouldUseSidebarLayout {
                    GeometryReader { proxy in
                        let spacing: CGFloat = 12
                        let minNoteWidth: CGFloat = 200
                        let minListWidth: CGFloat = 220
                        let minimumCombinedWidth = minListWidth + minNoteWidth + spacing
                        let fullWidth = proxy.size.width

                        if fullWidth < minimumCombinedWidth {
                            VStack(spacing: spacing) {
                                contentList
                                noteSidebar
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        } else {
                            let availableWidth = max(fullWidth - spacing, 0)
                            let targetListWidth = availableWidth * 0.5
                            let maxListWidth = max(availableWidth - minNoteWidth, minListWidth)
                            let taskColumnWidth = min(max(targetListWidth, minListWidth), maxListWidth)

                            HStack(alignment: .top, spacing: spacing) {
                                contentList
                                    .frame(width: taskColumnWidth)
                                    .frame(maxHeight: .infinity, alignment: .top)

                                noteSidebar
                                    .frame(minWidth: minNoteWidth, maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                    }
                } else {
                    contentList
                }
            }
            .onChangeCompat(of: viewModel.tasks) { _, tasks in
                // If there are no inbox tasks anymore, clear inbox filter
                if selectedFilter == .inbox && !tasks.contains(where: { $0.project == nil && !$0.isDone }) {
                    selectedFilter = .none
                }
                if let focusedId = selectedNoteTaskId,
                   !tasks.contains(where: { $0.id == focusedId }) {
                    selectedNoteTaskId = nil
                }
            }
            .onChangeCompat(of: horizontalSizeClass) { _, newValue in
                let isSidebar = (newValue ?? .regular) != .compact
                if isSidebar {
                    openNoteTask = nil
                } else {
                    selectedNoteTaskId = nil
                }
            }
            .alert(
                pendingDeleteTask.map { "Delete ‘\($0.title)’?" } ?? "Delete task?",
                isPresented: .init(get: { pendingDeleteTask != nil }, set: { if !$0 { pendingDeleteTask = nil } })
            ) {
                Button("Delete", role: .destructive) {
                    if let t = pendingDeleteTask {
                        viewModel.deleteTask(id: t.id)
                        pendingDeleteTask = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingDeleteTask = nil }
            } message: {
                if let t = pendingDeleteTask {
                    Text("This will permanently remove ‘\(t.title)’.")
                } else {
                    Text("This action cannot be undone.")
                }
            }
            .sheet(item: $editingTask) { task in
                editTaskSheet(task)
            }
            // Removed full-screen sheet for edit project; using overlay below
            .padding()
            .sheet(isPresented: $isPresentingAdd) { addTaskSheet }
            .sheet(isPresented: $isPresentingManageProjects) { manageProjectsSheet }
            .onAppear {
                // Load persisted points
                userPoints = UserDefaults.standard.integer(forKey: "userPoints")

                // Only seed sample data in Debug + Simulator to keep
                // physical devices/installations starting empty.
                #if DEBUG
                #if targetEnvironment(simulator)
                if viewModel.tasks.isEmpty {
                    viewModel.seedSampleData()
                }
                #endif
                #endif
                // Rollover any incomplete past-due tasks to today at app launch
                viewModel.rolloverIncompletePastDueTasksToToday()
            }
            // Listen for next occurrence generation to prompt Accept/Edit
            .onReceive(viewModel.nextOccurrence) { task in
                pendingNextOccurrence = task
            }
            .onChangeCompat(of: viewModel.lastGeneratedOccurrence) { _, task in
                pendingNextOccurrence = task
            }
            // Refresh date-scoped views when app becomes active or clock changes significantly
            .onChangeCompat(of: scenePhase) { _, phase in
                if phase == .active {
                    // First, rollover past-due incomplete tasks
                    viewModel.rolloverIncompletePastDueTasksToToday()
                    timeAnchor = Date()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                viewModel.rolloverIncompletePastDueTasksToToday()
                timeAnchor = Date()
            }
            .onChangeCompat(of: userPoints) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "userPoints")
            }
            // New Project popup overlay
            .overlay(alignment: .center) { newProjectOverlay() }
            .overlay(alignment: .center) { editProjectOverlay() }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerView { selected in
                    if editingProject != nil && isPickingForEdit {
                        editProjectEmoji = selected
                    } else {
                        newProjectEmoji = selected
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showingCompletedSheet) { completedSheet }
            .sheet(item: $openNoteTask) { task in
                TaskNoteView(
                    taskId: task.id,
                    taskTitle: task.title,
                    initialMarkdown: task.noteMarkdown ?? "",
                    autoSaveIntervalSeconds: 3,
                    layoutStyle: .sheet,
                    onSave: { text in
                        viewModel.updateTaskNote(id: task.id, noteMarkdown: text)
                    },
                    onAutoSave: { text in
                        viewModel.updateTaskNote(id: task.id, noteMarkdown: text)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog(
                pendingMoveTask.map { "Move ‘\($0.title)’ to…" } ?? "Move to date",
                isPresented: .init(get: { pendingMoveTask != nil }, set: { if !$0 { pendingMoveTask = nil } })
            ) {
                if let t = pendingMoveTask {
                    let due = TaskItem.defaultDueDate(t.dueDate)
                    let today = TaskItem.defaultDueDate()
                    let tomorrow = TaskItem.defaultDueDate(nextDays(1))
                    let weekend = TaskItem.defaultDueDate(upcomingSaturday())
                    let nextWeek = TaskItem.defaultDueDate(nextMonday())
                    if due != today {
                        Button("Today") {
                            viewModel.setTaskDueDate(id: t.id, dueDate: today)
                            pendingMoveTask = nil
                        }
                    }
                    if due != tomorrow {
                        Button("Tomorrow") {
                            viewModel.setTaskDueDate(id: t.id, dueDate: tomorrow)
                            pendingMoveTask = nil
                        }
                    }
                    if due != weekend {
                        Button("Weekend") {
                            viewModel.setTaskDueDate(id: t.id, dueDate: weekend)
                            pendingMoveTask = nil
                        }
                    }
                    if due != nextWeek {
                        Button("Next week") {
                            viewModel.setTaskDueDate(id: t.id, dueDate: nextWeek)
                            pendingMoveTask = nil
                        }
                    }
                    Button("Pick date") {
                        pendingRescheduleTask = t
                        rescheduleDate = t.dueDate
                        pendingMoveTask = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingMoveTask = nil }
            }
            .sheet(isPresented: .init(get: { pendingRescheduleTask != nil }, set: { if !$0 { pendingRescheduleTask = nil } })) { rescheduleSheet }
            // Accept/Edit prompt for next occurrence (with clear message)
            .alert(
                "Next Occurrence",
                isPresented: .init(get: { pendingNextOccurrence != nil }, set: { if !$0 { pendingNextOccurrence = nil } })
            ) {
                if let t = pendingNextOccurrence {
                    Button("Edit") {
                        // Create the occurrence, then open editor
                        viewModel.confirmNextOccurrence(t)
                        editingTask = t
                        pendingNextOccurrence = nil
                    }
                    Button("Accept") {
                        viewModel.confirmNextOccurrence(t)
                        pendingNextOccurrence = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingNextOccurrence = nil }
            } message: {
                Text(nextOccurrenceMessage)
            }
        }
    }

#Preview {
    ContentView()
}

// MARK: - Helpers
private func nextDays(_ days: Int, from date: Date = Date()) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
}

private func isCustomScope(_ scope: ContentView.DateScope) -> Bool {
    if case .custom(_) = scope { return true } else { return false }
}

private func upcomingSaturday(from date: Date = Date()) -> Date {
    let sat = 7 // Saturday in Gregorian
    var cal = Calendar.current
    cal.firstWeekday = 1 // Sunday
    let current = cal.component(.weekday, from: date)
    if current == sat { return date }
    var days = sat - current
    if days <= 0 { days += 7 }
    return cal.date(byAdding: .day, value: days, to: date) ?? date
}

private func nextMonday(from date: Date = Date()) -> Date {
    // Always returns the next Monday strictly after 'date'
    let mon = 2 // Monday in Gregorian
    var cal = Calendar.current
    cal.firstWeekday = 1 // Sunday
    let current = cal.component(.weekday, from: date)
    var days = (mon - current + 7) % 7
    if days == 0 { days = 7 }
    return cal.date(byAdding: .day, value: days, to: date) ?? date
}

// MARK: - ContentView helpers extracted to reduce type-check complexity
extension ContentView {
    // Small subviews to simplify type inference in body
    private struct TopBarButtons: View {
        var onReset: () -> Void
        var body: some View {
            HStack {
                Spacer()
                #if DEBUG
                #if targetEnvironment(simulator)
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise").font(.headline)
                }
                .accessibilityLabel("Reset Sample Data")
                .padding(.trailing, 8)
                #endif
                #endif
            }
            .padding(.horizontal, 8)
        }
    }

    private struct TitleRow: View {
        let points: Int
        var onManage: () -> Void
        var onPointsTap: () -> Void
        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Button(action: onManage) {
                    Image(systemName: "line.3.horizontal")
                        .font(.headline)
                }
                .accessibilityLabel("Manage Projects")
                Text("Tasky Crush")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                PointsBadge(points: points, onTap: onPointsTap)
            }
            .padding(.top, 21)
            .padding(.bottom, 13)
            .padding(.horizontal, 8)
        }
    }

    private struct FloatingAddButton: View {
        var action: () -> Void
        var body: some View {
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                    )
            }
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 6)
            .accessibilityLabel("Add Task")
        }
    }
    private var projectColorSwatches: [Color] {
        [.yellow, .green, .blue, .purple, .pink, .orange, .teal, .mint, .indigo, .red, .brown, .gray]
    }
    private var hasInbox: Bool {
        viewModel.tasks.contains { $0.project == nil && !$0.isDone }
    }

    private var baseTasks: [TaskItem] {
        switch selectedFilter {
        case .none:
            return viewModel.tasks
        case .inbox:
            return viewModel.tasks.filter { $0.project == nil }
        case .project(let id):
            return viewModel.tasks.filter { $0.project?.id == id }
        }
    }

    private var filteredTasks: [TaskItem] {
        _ = timeAnchor // depend on anchor so date-based filters refresh
        // Base by date scope
        let scoped: [TaskItem] = {
            switch dateScope {
            case .anytime:
                return baseTasks
            case .today:
                let today: Date = TaskItem.defaultDueDate()
                return baseTasks.filter { TaskItem.defaultDueDate($0.dueDate) == today }
            case .tomorrow:
                let target: Date = TaskItem.defaultDueDate(nextDays(1))
                return baseTasks.filter { TaskItem.defaultDueDate($0.dueDate) == target }
            case .weekend:
                let target: Date = TaskItem.defaultDueDate(upcomingSaturday())
                return baseTasks.filter { TaskItem.defaultDueDate($0.dueDate) == target }
            case .custom(let d):
                let target: Date = TaskItem.defaultDueDate(d)
                return baseTasks.filter { TaskItem.defaultDueDate($0.dueDate) == target }
            }
        }()
        // Hide completed tasks except during grace window
        let now = Date()
        return scoped.filter { task in
            guard task.isDone else { return true }
            if let until = pendingHideUntil[task.id], until > now { return true }
            return false
        }
    }

    private var selectedNoteTask: TaskItem? {
        guard let id = selectedNoteTaskId else { return nil }
        return viewModel.tasks.first(where: { $0.id == id })
    }

    @ViewBuilder
    private var noteSidebar: some View {
        if let task = selectedNoteTask {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        Text(projectSummary(for: task))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(noteSidebarStatus(for: task))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                    .accessibilityLabel("Close note column")
                    .buttonStyle(.plain)
                }

                Divider()

                TaskNoteView(
                    taskId: task.id,
                    taskTitle: task.title,
                    initialMarkdown: task.noteMarkdown ?? "",
                    autoSaveIntervalSeconds: 3,
                    layoutStyle: .sidebar,
                    onSave: { text in
                        viewModel.updateTaskNote(id: task.id, noteMarkdown: text)
                    },
                    onAutoSave: { text in
                        viewModel.updateTaskNote(id: task.id, noteMarkdown: text)
                    }
                )
                .id(task.id)
                .frame(minHeight: 280)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.05))
            )
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("Task notes", systemImage: "note.text")
                    .font(.headline)
                Text("Select a task to view, edit, and autosave its note alongside your list.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.05))
            )
        }
    }

    private var headerTitle: String {
        switch selectedFilter {
        case .project(let id):
            return viewModel.projects.first(where: { $0.id == id })?.name ?? "Project"
        case .inbox:
            return "Unassigned"
        case .none:
            return ""
        }
    }

    private var shouldUseSidebarLayout: Bool {
        if let sizeClass = horizontalSizeClass {
            return sizeClass != .compact
        }
        return true
    }

    private func projectSummary(for task: TaskItem) -> String {
        if let project = task.project {
            return "\(project.emoji) \(project.name)"
        }
        return "Unassigned"
    }

    private func noteSidebarStatus(for task: TaskItem) -> String {
        if let updated = task.noteUpdatedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Updated \(formatter.localizedString(for: updated, relativeTo: Date()))"
        }
        let hasText = !(task.noteMarkdown ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText ? "Unsaved note" : "No note yet"
    }

    private func handleNoteTap(for task: TaskItem) {
        if shouldUseSidebarLayout {
            focusNoteSidebar(on: task)
        } else {
            openNoteTask = task
        }
    }

    private var nextOccurrenceMessage: String {
        guard let t = pendingNextOccurrence else { return "" }
        let day = TaskItem.defaultDueDate(t.dueDate)
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        var parts: [String] = []
        parts.append(df.string(from: day))
        let tf = DateFormatter()
        tf.dateStyle = .none
        tf.timeStyle = .short
        var target: Date = t.dueDateWithTime(using: Calendar.current)
        if let reminderDate = t.reminders.compactMap({ $0.resolvedDate(for: t) }).sorted().first {
            parts.append("at " + tf.string(from: reminderDate))
            target = reminderDate
        } else if t.dueTimeComponents != nil {
            parts.append("at " + tf.string(from: target))
        }
        // Relative time (e.g., in 2 hr 5 min)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        let now = Date()
        if target > now, let rel = formatter.string(from: now, to: target) {
            parts.append("(in \(rel))")
        }
        // Occurrence progress (e.g., 9/11)
        if let rec = t.recurrence {
            let done = rec.occurrencesDone
            if let limit = rec.countLimit {
                parts.append("[\(done)/\(limit)]")
            } else {
                parts.append("[\(done)]")
            }
        }
        return parts.joined(separator: " ")
    }

    // Type-erased sheets to reduce type-checking complexity in body
    private var addTaskSheet: some View {
        let preselectedId: ProjectItem.ID? = {
            if case .project(let id) = selectedFilter { return id }
            return nil
        }()
        return AddTaskView(
            projects: viewModel.projects,
            tasks: viewModel.tasks,
            preSelectedProjectId: preselectedId,
            onCreateProject: { name, emoji, colorName in
                viewModel.addProject(name: name, emoji: emoji, colorName: colorName)
            },
            onAddProjectTag: { pid, tag in
                viewModel.addTag(toProject: pid, tag: tag)
            },
            onRenameProjectTag: { pid, old, new in viewModel.renameTag(onProject: pid, from: old, to: new) },
            onDeleteProjectTag: { pid, tag in viewModel.deleteTag(onProject: pid, tag: tag) },
            onSaveFull: { (title: String, project: ProjectItem?, difficulty: TaskDifficulty, resistance: TaskResistance, estimated: TaskEstimatedTime, dueDate: Date, dueTime: DateComponents?, reminders: [TaskReminder], tag: String?, recurrence: RecurrenceRule?) in
                viewModel.addTask(title: title, project: project, difficulty: difficulty, resistance: resistance, estimatedTime: estimated, dueDate: dueDate, dueTime: dueTime, reminders: reminders, recurrence: recurrence, tag: tag)
            }
        )
    }

    private var manageProjectsSheet: some View {
        ManageProjectsView(projects: viewModel.projects) { ids in
            viewModel.applyProjectOrder(idsInOrder: ids)
        }
    }

    private var contentList: AnyView {
        if selectedFilter == .none {
            if viewModel.tasks.isEmpty {
                return AnyView(
                    ContentUnavailableView("No tasks yet", systemImage: "checklist", description: Text("Tap + to add your first task."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            } else {
                return AnyView(
                    AllTaskSectionsView(
                        projects: viewModel.projects,
                        tasks: filteredTasks,
                        onLongPress: { _ in },
                        onProjectTap: { project in selectedFilter = .project(project.id) },
                        onToggle: { task in handleToggle(task) },
                        onEdit: { task in editingTask = task },
                        onDelete: { task in pendingDeleteTask = task },
                        onMoveMenu: { task in pendingMoveTask = task },
                        onOpenNote: { task in handleNoteTap(for: task) }
                    )
                )
            }
        } else {
            if filteredTasks.isEmpty {
                return AnyView(
                    ContentUnavailableView("No tasks yet", systemImage: "checklist", description: Text("Tap + to add your first task."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            } else {
                switch (selectedFilter, dateScope) {
                case (.project, .anytime):
                    return AnyView(
                        TasksByDueDateView(
                            tasks: filteredTasks,
                            onLongPress: { _ in },
                            onProjectTap: { project in selectedFilter = .project(project.id) },
                            onToggle: { task in handleToggle(task) },
                            onEdit: { task in editingTask = task },
                            onDelete: { task in pendingDeleteTask = task },
                            onMoveMenu: { task in pendingMoveTask = task },
                            onOpenNote: { task in handleNoteTap(for: task) }
                        )
                        .id(timeAnchor) // force regrouping headers on day change
                    )
                case (.project, .today), (.project, .tomorrow), (.project, .weekend), (.project, .custom(_)):
                    return AnyView(
                        TasksByTagView(
                            tasks: filteredTasks,
                            onLongPress: { _ in },
                            onProjectTap: { project in selectedFilter = .project(project.id) },
                            onToggle: { task in handleToggle(task) },
                            onEdit: { task in editingTask = task },
                            onDelete: { task in pendingDeleteTask = task },
                            onMoveMenu: { task in pendingMoveTask = task },
                            onOpenNote: { task in handleNoteTap(for: task) }
                        )
                    )
                default:
                    return AnyView(
                        TaskFlatListView(
                            title: headerTitle,
                            tasks: filteredTasks,
                            onLongPress: { _ in },
                            onProjectTap: { project in selectedFilter = .project(project.id) },
                            onToggle: { task in handleToggle(task) },
                            onEdit: { task in editingTask = task },
                            onDelete: { task in pendingDeleteTask = task },
                            onMoveMenu: { task in pendingMoveTask = task },
                            onOpenNote: { task in handleNoteTap(for: task) }
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func editTaskSheet(_ task: TaskItem) -> some View {
        EditTaskView(
            task: task,
            projects: viewModel.projects,
            tasks: viewModel.tasks,
            onCreateProject: { name, emoji, colorName in
                viewModel.addProject(name: name, emoji: emoji, colorName: colorName)
            },
            onAddProjectTag: { pid, tag in
                viewModel.addTag(toProject: pid, tag: tag)
            },
            onRenameProjectTag: { pid, old, new in viewModel.renameTag(onProject: pid, from: old, to: new) },
            onDeleteProjectTag: { pid, tag in viewModel.deleteTag(onProject: pid, tag: tag) },
            onSave: { title, project, difficulty, resistance, estimated, dueDate, dueTime, reminders, recurrence, tag in
                viewModel.updateTask(
                    id: task.id,
                    title: title,
                    project: project,
                    difficulty: difficulty,
                    resistance: resistance,
                    estimatedTime: estimated,
                    dueDate: dueDate,
                    dueTime: dueTime,
                    reminders: reminders,
                    recurrence: recurrence,
                    tag: tag
                )
            },
            onDelete: {
                viewModel.deleteTask(id: task.id)
            }
        )
    }

    @ViewBuilder
    private func newProjectOverlay() -> some View {
        if showingAddProject {
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingAddProject = false
                        newProjectName = ""
                        newProjectEmoji = ""
                        newProjectColor = nil
                    }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("New Project").font(.headline)
                        Spacer()
                        Button {
                            showingAddProject = false
                            newProjectName = ""
                            newProjectEmoji = ""
                            newProjectColor = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 12) {
                        Button {
                            isPickingForEdit = false
                            showingEmojiPicker = true
                        } label: {
                            ZStack {
                                Circle().fill(newProjectColor ?? Color.clear)
                                Circle().fill(.ultraThinMaterial)
                                Text(newProjectEmoji.isEmpty ? "✨" : newProjectEmoji)
                                    .font(.system(size: 24))
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        TextField("Project name", text: $newProjectName)
                            .textInputAutocapitalization(.words)
                            .focused($isNewProjectNameFocused)
                    }

                    // Color palette (horizontal scroll to avoid overflow)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(projectColorSwatches.enumerated()), id: \.offset) { pair in
                                let color = pair.element
                                let isSelected = (newProjectColor?.description == color.description)
                                Button {
                                    if isSelected { newProjectColor = nil } else { newProjectColor = color }
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle().strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Spacer()
                        Button("Cancel") {
                            showingAddProject = false
                            newProjectName = ""
                            newProjectEmoji = ""
                            newProjectColor = nil
                        }
                        Button("Create") {
                            let created: ProjectItem = viewModel.addProject(
                                name: newProjectName.trimmingCharacters(in: .whitespacesAndNewlines),
                                emoji: newProjectEmoji,
                                colorName: colorName(from: newProjectColor)
                            )
                            // select the newly created project
                            selectedFilter = .project(created.id)
                            showingAddProject = false
                            newProjectName = ""
                            newProjectEmoji = ""
                            newProjectColor = nil
                        }
                        .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
                .frame(maxWidth: 360)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 20)
                .offset(y: -140)
                // Prevent the overlay from being pushed by the keyboard
                .ignoresSafeArea(.keyboard)
                .onAppear { isNewProjectNameFocused = true }
            }
            .ignoresSafeArea(.keyboard) // keep overlay fixed when keyboard appears
        }
    }

    @ViewBuilder
    private func editProjectOverlay() -> some View {
        if let project = editingProject {
            ZStack {
                Color.black.opacity(0.25).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Edit Project").font(.headline)
                        Spacer()
                        Button {
                            editingProject = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 12) {
                        Button {
                            isPickingForEdit = true
                            showingEmojiPicker = true
                        } label: {
                            ZStack {
                                Circle().fill(editProjectColor ?? Color.clear)
                                Circle().fill(.ultraThinMaterial)
                                Text(editProjectEmoji.isEmpty ? "✨" : editProjectEmoji)
                                    .font(.system(size: 24))
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        TextField("Project name", text: $editProjectName)
                            .textInputAutocapitalization(.words)
                            .focused($isEditProjectNameFocused)
                    }

                    // Color palette (horizontal scroll)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(projectColorOptions.enumerated()), id: \.offset) { pair in
                                let opt = pair.element
                                let isSelected = colorsEqual(editProjectColor, opt.color)
                                Button {
                                    editProjectColor = isSelected ? nil : opt.color
                                } label: {
                                    Circle()
                                        .fill(opt.color)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle().strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Button(role: .destructive) {
                            if let p = editingProject {
                                // If currently filtered by this project, reset filter
                                if case .project(let id) = selectedFilter, id == p.id {
                                    selectedFilter = .none
                                }
                                viewModel.deleteProject(id: p.id)
                                editingProject = nil
                            }
                        } label: {
                            Text("Delete")
                        }
                        Spacer()
                        Button("Cancel") {
                            editingProject = nil
                        }
                        Button("Save") {
                            viewModel.updateProject(
                                id: project.id,
                                name: editProjectName,
                                emoji: editProjectEmoji,
                                colorName: colorName(from: editProjectColor)
                            )
                            editingProject = nil
                        }
                        .disabled(editProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editProjectEmoji.isEmpty)
                    }
                }
                .padding(16)
                .frame(maxWidth: 360)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 20)
                .offset(y: -140)
                .ignoresSafeArea(.keyboard)
                .onAppear { isEditProjectNameFocused = true }
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    // Color helpers for edit mapping
    private var projectColorOptions: [(name: String, color: Color)] {
        [
            ("yellow", .yellow), ("green", .green), ("blue", .blue), ("purple", .purple), ("pink", .pink),
            ("orange", .orange), ("teal", .teal), ("mint", .mint), ("indigo", .indigo), ("red", .red), ("brown", .brown), ("gray", .gray)
        ]
    }

    private func colorFromName(_ name: String?) -> Color? {
        guard let name = name else { return nil }
        return projectColorOptions.first(where: { $0.name == name })?.color
    }

    private func colorName(from color: Color?) -> String? {
        guard let color = color else { return nil }
        return projectColorOptions.first(where: { $0.color.description == color.description })?.name
    }

    private func colorsEqual(_ a: Color?, _ b: Color?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.description == y.description
        default: return false
        }
    }

    private func focusNoteSidebar(on task: TaskItem) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            selectedNoteTaskId = task.id
        }
    }

    // Toggle handler + points logic
    private func handleToggle(_ task: TaskItem) {
        let wasDone = task.isDone
        viewModel.toggleTaskDone(id: task.id)
        let delta = points(for: task)
        if !wasDone {
            userPoints += delta
            // Show for ~2 seconds before hiding from lists
            let until = Date().addingTimeInterval(2)
            pendingHideUntil[task.id] = until
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                // If still completed, remove grace period so it disappears
                if let current = viewModel.tasks.first(where: { $0.id == task.id }), current.isDone {
                    pendingHideUntil[task.id] = nil
                }
            }
        } else {
            userPoints -= delta
            if userPoints < 0 { userPoints = 0 }
            // Cancel any pending hide if user reverted
            pendingHideUntil[task.id] = nil
        }
    }

    private func points(for task: TaskItem) -> Int { 20 }

    // Completed tasks sheet
    @ViewBuilder
    private var completedSheet: some View {
        CompletedTasksView(
            tasks: viewModel.tasks,
            projects: viewModel.projects,
            onUncomplete: { task in handleToggle(task) },
            onClose: { showingCompletedSheet = false },
            onProjectTap: { project in
                selectedFilter = .project(project.id)
                showingCompletedSheet = false
            },
            onUpdateTask: { original, title, project, difficulty, resistance, estimated, dueDate, dueTime, reminders, recurrence, tag in
                viewModel.updateTask(
                    id: original.id,
                    title: title,
                    project: project,
                    difficulty: difficulty,
                    resistance: resistance,
                    estimatedTime: estimated,
                    dueDate: dueDate,
                    dueTime: dueTime,
                    reminders: reminders,
                    recurrence: recurrence,
                    tag: tag
                )
            },
            onCreateProject: { name, emoji, colorName in viewModel.addProject(name: name, emoji: emoji, colorName: colorName) },
            onAddProjectTag: { pid, tag in
                viewModel.addTag(toProject: pid, tag: tag)
            },
            onRenameProjectTag: { pid, old, new in viewModel.renameTag(onProject: pid, from: old, to: new) },
            onDeleteProjectTag: { pid, tag in viewModel.deleteTag(onProject: pid, tag: tag) },
            onUpdateTaskNote: { id, text in
                viewModel.updateTaskNote(id: id, noteMarkdown: text)
            },
            onSetTaskDueDate: { id, dueDate in
                viewModel.setTaskDueDate(id: id, dueDate: dueDate)
            }
        )
    }

    // Reschedule date picker sheet
    @ViewBuilder
    private var rescheduleSheet: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Cancel") { pendingRescheduleTask = nil }
                Spacer()
                Text("Pick Date").font(.headline)
                Spacer()
                Button("Save") {
                    if let t = pendingRescheduleTask {
                        viewModel.setTaskDueDate(id: t.id, dueDate: rescheduleDate)
                    }
                    pendingRescheduleTask = nil
                }
            }
            .padding(.horizontal)

            DatePicker("", selection: $rescheduleDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 332)
                .clipped()
                .padding(.horizontal)
                .animation(.none, value: rescheduleDate)
        }
        .padding(.vertical, 8)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }
}

// Simple points badge view (top-right)
private struct PointsBadge: View {
    let points: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(.yellow)
            Text("\(points)")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .overlay(
            Capsule().stroke(Color.secondary.opacity(0.3))
        )
        .clipShape(Capsule())
        .onTapGesture { onTap?() }
    }
}

// (TitleWithPoints removed; using in-content header row instead)
