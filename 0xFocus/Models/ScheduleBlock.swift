import Foundation

struct ScheduleBlock: Codable, Identifiable, Hashable {
    var id: UUID
    var subject: String
    var company: String?
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    var durationMinutes: Int {
        (endHour * 60 + endMinute) - (startHour * 60 + startMinute)
    }

    var durationInterval: TimeInterval {
        TimeInterval(durationMinutes * 60)
    }

    var startTimeString: String {
        String(format: "%d:%02d", startHour, startMinute)
    }

    var endTimeString: String {
        String(format: "%d:%02d", endHour, endMinute)
    }

    func startTimeToday() -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = startHour
        components.minute = startMinute
        components.second = 0
        return Calendar.current.date(from: components)
    }

    func endTimeToday() -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = endHour
        components.minute = endMinute
        components.second = 0
        return Calendar.current.date(from: components)
    }

    func isActiveNow() -> Bool {
        guard let start = startTimeToday(), let end = endTimeToday() else { return false }
        let now = Date()
        return now >= start && now < end
    }

    static func defaultSchedule() -> [ScheduleBlock] {
        [
            ScheduleBlock(id: UUID(), subject: "DSA", startHour: 6, startMinute: 0, endHour: 8, endMinute: 0),
            ScheduleBlock(id: UUID(), subject: "LLD", startHour: 8, startMinute: 30, endHour: 10, endMinute: 0),
            ScheduleBlock(id: UUID(), subject: "HLD", startHour: 10, startMinute: 30, endHour: 12, endMinute: 30),
            ScheduleBlock(id: UUID(), subject: "Golang", startHour: 14, startMinute: 0, endHour: 16, endMinute: 0),
            ScheduleBlock(id: UUID(), subject: "Company Prep", company: nil, startHour: 16, startMinute: 30, endHour: 18, endMinute: 0),
        ]
    }
}
