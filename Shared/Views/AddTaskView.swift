import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @FocusState private var isTitleFieldFocused: Bool

    // Projects input and callbacks
    let projects: [ProjectItem]
    // All tasks (for computing project-scoped existing tags)
    let tasks: [TaskItem]
    var onCreateProject: (String, String, String?) -> ProjectItem
    var onAddProjectTag: (ProjectItem.ID, String) -> Void
    var onRenameProjectTag: (ProjectItem.ID, String, String) -> Void = { _,_,_ in }
    var onDeleteProjectTag: (ProjectItem.ID, String) -> Void = { _,_ in }
    var onSave: (_ title: String, _ project: ProjectItem?, _ difficulty: TaskDifficulty, _ resistance: TaskResistance, _ estimated: TaskEstimatedTime, _ dueDate: Date, _ dueTime: DateComponents?, _ reminders: [TaskReminder]) -> Void
    var onSaveFull: ((_ title: String, _ project: ProjectItem?, _ difficulty: TaskDifficulty, _ resistance: TaskResistance, _ estimated: TaskEstimatedTime, _ dueDate: Date, _ dueTime: DateComponents?, _ reminders: [TaskReminder], _ tag: String?, _ recurrence: RecurrenceRule?) -> Void)? = nil

    // Selection state
    @State private var selectedProjectId: ProjectItem.ID?
    @State private var projectList: [ProjectItem] = []
    @State private var showingAddProject = false
    @State private var newProjectName: String = ""
    @State private var newProjectEmoji: String = ""
    @FocusState private var isAddProjectNameFocused: Bool
    @State private var newProjectColor: Color? = nil
    @State private var showingEmojiPicker = false
    // Attributes
    @State private var difficulty: TaskDifficulty = .easy
    @State private var resistance: TaskResistance = .low
    @State private var estimated: TaskEstimatedTime = .short
    // Info toggles
    @State private var showDifficultyInfo = false
    @State private var showResistanceInfo = false
    @State private var showEstimatedInfo = false
    // Due date
    enum DuePreset { case today, tomorrow, weekend, nextWeek, custom }
    @State private var duePreset: DuePreset = .today
    @State private var dueDate: Date = TaskItem.defaultDueDate()
    @State private var showDueInfo = false
    @State private var showCustomDatePicker = false
    // Due time & reminders
    @State private var hasDueTime: Bool = false
    @State private var dueTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var reminderDrafts: [TaskReminder] = []
    // Tag (scoped to selected project)
    @State private var tagText: String = ""
    @State private var showNewTagSheet: Bool = false
    @State private var showEditTagSheet: Bool = false
    @State private var newTagName: String = ""
    @State private var editingTagOriginal: String = ""
    @State private var editingTagName: String = ""
    // Session-only store of newly created tags per project so they remain selectable
    @State private var sessionTags: [ProjectItem.ID: Set<String>] = [:]
    @FocusState private var isNewTagFocused: Bool
    // Repeat (Phase 2 UI)
    @State private var repeatEnabled: Bool = false
    @State private var repeatInterval: Int = 2
    @State private var repeatUnit: RecurrenceUnit = .days
    @State private var repeatBasis: RecurrenceBasis = .scheduled
    @State private var repeatScope: RecurrenceScope = .allDays
    @State private var repeatCountLimitEnabled: Bool = false
    @State private var repeatCountLimit: Int = 5

    init(projects: [ProjectItem], tasks: [TaskItem], preSelectedProjectId: ProjectItem.ID? = nil, onCreateProject: @escaping (String, String, String?) -> ProjectItem, onAddProjectTag: @escaping (ProjectItem.ID, String) -> Void, onRenameProjectTag: @escaping (ProjectItem.ID, String, String) -> Void = { _,_,_ in }, onDeleteProjectTag: @escaping (ProjectItem.ID, String) -> Void = { _,_ in }, onSaveWithReminder: @escaping (_ title: String, _ project: ProjectItem?, _ difficulty: TaskDifficulty, _ resistance: TaskResistance, _ estimated: TaskEstimatedTime, _ dueDate: Date, _ dueTime: DateComponents?, _ reminders: [TaskReminder]) -> Void) {
        self.projects = projects
        self.tasks = tasks
        self.onCreateProject = onCreateProject
        self.onAddProjectTag = onAddProjectTag
        self.onRenameProjectTag = onRenameProjectTag
        self.onDeleteProjectTag = onDeleteProjectTag
        self.onSave = onSaveWithReminder
        _selectedProjectId = State(initialValue: preSelectedProjectId)
        _projectList = State(initialValue: projects)
    }

    // Full initializer including recurrence
    init(projects: [ProjectItem], tasks: [TaskItem], preSelectedProjectId: ProjectItem.ID? = nil, onCreateProject: @escaping (String, String, String?) -> ProjectItem, onAddProjectTag: @escaping (ProjectItem.ID, String) -> Void, onRenameProjectTag: @escaping (ProjectItem.ID, String, String) -> Void = { _,_,_ in }, onDeleteProjectTag: @escaping (ProjectItem.ID, String) -> Void = { _,_ in }, onSaveFull: @escaping (_ title: String, _ project: ProjectItem?, _ difficulty: TaskDifficulty, _ resistance: TaskResistance, _ estimated: TaskEstimatedTime, _ dueDate: Date, _ dueTime: DateComponents?, _ reminders: [TaskReminder], _ tag: String?, _ recurrence: RecurrenceRule?) -> Void) {
        self.projects = projects
        self.tasks = tasks
        self.onCreateProject = onCreateProject
        self.onAddProjectTag = onAddProjectTag
        self.onRenameProjectTag = onRenameProjectTag
        self.onDeleteProjectTag = onDeleteProjectTag
        self.onSave = { title, project, difficulty, resistance, estimated, dueDate, dueTime, reminders in
            onSaveFull(title, project, difficulty, resistance, estimated, dueDate, dueTime, reminders, nil, nil)
        }
        self.onSaveFull = onSaveFull
        _selectedProjectId = State(initialValue: preSelectedProjectId)
        _projectList = State(initialValue: projects)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                formContent
                if showingAddProject {
                    newProjectOverlay
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPickerView { selected in
                    newProjectEmoji = selected
                }
#if os(iOS)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
#endif
            }
        }
        .onChangeCompat(of: selectedProjectId) { _, _ in
            // Clear tag when switching projects
            tagText = ""
        }
        // Centered overlay for creating a new tag (like New Project overlay)
        .overlay(alignment: .center) {
            if showNewTagSheet { newTagOverlay }
        }
        .overlay(alignment: .center) {
            if showEditTagSheet { editTagOverlay }
        }
        .onAppear {
            DispatchQueue.main.async {
                isTitleFieldFocused = true
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                taskTitleSection
                projectSelectionSection
                dueDateSection
                remindersSection
                repeatSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }

    private var overlayBackgroundColor: Color {
#if os(iOS)
        Color(.systemBackground)
#else
        Color(nsColor: .windowBackgroundColor)
#endif
    }

    private func persistNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        tagText = normalized
        if let pid = selectedProjectId {
            var set = sessionTags[pid] ?? []
            set.insert(normalized)
            sessionTags[pid] = set
            onAddProjectTag(pid, normalized)
            if let idx = projectList.firstIndex(where: { $0.id == pid }) {
                var project = projectList[idx]
                var tags = Set(project.tags ?? [])
                tags.insert(normalized)
                project.tags = Array(tags)
                projectList[idx] = project
            }
        }
        newTagName = ""
        showNewTagSheet = false
    }

    @ViewBuilder
    private var taskTitleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $title, prompt: Text("Enter Task…"))
