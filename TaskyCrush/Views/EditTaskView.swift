import SwiftUI

struct EditTaskView: View {
    let task: TaskItem

    // Inputs
    let projects: [ProjectItem]
    let tasks: [TaskItem]
    var onCreateProject: (String, String, String?) -> ProjectItem
    var onAddProjectTag: (ProjectItem.ID, String) -> Void
    var onRenameProjectTag: (ProjectItem.ID, String, String) -> Void = { _,_,_ in }
    var onDeleteProjectTag: (ProjectItem.ID, String) -> Void = { _,_ in }
    var onSave: (_ title: String, _ project: ProjectItem?, _ difficulty: TaskDifficulty, _ resistance: TaskResistance, _ estimated: TaskEstimatedTime, _ dueDate: Date, _ dueTime: DateComponents?, _ reminders: [TaskReminder], _ recurrence: RecurrenceRule?, _ tag: String?) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // State mirrors AddTaskView but seeded from task
    @State private var title: String
    @State private var projectList: [ProjectItem]
    @State private var selectedProjectId: ProjectItem.ID?

    @State private var difficulty: TaskDifficulty
    @State private var resistance: TaskResistance
    @State private var estimated: TaskEstimatedTime

    @State private var duePreset: DuePreset
    @State private var dueDate: Date
    @State private var showCustomDatePicker: Bool
    // Due time & reminders
    @State private var hasDueTime: Bool
    @State private var dueTime: Date
    @State private var reminderDrafts: [TaskReminder]
    // Tag state
    @State private var tagText: String
    @State private var showNewTagSheet: Bool = false
    @State private var showEditTagSheet: Bool = false
    @State private var newTagName: String = ""
    @State private var editingTagOriginal: String = ""
    @State private var editingTagName: String = ""
    @State private var sessionTags: [ProjectItem.ID: Set<String>] = [:]
    @FocusState private var isNewTagFocused: Bool
    // Repeat (Phase 2 UI)
    @State private var repeatEnabled: Bool
    @State private var repeatInterval: Int
    @State private var repeatUnit: RecurrenceUnit
    @State private var repeatBasis: RecurrenceBasis
    @State private var repeatScope: RecurrenceScope
    @State private var repeatCountLimitEnabled: Bool
    @State private var repeatCountLimit: Int

    @State private var showingAddProject = false
    @State private var newProjectName: String = ""
    @State private var newProjectEmoji: String = ""
    @State private var newProjectColor: Color? = nil
    @FocusState private var isAddProjectNameFocused: Bool
    @State private var showingEmojiPicker = false

    // Info toggles
    @State private var showDifficultyInfo = false
    @State private var showResistanceInfo = false
    @State private var showEstimatedInfo = false
    @State private var showDueInfo = false

    init(task: TaskItem, projects: [ProjectItem], tasks: [TaskItem], onCreateProject: @escaping (String, String, String?) -> ProjectItem, onAddProjectTag: @escaping (ProjectItem.ID, String) -> Void, onRenameProjectTag: @escaping (ProjectItem.ID, String, String) -> Void = { _,_,_ in }, onDeleteProjectTag: @escaping (ProjectItem.ID, String) -> Void = { _,_ in }, onSave: @escaping (_ title: String, _ project: ProjectItem?, _ difficulty: TaskDifficulty, _ resistance: TaskResistance, _ estimated: TaskEstimatedTime, _ dueDate: Date, _ dueTime: DateComponents?, _ reminders: [TaskReminder], _ recurrence: RecurrenceRule?, _ tag: String?) -> Void, onDelete: (() -> Void)? = nil) {
        self.task = task
        self.projects = projects
        self.tasks = tasks
        self.onCreateProject = onCreateProject
        self.onAddProjectTag = onAddProjectTag
        self.onRenameProjectTag = onRenameProjectTag
        self.onDeleteProjectTag = onDeleteProjectTag
        self.onSave = onSave
        self.onDelete = onDelete

        _title = State(initialValue: task.title)
        _projectList = State(initialValue: projects)
        _selectedProjectId = State(initialValue: task.project?.id)
        _difficulty = State(initialValue: task.difficulty)
        _resistance = State(initialValue: task.resistance)
        _estimated = State(initialValue: task.estimatedTime)

        let preset = EditTaskView.presetFor(date: task.dueDate)
        _duePreset = State(initialValue: preset)
        _dueDate = State(initialValue: task.dueDate)
        _showCustomDatePicker = State(initialValue: preset == .custom)
        let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        if let existingTime = task.dueTimeDate() {
            _hasDueTime = State(initialValue: true)
            _dueTime = State(initialValue: existingTime)
        } else {
            _hasDueTime = State(initialValue: false)
            _dueTime = State(initialValue: defaultTime)
        }
        _reminderDrafts = State(initialValue: task.reminders)

        if let r = task.recurrence {
            _repeatEnabled = State(initialValue: true)
            _repeatInterval = State(initialValue: r.interval)
            _repeatUnit = State(initialValue: r.unit)
            _repeatBasis = State(initialValue: r.basis)
            _repeatScope = State(initialValue: r.scope)
            _repeatCountLimitEnabled = State(initialValue: r.countLimit != nil)
            _repeatCountLimit = State(initialValue: r.countLimit ?? 5)
        } else {
            _repeatEnabled = State(initialValue: false)
            _repeatInterval = State(initialValue: 2)
            _repeatUnit = State(initialValue: .days)
            _repeatBasis = State(initialValue: .scheduled)
            _repeatScope = State(initialValue: .allDays)
            _repeatCountLimitEnabled = State(initialValue: false)
            _repeatCountLimit = State(initialValue: 5)
        }
        _tagText = State(initialValue: task.tag ?? "")
    }

