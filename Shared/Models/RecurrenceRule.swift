import Foundation

enum RecurrenceUnit: String, Codable, CaseIterable {
    case minutes, hours, days, weeks, months, years
}

enum RecurrenceBasis: String, Codable, CaseIterable {
    case scheduled   // next occurrence calculated from anchor/scheduled date
    case completion  // next occurrence calculated from completion time
}

enum RecurrenceScope: String, Codable, CaseIterable {
    case allDays
    case weekdaysOnly
    case weekendsOnly
}

struct RecurrenceRule: Codable, Equatable {
    var unit: RecurrenceUnit
    var interval: Int
    var basis: RecurrenceBasis
    var scope: RecurrenceScope
    var countLimit: Int? = nil
    var occurrencesDone: Int = 0
    // Anchor for the series (does not shift on edits unless explicitly reset)
    var anchor: Date
}

