import Foundation

/// Parses a simple text format into schedule blocks and interview blocks.
///
/// Format:
/// ```
/// # Daily Schedule
/// 06:00-08:00 DSA
/// 08:30-10:00 LLD
/// 10:30-12:30 HLD
/// 14:00-16:00 Golang
/// 16:30-18:00 Company Prep @ Google
///
/// # Interview Blocks
/// 2026-03-20 14:00-15:00 Interview @ Google
/// 2026-03-22 10:00-11:30 Interview @ Uber
/// ```
enum ScheduleParser {

    struct ParseResult {
        var scheduleBlocks: [ScheduleBlock]
        var interviewBlocks: [InterviewBlock]
        var errors: [String]
    }

    static func parse(_ text: String) -> ParseResult {
        var scheduleBlocks: [ScheduleBlock] = []
        var interviewBlocks: [InterviewBlock] = []
        var errors: [String] = []

        var currentSection = "schedule" // default section

        let lines = text.components(separatedBy: .newlines)

        for (lineNumber, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if line.isEmpty { continue }
            if line.hasPrefix("//") { continue }

            // Section headers
            if line.hasPrefix("#") {
                let header = line.dropFirst().trimmingCharacters(in: .whitespaces).lowercased()
                if header.contains("interview") {
                    currentSection = "interview"
                } else {
                    currentSection = "schedule"
                }
                continue
            }

            if currentSection == "interview" {
                if let block = parseInterviewLine(line) {
                    interviewBlocks.append(block)
                } else {
                    errors.append("Line \(lineNumber + 1): Could not parse interview: \"\(line)\"")
                }
            } else {
                if let block = parseScheduleLine(line) {
                    scheduleBlocks.append(block)
                } else {
                    errors.append("Line \(lineNumber + 1): Could not parse schedule: \"\(line)\"")
                }
            }
        }

        // Sort
        scheduleBlocks.sort { ($0.startHour * 60 + $0.startMinute) < ($1.startHour * 60 + $1.startMinute) }
        interviewBlocks.sort { ($0.date, $0.startHour) < ($1.date, $1.startHour) }

        return ParseResult(scheduleBlocks: scheduleBlocks, interviewBlocks: interviewBlocks, errors: errors)
    }

    /// Parses: "06:00-08:00 DSA" or "16:30-18:00 Company Prep @ Google"
    private static func parseScheduleLine(_ line: String) -> ScheduleBlock? {
        // Pattern: HH:MM-HH:MM Subject [@ Company]
        let pattern = #"^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})\s+(.+)$"#
        guard let match = line.range(of: pattern, options: .regularExpression) else { return nil }

        let parts = extractTimeAndRest(from: line)
        guard let parts = parts else { return nil }

        var subject = parts.rest
        var company: String? = nil

        // Check for "@ Company" suffix
        if let atRange = subject.range(of: #"\s*@\s*"#, options: .regularExpression) {
            company = String(subject[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            subject = String(subject[..<atRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        return ScheduleBlock(
            id: UUID(),
            subject: subject,
            company: company,
            startHour: parts.startHour,
            startMinute: parts.startMinute,
            endHour: parts.endHour,
            endMinute: parts.endMinute
        )
    }

    /// Parses: "2026-03-20 14:00-15:00 Interview @ Google"
    private static func parseInterviewLine(_ line: String) -> InterviewBlock? {
        // Pattern: YYYY-MM-DD HH:MM-HH:MM Interview @ Company
        let pattern = #"^(\d{4}-\d{2}-\d{2})\s+(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})\s+(.+)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func group(_ i: Int) -> String? {
            guard let range = Range(match.range(at: i), in: line) else { return nil }
            return String(line[range])
        }

        guard let dateStr = group(1),
              let startH = group(2).flatMap({ Int($0) }),
              let startM = group(3).flatMap({ Int($0) }),
              let endH = group(4).flatMap({ Int($0) }),
              let endM = group(5).flatMap({ Int($0) }),
              let rest = group(6) else {
            return nil
        }

        // Parse date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateStr) else { return nil }

        // Extract company from "Interview @ Company" or just "@ Company"
        var company = rest
        if let atRange = company.range(of: #"@\s*"#, options: .regularExpression) {
            company = String(company[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            // If no @, use the whole rest as company (e.g., "Google Interview")
            company = company.replacingOccurrences(of: "Interview", with: "").trimmingCharacters(in: .whitespaces)
            if company.isEmpty { company = "Unknown" }
        }

        return InterviewBlock(
            id: UUID(),
            company: company,
            date: date,
            startHour: startH,
            startMinute: startM,
            endHour: endH,
            endMinute: endM
        )
    }

    private struct TimeParts {
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
        let rest: String
    }

    private static func extractTimeAndRest(from line: String) -> TimeParts? {
        let pattern = #"^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func group(_ i: Int) -> String? {
            guard let range = Range(match.range(at: i), in: line) else { return nil }
            return String(line[range])
        }

        guard let sh = group(1).flatMap({ Int($0) }),
              let sm = group(2).flatMap({ Int($0) }),
              let eh = group(3).flatMap({ Int($0) }),
              let em = group(4).flatMap({ Int($0) }),
              let rest = group(5) else { return nil }

        return TimeParts(startHour: sh, startMinute: sm, endHour: eh, endMinute: em, rest: rest)
    }

    // MARK: - Export (generate the text format from existing data)

    static func export(scheduleBlocks: [ScheduleBlock], interviewBlocks: [InterviewBlock]) -> String {
        var lines: [String] = []
        lines.append("# Daily Schedule")

        for block in scheduleBlocks.sorted(by: { ($0.startHour * 60 + $0.startMinute) < ($1.startHour * 60 + $1.startMinute) }) {
            let time = String(format: "%02d:%02d-%02d:%02d", block.startHour, block.startMinute, block.endHour, block.endMinute)
            if let company = block.company, !company.isEmpty {
                lines.append("\(time) \(block.subject) @ \(company)")
            } else {
                lines.append("\(time) \(block.subject)")
            }
        }

        if !interviewBlocks.isEmpty {
            lines.append("")
            lines.append("# Interview Blocks")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            for block in interviewBlocks.sorted(by: { ($0.date, $0.startHour) < ($1.date, $1.startHour) }) {
                let date = formatter.string(from: block.date)
                let time = String(format: "%02d:%02d-%02d:%02d", block.startHour, block.startMinute, block.endHour, block.endMinute)
                lines.append("\(date) \(time) Interview @ \(block.company)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