    private func shortDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        let normalized = TaskItem.defaultDueDate(date)
        if normalized == TaskItem.defaultDueDate(now) { return "Today" }
        if normalized == TaskItem.defaultDueDate(cal.date(byAdding: .day, value: 1, to: now) ?? now) { return "Tomorrow" }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: normalized)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section(header: Text("Task")) {
                        TextField("Enter task title", text: $title)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.done)
                    }

                    

                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                NewProjectChip { showingAddProject = true }
                                ForEach(projectList) { project in
                                    ProjectChip(
                                        project: project,
                                        isSelected: selectedProjectId == project.id,
                                        onTap: {
                                            if selectedProjectId == project.id {
                                                selectedProjectId = nil
                                            } else {
                                                selectedProjectId = project.id
                                            }
                                        }
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // Tag chips row (project-scoped)
                        if selectedProjectId != nil {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    NewTagChip { showNewTagSheet = true }
                                    ForEach(existingProjectTags, id: \.self) { tag in
                                        let isSelected = (normalizedSelectedTag == tag)
                                        SelectableChip(title: "#\(tag)", isSelected: isSelected, color: .blue) {
                                            if isSelected { tagText = "" } else { tagText = tag }
                                        }
                                        .simultaneousGesture(
                                            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                                                editingTagOriginal = tag
                                                editingTagName = tag
                                                showEditTagSheet = true
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Due Date
                    Section {
                        HStack(spacing: 8) {
                            Text("Due Date").font(.headline)
                            Button { showDueInfo.toggle() } label: { Image(systemName: "info.circle") }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showDueInfo, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                                    Text("Pick when you plan to do it. You can change it anytime.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .padding(12)
                                        .frame(maxWidth: 260)
                                }
                                .presentationCompactAdaptation(.popover)
                            Spacer()
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                SelectableChip(title: "Today", isSelected: duePreset == .today, color: .blue) {
                                    duePreset = .today
                                    dueDate = TaskItem.defaultDueDate()
                                    showCustomDatePicker = false
                                }
                                SelectableChip(title: "Tomorrow", isSelected: duePreset == .tomorrow, color: .blue) {
                                    duePreset = .tomorrow
                                    dueDate = TaskItem.defaultDueDate(nextDays(1))
                                    showCustomDatePicker = false
                                }
                                SelectableChip(title: "This weekend", isSelected: duePreset == .weekend, color: .blue) {
                                    duePreset = .weekend
                                    dueDate = TaskItem.defaultDueDate(upcomingSaturday())
                                    showCustomDatePicker = false
                                }
                                SelectableChip(title: "Next week", isSelected: duePreset == .nextWeek, color: .blue) {
                                    duePreset = .nextWeek
                                    dueDate = TaskItem.defaultDueDate(nextWeekMonday())
                                    showCustomDatePicker = false
                                }
                                SelectableChip(title: (duePreset == .custom ? shortDateLabel(dueDate) : "Pick date…"), isSelected: duePreset == .custom, color: .blue) {
                                    if duePreset != .custom {
                                        duePreset = .custom
                                        showCustomDatePicker = true
                                    } else {
                                        showCustomDatePicker.toggle()
                                    }
                                }
                            }
                        }
                        if duePreset == .custom && showCustomDatePicker {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .onChangeCompat(of: dueDate) { _, new in
                                    dueDate = TaskItem.defaultDueDate(new)
                                    showCustomDatePicker = false
                                }
                        }
                        Toggle("Add due time", isOn: $hasDueTime)
                        if hasDueTime {
                            DatePicker("Time", selection: $dueTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                        }
                    }

                    // Repeat (preview-only for Phase 2) -- already inserted below Due Date

                    Section {
                        ReminderListEditor(
                            reminders: $reminderDrafts,
                            dueTimeIsSet: hasDueTime,
                            onFirstReminderAdded: { NotificationManager.shared.requestAuthorizationIfNeeded() }
                        )
                    } header: {
                        Text("Reminders")
                    } footer: {
                        Text("Schedule up to three reminders per task.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    // Repeat (clearer copy)
                    Section {
                        Toggle("Repeat", isOn: $repeatEnabled)
                        if repeatEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Frequency").font(.headline)
                                HStack {
                                    Stepper(value: $repeatInterval, in: 1...999) { Text("Every \(repeatInterval)") }
                                    Picker("Unit", selection: $repeatUnit) {
                                        Text("Minutes").tag(RecurrenceUnit.minutes)
                                        Text("Hours").tag(RecurrenceUnit.hours)
                                        Text("Days").tag(RecurrenceUnit.days)
                                        Text("Weeks").tag(RecurrenceUnit.weeks)
                                        Text("Months").tag(RecurrenceUnit.months)
                                        Text("Years").tag(RecurrenceUnit.years)
                                    }
                                    .pickerStyle(.menu)
                                }
                                // Example removed for clarity

                                Text("When to schedule the next").font(.headline)
                                Picker("", selection: $repeatBasis) {
                                    Text("When I complete it").tag(RecurrenceBasis.completion)
                                    Text("On the scheduled date").tag(RecurrenceBasis.scheduled)
                                }
                                .pickerStyle(.segmented)
                                Group {
                                    if repeatBasis == .completion {
                                        Text("The next date is calculated from when you complete the task.")
                                    } else {
                                        Text("The next date advances by the selected frequency, even if you don't complete it.")
                                    }
                                }
                                .font(.footnote).foregroundStyle(.secondary)

                                Text("Days to consider").font(.headline)
                                Picker("", selection: $repeatScope) {
                                    Text("All days").tag(RecurrenceScope.allDays)
                                    Text("Weekdays only").tag(RecurrenceScope.weekdaysOnly)
                                    Text("Weekends only").tag(RecurrenceScope.weekendsOnly)
                                }
                                .pickerStyle(.segmented)
                                // Helper note removed (title is self-explanatory)

                                Text("Repetition limit").font(.headline)
                                Toggle("Limit repetitions", isOn: $repeatCountLimitEnabled)
                                if repeatCountLimitEnabled {
                                    Stepper(value: $repeatCountLimit, in: 1...1000) {
                                        Text("Up to \(repeatCountLimit) times")
                                    }
                                }

                                Text("Next").font(.headline)
                                if let preview = repeatPreview() {
                                    Text("\(dateTimeFormatter.string(from: preview))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("—").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    

                    // Delete Task (separate section at bottom)
                    Section {
                        Button(role: .destructive) {
                            onDelete?()
                            dismiss()
                        } label: {
                            Text("Delete Task")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                // Popup centered overlay (new project)
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
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            HStack(spacing: 12) {
                                Button { showingEmojiPicker = true } label: {
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
                                    .focused($isAddProjectNameFocused)
                            }

                            // Color palette (creation preview only, horizontal scroll)
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
                                    let created = onCreateProject(
                                        newProjectName.trimmingCharacters(in: .whitespacesAndNewlines),
                                        newProjectEmoji,
                                        colorName(from: newProjectColor)
                                    )
                                    projectList.append(created)
                                    selectedProjectId = created.id
                                    showingAddProject = false
                                    newProjectName = ""
                                    newProjectEmoji = ""
                                    newProjectColor = nil
                                }
                                .disabled(!canCreateProject)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: 360)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(radius: 20)
                        .offset(y: -140)
                        .onAppear { isAddProjectNameFocused = true }
                    }
                    .ignoresSafeArea(.keyboard)
                }
            }
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .overlay(alignment: .center) { newTagOverlay }
            .overlay(alignment: .center) { editTagOverlay }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerView { selected in
                    newProjectEmoji = selected
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .onChangeCompat(of: selectedProjectId) { _, _ in
                // Clear tag when switching projects
                tagText = ""
            }
        }
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func save() {
        let project = selectedProjectId.flatMap { id in projectList.first(where: { $0.id == id }) }
        let dueTimeComponents = hasDueTime ? Calendar.current.dateComponents([.hour, .minute], from: dueTime) : nil
        let reminders = Array(reminderDrafts.prefix(3))
        let recurrence = repeatRule()
        let tagToUse = (project != nil) ? tagText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
        onSave(title, project, difficulty, resistance, estimated, dueDate, dueTimeComponents, reminders, recurrence, tagToUse)
        dismiss()
    }

    private var canCreateProject: Bool {
        !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Overlay for new tag creation (centered, similar to New Project)
    @ViewBuilder
    private var newTagOverlay: some View {
        if showNewTagSheet {
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showNewTagSheet = false
                        newTagName = ""
                    }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("New Tag").font(.headline)
                        Spacer()
                        Button {
                            showNewTagSheet = false
                            newTagName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("#Tag name", text: $newTagName)
                        .textInputAutocapitalization(.never)
                        .focused($isNewTagFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                let normalized = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
                                tagText = normalized
                                if let pid = selectedProjectId {
                                    var set = sessionTags[pid] ?? []
                                    set.insert(normalized)
                                    sessionTags[pid] = set
                                    onAddProjectTag(pid, normalized)
                                    if let idx = projectList.firstIndex(where: { $0.id == pid }) {
                                        var p = projectList[idx]
                                        var tags = Set((p.tags ?? []))
                                        tags.insert(normalized)
                                        p.tags = Array(tags)
                                        projectList[idx] = p
                                    }
                                }
                                newTagName = ""
                                showNewTagSheet = false
                            }
                        }
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            showNewTagSheet = false
                            newTagName = ""
                        }
                        Button("Save") {
                            let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                let normalized = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
                                tagText = normalized
                                if let pid = selectedProjectId {
                                    var set = sessionTags[pid] ?? []
                                    set.insert(normalized)
                                    sessionTags[pid] = set
                                    onAddProjectTag(pid, normalized)
                                    if let idx = projectList.firstIndex(where: { $0.id == pid }) {
                                        var p = projectList[idx]
                                        var tags = Set((p.tags ?? []))
                                        tags.insert(normalized)
                                        p.tags = Array(tags)
                                        projectList[idx] = p
                                    }
                                }
                            }
                            newTagName = ""
                            showNewTagSheet = false
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
                .frame(maxWidth: 360)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 20)
                .offset(y: -140)
                .ignoresSafeArea(.keyboard)
            }
            .ignoresSafeArea(.keyboard)
            .onAppear { isNewTagFocused = true }
        }
    }

    // Overlay for editing/deleting an existing tag
    @ViewBuilder
    private var editTagOverlay: some View {
        if showEditTagSheet {
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { showEditTagSheet = false }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Edit Tag").font(.headline)
                        Spacer()
                        Button {
                            showEditTagSheet = false
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("#Tag name", text: $editingTagName)
                        .textInputAutocapitalization(.never)
                        .focused($isNewTagFocused)
                        .submitLabel(.done)
                        .onSubmit { saveEditedTag() }
                    HStack {
                        Button(role: .destructive) { deleteEditedTag() } label: { Text("Delete") }
                        Spacer()
                        Button("Cancel") { showEditTagSheet = false }
                        Button("Save") { saveEditedTag() }
                            .disabled(editingTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
                .frame(maxWidth: 360)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 20)
                .offset(y: -140)
                .ignoresSafeArea(.keyboard)
                .onAppear { isNewTagFocused = true }
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    // MARK: - Helpers
    private enum DuePreset { case today, tomorrow, weekend, nextWeek, custom }

    private static func presetFor(date: Date) -> DuePreset {
        let normalized = TaskItem.defaultDueDate(date)
        if normalized == TaskItem.defaultDueDate() { return .today }
        if normalized == TaskItem.defaultDueDate(nextDays(1)) { return .tomorrow }
        if normalized == TaskItem.defaultDueDate(upcomingSaturday()) { return .weekend }
        if normalized == TaskItem.defaultDueDate(nextWeekMonday()) { return .nextWeek }
        return .custom
    }
}

// MARK: - Date helpers (duplicated from AddTaskView)
private func nextWeekday(_ weekday: Int, from date: Date = Date()) -> Date {
    var cal = Calendar.current
    cal.firstWeekday = 1 // Sunday
    let current = cal.component(.weekday, from: date)
    var days = weekday - current
    if days <= 0 { days += 7 }
    return cal.date(byAdding: .day, value: days, to: date) ?? date
}

private func upcomingSaturday(from date: Date = Date()) -> Date {
    let sat = 7
    var cal = Calendar.current
    cal.firstWeekday = 1
    let current = cal.component(.weekday, from: date)
    if current == sat { return date }
    return nextWeekday(sat, from: date)
}

private func nextWeekMonday(from date: Date = Date()) -> Date {
    return nextWeekday(2, from: date)
}

private func nextDays(_ days: Int, from date: Date = Date()) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
}

private func dateTimeFormatterFactory_Edit() -> DateFormatter {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    return df
}

private var dateTimeFormatter: DateFormatter { dateTimeFormatterFactory_Edit() }

private var projectColorSwatches: [Color] { [.yellow, .green, .blue, .purple, .pink, .orange, .teal, .mint, .indigo, .red, .brown, .gray] }
private var projectColorNames: [String] { ["yellow", "green", "blue", "purple", "pink", "orange", "teal", "mint", "indigo", "red", "brown", "gray"] }
private func colorName(from color: Color?) -> String? {
    guard let color = color else { return nil }
    if let idx = projectColorSwatches.firstIndex(where: { $0.description == color.description }) {
        return projectColorNames[idx]
    }
    return nil
}

private extension EditTaskView {
    func repeatRule() -> RecurrenceRule? {
        guard repeatEnabled else { return nil }
        let anchor = TaskItem.defaultDueDate(dueDate)
        return RecurrenceRule(
            unit: repeatUnit,
            interval: repeatInterval,
            basis: repeatBasis,
            scope: repeatScope,
            countLimit: repeatCountLimitEnabled ? repeatCountLimit : nil,
            occurrencesDone: task.recurrence?.occurrencesDone ?? 0,
            anchor: task.recurrence?.anchor ?? anchor
        )
    }

    func repeatPreview() -> Date? {
        guard let rule = repeatRule() else { return nil }
        switch rule.basis {
        case .scheduled:
            return RecurrenceEngine.nextOccurrence(from: rule.anchor, rule: rule)
        case .completion:
            return RecurrenceEngine.nextOccurrence(from: Date(), rule: rule)
        }
    }
}

// projectColorSwatches moved above with name mapping helpers

private extension EditTaskView {
    var normalizedSelectedTag: String? {
        tagText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
    var existingProjectTags: [String] {
        guard let pid = selectedProjectId else { return [] }
        let raw = tasks
            .filter { $0.project?.id == pid }
            .compactMap { $0.tag?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let session = Array(sessionTags[pid] ?? [])
        let projectTags: [String] = {
            if let proj = projectList.first(where: { $0.id == pid }) {
                return (proj.tags ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
            return []
        }()
        var unique: [String] = Array(Set(raw).union(session).union(projectTags))
        unique.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if let sel = normalizedSelectedTag {
            if let idx = unique.firstIndex(where: { $0.localizedCaseInsensitiveCompare(sel) == .orderedSame }) {
                let val = unique.remove(at: idx)
                unique.insert(val, at: 0)
            } else {
                unique.insert(sel, at: 0)
            }
        }
        return unique
    }

    // MARK: - Edit/Delete Tag helpers
    func saveEditedTag() {
        let trimmed = editingTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = selectedProjectId, !trimmed.isEmpty else { return }
        if trimmed.compare(editingTagOriginal, options: .caseInsensitive) == .orderedSame {
            showEditTagSheet = false
            return
        }
        onRenameProjectTag(pid, editingTagOriginal, trimmed)
        if let idx = projectList.firstIndex(where: { $0.id == pid }) {
            var p = projectList[idx]
            var set = Set((p.tags ?? []))
            set.remove(editingTagOriginal)
            set.insert(trimmed)
            p.tags = Array(set)
            projectList[idx] = p
        }
        var sess = sessionTags[pid] ?? []
        sess.remove(editingTagOriginal)
        sess.insert(trimmed)
        sessionTags[pid] = sess
        if let sel = normalizedSelectedTag, sel.compare(editingTagOriginal, options: .caseInsensitive) == .orderedSame {
            tagText = trimmed
        }
        showEditTagSheet = false
    }

    func deleteEditedTag() {
        guard let pid = selectedProjectId else { return }
        onDeleteProjectTag(pid, editingTagOriginal)
        if let idx = projectList.firstIndex(where: { $0.id == pid }) {
            var p = projectList[idx]
            var set = Set((p.tags ?? []))
            set.remove(editingTagOriginal)
            p.tags = Array(set)
            projectList[idx] = p
        }
        var sess = sessionTags[pid] ?? []
        sess.remove(editingTagOriginal)
        sessionTags[pid] = sess
        if let sel = normalizedSelectedTag, sel.compare(editingTagOriginal, options: .caseInsensitive) == .orderedSame {
            tagText = ""
        }
        showEditTagSheet = false
    }
}
