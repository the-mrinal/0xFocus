import Foundation

struct InterviewBlock: Codable, Identifiable, Hashable {
    var id: UUID
    var company: String
    var date: Date         // specific date (not recurring like schedule blocks)
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    var durationMinutes: Int {
        (endHour * 60 + endMinute) - (startHour * 60 + startMinute)
    }

    var startTimeString: String {
        TimeFormatting.formatTime(hour: startHour, minute: startMinute)
    }

    var endTimeString: String {
        TimeFormatting.formatTime(hour: endHour, minute: endMinute)
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var displayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Is this interview block happening right now?
    func isActiveNow() -> Bool {
        let calendar = Calendar.current
        guard calendar.isDateInToday(date) else { return false }
        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startComponents.hour = startHour
        startComponents.minute = startMinute
        var endComponents = startComponents
        endComponents.hour = endHour
        endComponents.minute = endMinute

        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(from: endComponents) else { return false }

        let now = Date()
        return now >= start && now < end
    }

    /// Is this interview today (but maybe not active right now)?
    func isToday() -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func startDateTime() -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = startHour
        components.minute = startMinute
        components.second = 0
        return calendar.date(from: components)
    }

    func endDateTime() -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = endHour
        components.minute = endMinute
        components.second = 0
        return calendar.date(from: components)
    }

    /// Time remaining until this interview starts. Nil if already started or passed.
    func timeUntilStart() -> TimeInterval? {
        guard let start = startDateTime() else { return nil }
        let remaining = start.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    /// Human-readable countdown: "in 2h 30m", "Tomorrow 2:00 PM", "Mar 22 10:00 AM"
    func countdownText() -> String {
        guard let remaining = timeUntilStart() else { return "now" }
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "in \(TimeFormatting.formatDuration(remaining))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(startTimeString)"
        } else {
            return "\(displayDateString) \(startTimeString)"
        }
    }

    /// Is this interview within the next N hours?
    func isWithinHours(_ hours: Double) -> Bool {
        guard let remaining = timeUntilStart() else { return false }
        return remaining <= hours * 3600
    }
}
