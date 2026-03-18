import Foundation

enum TimeFormatting {
    static func formatDuration(_ interval: TimeInterval, showSeconds: Bool = false) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if showSeconds {
            if hours > 0 {
                return "\(hours)h \(String(format: "%02d", minutes))m \(String(format: "%02d", seconds))s"
            } else if minutes > 0 {
                return "\(minutes)m \(String(format: "%02d", seconds))s"
            } else {
                return "\(seconds)s"
            }
        } else {
            if hours > 0 {
                return "\(hours)h \(String(format: "%02d", minutes))m"
            } else {
                return "\(minutes)m"
            }
        }
    }

    static func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}
