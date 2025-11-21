import Foundation

enum TaskDifficulty: String, Codable, CaseIterable { case easy, medium, hard }
enum TaskResistance: String, Codable, CaseIterable { case low, medium, high }
enum TaskEstimatedTime: String, Codable, CaseIterable { case short, medium, long }

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    var completedAt: Date? = nil
    var project: ProjectItem?
    // Optional single tag scoped to the task's project
    var tag: String? = nil
    var difficulty: TaskDifficulty
    var resistance: TaskResistance
    var estimatedTime: TaskEstimatedTime
    var dueDate: Date
    var dueTimeComponents: DateComponents? = nil
    // Optional recurrence configuration (Phase 1)
    var recurrence: RecurrenceRule? = nil
    // Up to three reminders per task
    var reminders: [TaskReminder] = []
    // Optional markdown note linked to the task
    var noteMarkdown: String? = nil
    var noteUpdatedAt: Date? = nil

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        project: ProjectItem? = nil,
        difficulty: TaskDifficulty = .easy,
        resistance: TaskResistance = .low,
        estimatedTime: TaskEstimatedTime = .short,
        dueDate: Date = TaskItem.defaultDueDate(),
        dueTimeComponents: DateComponents? = nil,
        reminders: [TaskReminder] = [],
        recurrence: RecurrenceRule? = nil,
        noteMarkdown: String? = nil,
        noteUpdatedAt: Date? = nil,
        tag: String? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.completedAt = nil
        self.project = project
        self.tag = tag
        self.difficulty = difficulty
        self.resistance = resistance
        self.estimatedTime = estimatedTime
        self.dueDate = dueDate
        self.dueTimeComponents = dueTimeComponents
        self.reminders = reminders
        self.recurrence = recurrence
        self.noteMarkdown = noteMarkdown
        self.noteUpdatedAt = noteUpdatedAt
    }

    static func defaultDueDate(_ date: Date = Date()) -> Date {
        // Normalize to start of day to avoid time-of-day variability
        Calendar.current.startOfDay(for: date)
    }

    var hasReminders: Bool { !reminders.isEmpty }

    func dueDateWithTime(using calendar: Calendar = .current) -> Date {
        let day = TaskItem.defaultDueDate(dueDate)
        guard let comps = dueTimeComponents,
              let hour = comps.hour,
              let minute = comps.minute else {
            return day
        }
        var dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        dayComponents.hour = hour
        dayComponents.minute = minute
        return calendar.date(from: dayComponents) ?? day
    }

    func dueTimeDate(using calendar: Calendar = .current) -> Date? {
        guard let comps = dueTimeComponents,
              let hour = comps.hour,
              let minute = comps.minute else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

}

extension TaskItem {
    enum CodingKeys: String, CodingKey {
        case id, title, isDone, completedAt, project, tag, difficulty, resistance, estimatedTime, dueDate, recurrence, noteMarkdown, noteUpdatedAt, dueTimeComponents, reminders, legacyReminderAt = "reminderAt"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        project = try container.decodeIfPresent(ProjectItem.self, forKey: .project)
        tag = try container.decodeIfPresent(String.self, forKey: .tag)
        difficulty = try container.decode(TaskDifficulty.self, forKey: .difficulty)
        resistance = try container.decode(TaskResistance.self, forKey: .resistance)
        estimatedTime = try container.decode(TaskEstimatedTime.self, forKey: .estimatedTime)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        dueTimeComponents = try container.decodeIfPresent(DateComponents.self, forKey: .dueTimeComponents)
        recurrence = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrence)
        reminders = try container.decodeIfPresent([TaskReminder].self, forKey: .reminders) ?? []
        if reminders.isEmpty, let legacy = try container.decodeIfPresent(Date.self, forKey: .legacyReminderAt) {
            reminders = [TaskReminder(kind: .absolute, absoluteDate: legacy)]
        }
        noteMarkdown = try container.decodeIfPresent(String.self, forKey: .noteMarkdown)
        noteUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .noteUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isDone, forKey: .isDone)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(project, forKey: .project)
        try container.encodeIfPresent(tag, forKey: .tag)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(resistance, forKey: .resistance)
        try container.encode(estimatedTime, forKey: .estimatedTime)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(dueTimeComponents, forKey: .dueTimeComponents)
        try container.encodeIfPresent(recurrence, forKey: .recurrence)
        if !reminders.isEmpty {
            try container.encode(reminders, forKey: .reminders)
        }
        try container.encodeIfPresent(noteMarkdown, forKey: .noteMarkdown)
        try container.encodeIfPresent(noteUpdatedAt, forKey: .noteUpdatedAt)
    }
}
