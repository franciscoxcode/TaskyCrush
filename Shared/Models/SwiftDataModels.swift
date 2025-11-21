import Foundation
import SwiftData

@Model
final class ProjectRecord {
    var id: UUID = Foundation.UUID()
    var name: String = ""
    var emoji: String = "📁"
    var colorName: String?
    var sortOrder: Int?
    @Attribute(.externalStorage) private var encodedTags: Data? = nil

    var tags: [String] {
        get { decode([String].self, from: encodedTags) ?? [] }
        set { encodedTags = encode(newValue) }
    }

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        colorName: String? = nil,
        sortOrder: Int? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorName = colorName
        self.sortOrder = sortOrder
        self.encodedTags = encode(tags)
    }
}

@Model
final class TaskRecord {
    var id: UUID = Foundation.UUID()
    var title: String = ""
    var isDone: Bool = false
    var completedAt: Date?
    var projectId: UUID?
    var tag: String?
    var difficulty: TaskDifficulty = TaskDifficulty.easy
    var resistance: TaskResistance = TaskResistance.low
    var estimatedTime: TaskEstimatedTime = TaskEstimatedTime.short
    var dueDate: Date = Foundation.Date()
    @Attribute(.externalStorage) private var encodedDueTimeComponents: Data? = nil
    @Attribute(.externalStorage) private var encodedRecurrence: Data? = nil
    @Attribute(.externalStorage) private var encodedReminders: Data? = nil
    @Attribute(.externalStorage) private var encodedProjectSnapshot: Data? = nil
    var noteMarkdown: String?
    var noteUpdatedAt: Date?

    var remindersStorage: Data? {
        get { encodedReminders }
        set { encodedReminders = newValue }
    }

    var dueTimeComponents: DateComponents? {
        get { decode(DateComponents.self, from: encodedDueTimeComponents) }
        set { encodedDueTimeComponents = encode(newValue) }
    }

    var recurrence: RecurrenceRule? {
        get { decode(RecurrenceRule.self, from: encodedRecurrence) }
        set { encodedRecurrence = encode(newValue) }
    }

    // Explicitly mark as transient to prevent SwiftData from generating accessors.
    @Transient
    private var remindersBackingStore: [TaskReminder] {
        get { decode([TaskReminder].self, from: remindersStorage) ?? [] }
        set { remindersStorage = encode(newValue) }
    }

    var reminders: [TaskReminder] {
        get { remindersBackingStore }
        set { remindersBackingStore = newValue }
    }

    var projectSnapshot: ProjectItem? {
        get { decode(ProjectItem.self, from: encodedProjectSnapshot) }
        set { encodedProjectSnapshot = encode(newValue) }
    }

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        projectId: UUID? = nil,
        tag: String? = nil,
        difficulty: TaskDifficulty = .easy,
        resistance: TaskResistance = .low,
        estimatedTime: TaskEstimatedTime = .short,
        dueDate: Date = Calendar.current.startOfDay(for: Date()),
        dueTimeComponents: DateComponents? = nil,
        recurrence: RecurrenceRule? = nil,
        noteMarkdown: String? = nil,
        noteUpdatedAt: Date? = nil,
        reminders: [TaskReminder] = [],
        projectSnapshot: ProjectItem? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.completedAt = nil
        self.projectId = projectId
        self.tag = tag
        self.difficulty = difficulty
        self.resistance = resistance
        self.estimatedTime = estimatedTime
        self.dueDate = dueDate
        self.encodedDueTimeComponents = encode(dueTimeComponents)
        self.encodedRecurrence = encode(recurrence)
        self.encodedReminders = encode(reminders)
        self.noteMarkdown = noteMarkdown
        self.noteUpdatedAt = noteUpdatedAt
        self.projectSnapshot = projectSnapshot
    }
}

private func encode<T: Codable>(_ value: T?) -> Data? {
    guard let value else { return nil }
    do {
        return try JSONEncoder().encode(value)
    } catch {
        assertionFailure("Failed to encode value: \(error)")
        return nil
    }
}

private func decode<T: Codable>(_ type: T.Type, from data: Data?) -> T? {
    guard let data else { return nil }
    do {
        return try JSONDecoder().decode(type, from: data)
    } catch {
        assertionFailure("Failed to decode value: \(error)")
        return nil
    }
}
