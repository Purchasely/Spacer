//
//  NASADate.swift
//  Spacer
//
//  NASA's daily content (APOD especially) is keyed to the US/Eastern publication
//  clock. We anchor all date-window math to America/New_York so "today" matches
//  NASA regardless of device timezone. Device-clock spoofing is out of scope for
//  a demo (documented in the plan).
//

import Foundation

nonisolated enum NASADate {
    /// America/New_York calendar used for all NASA date-window math.
    static let easternCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return calendar
    }()

    /// "yyyy-MM-dd" formatter in Eastern time — the NASA API date format.
    static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = easternCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// APOD archive floor: the first APOD, 1995-06-16.
    static let apodArchiveFloor: Date = apiFormatter.date(from: "1995-06-16") ?? Date(timeIntervalSince1970: 0)

    /// "Today" in NASA's Eastern publication clock, normalized to start of day.
    static var today: Date {
        easternCalendar.startOfDay(for: Date())
    }

    static func string(from date: Date) -> String {
        apiFormatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        apiFormatter.date(from: string)
    }

    /// The date `days` before `from` (Eastern).
    static func date(daysAgo days: Int, from: Date = today) -> Date {
        easternCalendar.date(byAdding: .day, value: -days, to: from) ?? from
    }

    /// Number of whole days between two dates (Eastern), `to - from`.
    static func dayCount(from: Date, to: Date) -> Int {
        easternCalendar.dateComponents([.day], from: easternCalendar.startOfDay(for: from),
                                       to: easternCalendar.startOfDay(for: to)).day ?? 0
    }

    /// A user-facing medium date string ("Jun 16, 2026").
    static func displayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = easternCalendar.timeZone
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
