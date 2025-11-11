import SwiftUI

struct CompletedTasksView: View {
    let tasks: [TaskItem]
    let projects: [ProjectItem]
    var onUncomplete: (TaskItem) -> Void
    var onClose: () -> Void
    var onProjectTap: (ProjectItem) -> Void = { _ in }
    var onUpdateTask: (_ original: TaskItem, _ title: String, _ project: ProjectItem?, _ difficulty: TaskDifficulty, _ resistance: TaskResistance, _ estimated: TaskEstimatedTime, _ dueDate: Date, _ dueTime: DateComponents?, _ reminders: [TaskReminder], _ recurrence: RecurrenceRule?, _ tag: String?) -> Void
    var onCreateProject: (String, String, String?) -> ProjectItem
    var onAddProjectTag: (ProjectItem.ID, String) -> Void
    var onRenameProjectTag: (ProjectItem.ID, String, String) -> Void = { _,_,_ in }
    var onDeleteProjectTag: (ProjectItem.ID, String) -> Void = { _,_ in }
    var onUpdateTaskNote: (_ id: UUID, _ text: String) -> Void
    var onSetTaskDueDate: (_ id: UUID, _ dueDate: Date) -> Void

    // Single-day view state
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var showPicker: Bool = false
    @State private var editingTask: TaskItem? = nil
    @State private var openNoteTask: TaskItem? = nil
    @State private var pendingMoveTask: TaskItem? = nil
    @State private var pendingRescheduleTask: TaskItem? = nil
    @State private var rescheduleDate: Date = TaskItem.defaultDueDate()

    var body: some View {
        NavigationStack {
            VStack(spacing: 4) {
                // Screen title with extra top padding
                Text("Completed Tasks")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.top, 8)

                // Header controls: prev day, title (tap to pick), next day, Today
                headerControls
                    .padding(.top, 25)
                    .padding(.bottom, 8)

                List {
                    ForEach(itemsForSelectedDay) { task in
                        let pts = points(for: task)
                        TaskRow(
                            task: task,
                            onProjectTap: { project in onProjectTap(project) },
                            onToggle: { _ in onUncomplete(task) },
                            onEdit: { _ in editingTask = task },
                            onMoveMenu: { _ in pendingMoveTask = task }, onOpenNote: { _ in openNoteTask = task },
                            showCompletedStyle: false,
                            trailingInfo: "+\(pts)",
                            showProjectName: false
                        )
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose() }
                }
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: $showPicker) {
                VStack {
                    HStack {
                        Button("Cancel") { showPicker = false }
                        Spacer()
                        Text("Pick Date").font(.headline)
                        Spacer()
                        Button("Done") { showPicker = false }
                    }
                    .padding(.horizontal)
                    DatePicker("", selection: $selectedDay, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .onChangeCompat(of: selectedDay) { _, new in selectedDay = normalized(new) }
                        .padding(.horizontal)
                }
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            }
            // Present note editor above CompletedTasks
            .sheet(item: $openNoteTask) { task in
                TaskNoteView(
                    taskId: task.id,
                    taskTitle: task.title,
                    initialMarkdown: task.noteMarkdown ?? "",
                    autoSaveIntervalSeconds: 3,
                    onSave: { text in onUpdateTaskNote(task.id, text) },
                    onAutoSave: { text in onUpdateTaskNote(task.id, text) }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            // Present task editor above CompletedTasks
            .sheet(item: $editingTask) { task in
                EditTaskView(
                    task: task,
                    projects: projects,
                    tasks: tasks,
                    onCreateProject: { name, emoji, colorName in onCreateProject(name, emoji, colorName) },
                    onAddProjectTag: { pid, tag in onAddProjectTag(pid, tag) },
                    onRenameProjectTag: { pid, old, new in onRenameProjectTag(pid, old, new) },
                    onDeleteProjectTag: { pid, tag in onDeleteProjectTag(pid, tag) },
                    onSave: { title, project, difficulty, resistance, estimated, dueDate, dueTime, reminders, recurrence, tag in
                        onUpdateTask(task, title, project, difficulty, resistance, estimated, dueDate, dueTime, reminders, recurrence, tag)
                    },
                    onDelete: nil
                )
            }
            // Move menu and reschedule inside CompletedTasks
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
                            onSetTaskDueDate(t.id, today)
                            pendingMoveTask = nil
                        }
                    }
                    if due != tomorrow {
                        Button("Tomorrow") {
                            onSetTaskDueDate(t.id, tomorrow)
                            pendingMoveTask = nil
                        }
                    }
                    if due != weekend {
                        Button("Weekend") {
                            onSetTaskDueDate(t.id, weekend)
                            pendingMoveTask = nil
                        }
                    }
                    if due != nextWeek {
                        Button("Next week") {
                            onSetTaskDueDate(t.id, nextWeek)
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
            .sheet(isPresented: .init(get: { pendingRescheduleTask != nil }, set: { if !$0 { pendingRescheduleTask = nil } })) {
                VStack(spacing: 8) {
                    HStack {
                        Button("Cancel") { pendingRescheduleTask = nil }
                        Spacer()
                        Text("Pick Date").font(.headline)
                        Spacer()
                        Button("Save") {
                            if let t = pendingRescheduleTask {
                                onSetTaskDueDate(t.id, rescheduleDate)
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
    }

    // MARK: - Single-day computed views
    private var completed: [TaskItem] { tasks.filter { $0.isDone } }

    private var itemsForSelectedDay: [TaskItem] {
        let day = normalized(selectedDay)
        return completed.filter { normalized($0.completedAt ?? Date()) == day }
            .sorted { (a, b) in
                let da = a.completedAt ?? Date.distantPast
                let db = b.completedAt ?? Date.distantPast
                return da > db
            }
    }

    private var dayTitle: String {
        let day = normalized(selectedDay)
        let today = normalized(Date())
        let yesterday = normalized(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        if day == today { return "Today" }
        if day == yesterday { return "Yesterday" }
        return headerFormatter.string(from: day)
    }

    private var dayTotalPoints: Int {
        itemsForSelectedDay.reduce(0) { $0 + points(for: $1) }
    }

    // (section header no longer used; total points chip moved to headerControls)

    private func normalized(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private var headerFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }

    // Points calculation mirrors ContentView.points(for:)
    private func points(for task: TaskItem) -> Int { 20 }

    // MARK: - Header controls
    @ViewBuilder
    private var headerControls: some View {
        let today = normalized(Date())
        HStack(spacing: 12) {
            Button(action: { selectedDay = normalized(addDays(-1, from: selectedDay)) }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Button(action: { showPicker = true }) {
                HStack(spacing: 6) {
                    Text(dayTitle).font(.headline)
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button(action: { selectedDay = normalized(addDays(1, from: selectedDay)) }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(normalized(selectedDay) >= today)

            Spacer()

            if normalized(selectedDay) != today {
                Button("Today") { selectedDay = today }
                    .buttonStyle(.bordered)
                    .font(.caption)
            }

            // Daily total points chip aligned to far right
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(dayTotalPoints)")
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
        }
        .padding(.horizontal)
    }

    private func addDays(_ days: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }
}

// MARK: - Date helpers for move menu
private func nextDays(_ days: Int, from date: Date = Date()) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
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
