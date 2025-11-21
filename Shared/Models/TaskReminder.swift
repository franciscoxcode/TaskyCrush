import Foundation

struct TaskReminder: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case relative
        case absolute

        var id: String { rawValue }

        var label: String {
            switch self {
            case .relative: return "Before due date"
            case .absolute: return "Specific date"
            }
        }
    }

    enum RelativeUnit: String, Codable, CaseIterable, Identifiable {
        case minutes
        case hours
        case days
        case weeks

        var id: String { rawValue }

        var singularName: String {
            switch self {
            case .minutes: return "minute"
            case .hours: return "hour"
            case .days: return "day"
            case .weeks: return "week"
            }
        }

        var pluralName: String {
            singularName + "s"
        }

        var usesSubDayPrecision: Bool {
            switch self {
            case .minutes, .hours: return true
            case .days, .weeks: return false
            }
        }
    }

    var id: UUID
    var kind: Kind
    var relativeValue: Int
    var relativeUnit: RelativeUnit
    var absoluteDate: Date

    init(
        id: UUID = UUID(),
        kind: Kind = .relative,
        relativeValue: Int = 1,
        relativeUnit: RelativeUnit = .days,
        absoluteDate: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.relativeValue = max(1, relativeValue)
        self.relativeUnit = relativeUnit
        self.absoluteDate = absoluteDate
    }

    func resolvedDate(for task: TaskItem, calendar: Calendar = .current) -> Date? {
        switch kind {
        case .absolute:
            return absoluteDate
        case .relative:
            guard relativeValue > 0 else { return nil }
            let anchor = task.dueDateWithTime(using: calendar)
            var comps = DateComponents()
            switch relativeUnit {
            case .minutes:
                comps.minute = -relativeValue
            case .hours:
                comps.hour = -relativeValue
            case .days:
                comps.day = -relativeValue
            case .weeks:
                comps.day = -(relativeValue * 7)
            }
            return calendar.date(byAdding: comps, to: anchor)
        }
    }

    func copyForNextOccurrence() -> TaskReminder? {
        switch kind {
        case .relative:
            return TaskReminder(id: UUID(), kind: .relative, relativeValue: relativeValue, relativeUnit: relativeUnit)
        case .absolute:
            return nil
        }
    }

        var summaryLabel: String {
            switch kind {
            case .absolute:
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .short
                return df.string(from: absoluteDate)
            case .relative:
                let unitName = (relativeValue == 1) ? relativeUnit.singularName : relativeUnit.pluralName
                return "\(relativeValue) \(unitName) before"
            }
        }
}

extension TaskReminder {
    enum CodingKeys: String, CodingKey {
        case id, kind, relativeValue, relativeUnit, absoluteDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let relativeValue = try container.decodeIfPresent(Int.self, forKey: .relativeValue) ?? 1
        let relativeUnit = try container.decodeIfPresent(RelativeUnit.self, forKey: .relativeUnit) ?? .days
        let absoluteDate = try container.decodeIfPresent(Date.self, forKey: .absoluteDate) ?? Date()
        self.init(id: id, kind: kind, relativeValue: relativeValue, relativeUnit: relativeUnit, absoluteDate: absoluteDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(relativeValue, forKey: .relativeValue)
        try container.encode(relativeUnit, forKey: .relativeUnit)
        try container.encode(absoluteDate, forKey: .absoluteDate)
    }
}
