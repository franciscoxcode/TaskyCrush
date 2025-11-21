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
        let projects = try fetchProjectRecordsByID()
        return records.map { record in
            let resolvedProject = record.projectId.flatMap { projects[$0] }.map(ProjectItem.init(record:)) ?? record.projectSnapshot
            var item = TaskItem(
                id: record.id,
                title: record.title,
                isDone: record.isDone,
                project: resolvedProject,
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
            item.completedAt = record.completedAt
            return item
        }
    }

    func saveProjects(_ projects: [ProjectItem]) throws {
        let descriptor = FetchDescriptor<ProjectRecord>()
        let existing = try context.fetch(descriptor)
        var lookup = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIds = Set(projects.map(\.id))

        for record in existing where !incomingIds.contains(record.id) {
            context.delete(record)
        }

        for project in projects {
            if let record = lookup[project.id] {
                record.name = project.name
                record.emoji = project.emoji
                record.colorName = project.colorName
                record.sortOrder = project.sortOrder
                record.tags = project.tags ?? []
            } else {
                let newRecord = ProjectRecord(
                    id: project.id,
                    name: project.name,
                    emoji: project.emoji,
                    colorName: project.colorName,
                    sortOrder: project.sortOrder,
                    tags: project.tags ?? []
                )
                context.insert(newRecord)
                lookup[project.id] = newRecord
            }
        }

        try context.save()
    }

    func saveTasks(_ tasks: [TaskItem]) throws {
        let descriptor = FetchDescriptor<TaskRecord>()
        let existing = try context.fetch(descriptor)
        var lookup = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIds = Set(tasks.map(\.id))

        for record in existing where !incomingIds.contains(record.id) {
            context.delete(record)
        }

        for task in tasks {
            if let record = lookup[task.id] {
                update(record: record, with: task)
            } else {
                let newRecord = TaskRecord(
                    id: task.id,
                    title: task.title,
                    isDone: task.isDone,
                    projectId: task.project?.id,
                    tag: task.tag,
                    difficulty: task.difficulty,
                    resistance: task.resistance,
                    estimatedTime: task.estimatedTime,
                    dueDate: task.dueDate,
                    dueTimeComponents: task.dueTimeComponents,
                    recurrence: task.recurrence,
                    noteMarkdown: task.noteMarkdown,
                    noteUpdatedAt: task.noteUpdatedAt,
                    reminders: task.reminders,
                    projectSnapshot: task.project
                )
                newRecord.completedAt = task.completedAt
                lookup[task.id] = newRecord
                context.insert(newRecord)
            }
        }

        try context.save()
    }

    private func update(record: TaskRecord, with task: TaskItem) {
        record.title = task.title
        record.isDone = task.isDone
        record.completedAt = task.completedAt
        record.projectId = task.project?.id
        record.projectSnapshot = task.project
        record.tag = task.tag
        record.difficulty = task.difficulty
        record.resistance = task.resistance
        record.estimatedTime = task.estimatedTime
        record.dueDate = task.dueDate
        record.dueTimeComponents = task.dueTimeComponents
        record.recurrence = task.recurrence
        record.reminders = task.reminders
        record.noteMarkdown = task.noteMarkdown
        record.noteUpdatedAt = task.noteUpdatedAt
    }

    private func fetchProjectRecordsByID() throws -> [UUID: ProjectRecord] {
        let descriptor = FetchDescriptor<ProjectRecord>()
        let records = try context.fetch(descriptor)
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
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
