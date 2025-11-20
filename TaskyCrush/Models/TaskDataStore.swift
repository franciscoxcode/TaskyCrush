import Foundation
import SwiftData

@MainActor
final class TaskDataStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchProjects() throws -> [ProjectItem] {
        let descriptor = FetchDescriptor<ProjectRecord>(sortBy: [
            SortDescriptor(\.sortOrder, order: .forward),
            SortDescriptor(\.name, order: .forward)
        ])
        let records = try context.fetch(descriptor)
        return records.map(ProjectItem.init(record:))
    }

    func fetchTasks() throws -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskRecord>(sortBy: [
            SortDescriptor(\.dueDate, order: .forward)
        ])
        let records = try context.fetch(descriptor)
        return records.map(TaskItem.init(record:))
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

private extension TaskItem {
    init(record: TaskRecord) {
        self.init(
            id: record.id,
            title: record.title,
            isDone: record.isDone,
            project: record.project.map(ProjectItem.init),
            difficulty: record.difficulty,
            resistance: record.resistance,
            estimatedTime: record.estimatedTime,
            dueDate: record.dueDate,
            dueTimeComponents: record.dueTimeComponents,
            reminders: record.reminders,
            recurrence: record.recurrence,
            noteMarkdown: record.noteMarkdown,
            noteUpdatedAt: record.noteUpdatedAt,
            tag: record.tag
        )
        self.completedAt = record.completedAt
    }
}
