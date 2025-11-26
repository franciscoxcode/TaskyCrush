import Foundation

enum RecurrenceEngine {
    // Preview helper: compute a next occurrence date based on a rule and a base date.
    // - For .scheduled, base is the anchor (typically dueDate).
    // - For .completion, base is the provided completion date (or now for preview).
    static func nextOccurrence(from base: Date, rule: RecurrenceRule) -> Date {
        var candidate = base
        switch rule.unit {
        case .minutes:
            candidate = add(minutes: rule.interval, to: candidate)
        case .hours:
            candidate = add(hours: rule.interval, to: candidate)
        case .days:
            candidate = addBusinessDays(rule.interval, to: candidate, scope: rule.scope)
        case .weeks:
            candidate = addWeeks(rule.interval, to: candidate, scope: rule.scope)
        case .months:
            candidate = addMonthsClamped(rule.interval, to: candidate)
            candidate = applyScope(candidate, scope: rule.scope)
        case .years:
            candidate = addYearsClamped(rule.interval, to: candidate)
            candidate = applyScope(candidate, scope: rule.scope)
        }
        return normalize(candidate)
    }

    private static func normalize(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private static func add(minutes: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: date) ?? date
    }

    private static func add(hours: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: date) ?? date
    }

    private static func addWeeks(_ weeks: Int, to date: Date, scope: RecurrenceScope) -> Date {
        let days = weeks * 7
        let raw = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return applyScope(raw, scope: scope)
    }

    // Adds days respecting scope: all days, weekdays, weekends.
    private static func addBusinessDays(_ days: Int, to date: Date, scope: RecurrenceScope) -> Date {
        switch scope {
        case .allDays:
            return Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        case .weekdaysOnly:
            return addWeekdays(days, to: date)
        case .weekendsOnly:
            return addWeekends(days, to: date)
        }
    }

    private static func isWeekend(_ date: Date) -> Bool {
        let wd = Calendar.current.component(.weekday, from: date)
        return wd == 7 || wd == 1 // Sat=7, Sun=1 in Gregorian
    }

    // Add N weekdays (Mon-Fri) skipping weekends
    private static func addWeekdays(_ count: Int, to date: Date) -> Date {
        var d = date
        var added = 0
        while added < count {
            d = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d
            if !isWeekend(d) { added += 1 }
        }
        return d
    }

    // Add N weekend days (jumping to next Saturday first if needed)
    private static func addWeekends(_ count: Int, to date: Date) -> Date {
        var d = date
        // move to next Saturday anchor if not weekend
        if !isWeekend(d) { d = nextSaturday(from: d) }
        var added = 0
        while added < count {
            d = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d
            if isWeekend(d) { added += 1 }
        }
        // Snap back to Saturday as canonical anchor
        return previousOrSameSaturday(from: d)
    }

    private static func nextSaturday(from date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let sat = 7
        let wd = cal.component(.weekday, from: date)
        var diff = sat - wd
        if diff <= 0 { diff += 7 }
        return cal.date(byAdding: .day, value: diff, to: date) ?? date
    }

    private static func previousOrSameSaturday(from date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let wd = cal.component(.weekday, from: date)
        let diff = wd - 7
        return cal.date(byAdding: .day, value: -diff, to: date) ?? date
    }

    private static func addMonthsClamped(_ months: Int, to date: Date) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        var m = DateComponents()
        m.month = months
        let target = cal.date(byAdding: m, to: date) ?? date
        var t = cal.dateComponents([.year, .month], from: target)
        let day = min(max(1, comps.day ?? 1), lastDay(ofMonth: t.month ?? 1, year: t.year ?? comps.year ?? 2000))
        t.day = day
        return cal.date(from: t) ?? target
    }

    private static func addYearsClamped(_ years: Int, to date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        var y = DateComponents()
        y.year = years
        let target = cal.date(byAdding: y, to: date) ?? date
        var t = cal.dateComponents([.year, .month], from: target)
        let day = min(max(1, comps.day ?? 1), lastDay(ofMonth: t.month ?? 1, year: t.year ?? comps.year ?? 2000))
        t.day = day
        return cal.date(from: t) ?? target
    }

    private static func lastDay(ofMonth month: Int, year: Int) -> Int {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let date = cal.date(from: comps) ?? Date()
        // Calendar returns a half-open Range; provide a matching fallback (1..<32)
        let range = cal.range(of: .day, in: .month, for: date) ?? (1..<32)
        return range.upperBound - 1
    }

    private static func applyScope(_ date: Date, scope: RecurrenceScope) -> Date {
        switch scope {
        case .allDays:
            return date
        case .weekdaysOnly:
            // move forward to next weekday if falls on weekend
            var d = date
            while isWeekend(d) {
                d = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d
            }
            return d
        case .weekendsOnly:
            // move forward to next Saturday if not weekend
            return isWeekend(date) ? previousOrSameSaturday(from: date) : nextSaturday(from: date)
        }
    }
}