#if os(iOS)
                .textInputAutocapitalization(.sentences)
#endif
                .submitLabel(.done)
                .focused($isTitleFieldFocused)
            Divider()
        }
    }

    @ViewBuilder
    private var projectSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
    }

    @ViewBuilder
    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
    }

    @ViewBuilder
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReminderListEditor(
                reminders: $reminderDrafts,
                dueTimeIsSet: hasDueTime,
                onFirstReminderAdded: { NotificationManager.shared.requestAuthorizationIfNeeded() }
            )
            Text("Reminders")
            Text("Up to three reminders per task.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Text("Days to consider").font(.headline)
                    Picker("", selection: $repeatScope) {
                        Text("All days").tag(RecurrenceScope.allDays)
                        Text("Weekdays only").tag(RecurrenceScope.weekdaysOnly)
                        Text("Weekends only").tag(RecurrenceScope.weekendsOnly)
                    }
                    .pickerStyle(.segmented)

                    Text("Repetition limit").font(.headline)
                    Toggle("Limit repetitions", isOn: $repeatCountLimitEnabled)
                    if repeatCountLimitEnabled {
                        Stepper(value: $repeatCountLimit, in: 1...1000) { Text("Up to \(repeatCountLimit) times") }
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
    }

    @ViewBuilder
    private var newProjectOverlay: some View {
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
#if os(iOS)
                        .textInputAutocapitalization(.words)
#endif
                        .focused($isAddProjectNameFocused)
                }

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
            .background(overlayBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 20)
            .offset(y: -140)
            .onAppear { isAddProjectNameFocused = true }
        }
        .ignoresKeyboardSafeArea()
    }

    @ViewBuilder
    private var newTagOverlay: some View {
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
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .focused($isNewTagFocused)
                    .submitLabel(.done)
                    .onSubmit { persistNewTag() }
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showNewTagSheet = false
                        newTagName = ""
                    }
                    Button("Save") {
                        persistNewTag()
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
            .frame(maxWidth: 360)
            .background(overlayBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 20)
            .offset(y: -140)
        }
        .ignoresKeyboardSafeArea()
        .onAppear { isNewTagFocused = true }
    }

    @ViewBuilder
    private var editTagOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { showEditTagSheet = false }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Edit Tag").font(.headline)
                    Spacer()
                    Button { showEditTagSheet = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                TextField("#Tag name", text: $editingTagName)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
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
            .background(overlayBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 20)
            .offset(y: -140)
        }
        .ignoresKeyboardSafeArea()
        .onAppear { isNewTagFocused = true }
    }

    private func save() {
        let project = selectedProjectId.flatMap { id in projectList.first(where: { $0.id == id }) }
        let dueTimeComponents = hasDueTime ? Calendar.current.dateComponents([.hour, .minute], from: dueTime) : nil
        let reminders = Array(reminderDrafts.prefix(3))
        let recurrence = repeatRule()
        if let full = onSaveFull {
            let tagToUse = (project != nil) ? tagText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
            full(title, project, difficulty, resistance, estimated, dueDate, dueTimeComponents, reminders, tagToUse, recurrence)
        } else {
            onSave(title, project, difficulty, resistance, estimated, dueDate, dueTimeComponents, reminders)
        }
        dismiss()
    }

    private var existingProjectTags: [String] {
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
                // Move selected to front
                let val = unique.remove(at: idx)
                unique.insert(val, at: 0)
            } else {
                // Insert newly created/typed tag at front
                unique.insert(sel, at: 0)
            }
        }
        return unique
    }

    private var normalizedSelectedTag: String? {
        tagText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private var canCreateProject: Bool {
        !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Edit/Delete Tag helpers
    private func saveEditedTag() {
        let trimmed = editingTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = selectedProjectId, !trimmed.isEmpty else { return }
        if trimmed.compare(editingTagOriginal, options: .caseInsensitive) == .orderedSame {
            showEditTagSheet = false
            return
        }
        onRenameProjectTag(pid, editingTagOriginal, trimmed)
        // Update local mirrors
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

    private func deleteEditedTag() {
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

// MARK: - Date helpers
private var projectColorSwatches: [Color] { [.yellow, .green, .blue, .purple, .pink, .orange, .teal, .mint, .indigo, .red, .brown, .gray] }

private var projectColorNames: [String] { ["yellow", "green", "blue", "purple", "pink", "orange", "teal", "mint", "indigo", "red", "brown", "gray"] }

private func colorName(from color: Color?) -> String? {
    guard let color = color else { return nil }
    if let idx = projectColorSwatches.firstIndex(where: { $0.description == color.description }) {
        return projectColorNames[idx]
    }
    return nil
}

private func shortDateLabel(_ date: Date) -> String {
    let cal = Calendar.current
    let now = Date()
    let normalized = TaskItem.defaultDueDate(date)
    if normalized == TaskItem.defaultDueDate(now) { return "Today" }
    if normalized == TaskItem.defaultDueDate(cal.date(byAdding: .day, value: 1, to: now) ?? now) { return "Tomorrow" }
    let df = DateFormatter()
    df.dateFormat = "MMM d" // concise
    return df.string(from: normalized)
}

private func nextWeekday(_ weekday: Int, from date: Date = Date()) -> Date {
    var cal = Calendar.current
    cal.firstWeekday = 1 // Sunday
    let current = cal.component(.weekday, from: date)
    var days = weekday - current
    if days <= 0 { days += 7 }
    return cal.date(byAdding: .day, value: days, to: date) ?? date
}

private func upcomingSaturday(from date: Date = Date()) -> Date {
    // In Gregorian, Saturday = 7
    let sat = 7
    var cal = Calendar.current
    cal.firstWeekday = 1
    let current = cal.component(.weekday, from: date)
    if current == sat { return date }
    return nextWeekday(sat, from: date)
}

private func nextWeekMonday(from date: Date = Date()) -> Date {
    // Monday = 2
    return nextWeekday(2, from: date)
}

private func nextDays(_ days: Int, from date: Date = Date()) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
}

private func dateTimeFormatterFactory() -> DateFormatter {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    return df
}

private var dateTimeFormatter: DateFormatter { dateTimeFormatterFactory() }

private extension AddTaskView {
    func repeatRule() -> RecurrenceRule? {
        guard repeatEnabled else { return nil }
        let anchor = TaskItem.defaultDueDate(dueDate)
        return RecurrenceRule(
            unit: repeatUnit,
            interval: repeatInterval,
            basis: repeatBasis,
            scope: repeatScope,
            countLimit: repeatCountLimitEnabled ? repeatCountLimit : nil,
            occurrencesDone: 0,
            anchor: anchor
        )
    }

    func repeatPreview() -> Date? {
        guard let rule = repeatRule() else { return nil }
        switch rule.basis {
        case .scheduled:
            return RecurrenceEngine.nextOccurrence(from: rule.anchor, rule: rule)
        case .completion:
            // Preview from now (hypothetical completion)
            return RecurrenceEngine.nextOccurrence(from: Date(), rule: rule)
        }
    }
}
