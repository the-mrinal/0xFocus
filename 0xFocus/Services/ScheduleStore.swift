import Foundation
import Observation

@Observable
final class ScheduleStore {
    var blocks: [ScheduleBlock] = []
    var interviewBlocks: [InterviewBlock] = []

    private let fileURL: URL
    private let interviewFileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("0xFocus", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("schedule.json")
        self.interviewFileURL = appDir.appendingPathComponent("interviews.json")
        load()
        loadInterviews()
    }

    // MARK: - Schedule Blocks

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            blocks = ScheduleBlock.defaultSchedule()
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            blocks = try JSONDecoder().decode([ScheduleBlock].self, from: data)
        } catch {
            blocks = ScheduleBlock.defaultSchedule()
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(blocks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save schedule: \(error)")
        }
    }

    func addBlock(_ block: ScheduleBlock) {
        blocks.append(block)
        blocks.sort { ($0.startHour * 60 + $0.startMinute) < ($1.startHour * 60 + $1.startMinute) }
        save()
    }

    func removeBlock(_ block: ScheduleBlock) {
        blocks.removeAll { $0.id == block.id }
        save()
    }

    func updateBlock(_ block: ScheduleBlock) {
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
            blocks.sort { ($0.startHour * 60 + $0.startMinute) < ($1.startHour * 60 + $1.startMinute) }
            save()
        }
    }

    func currentBlock() -> ScheduleBlock? {
        // Interview blocks override everything — if interview is active, no schedule block is "current"
        if activeInterview() != nil { return nil }
        return blocks.first { $0.isActiveNow() }
    }

    func nextBlock() -> ScheduleBlock? {
        let now = Date()
        let calendar = Calendar.current
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        // If an interview is active, find next block AFTER the interview ends
        if let interview = activeInterview() {
            let interviewEndMinutes = interview.endHour * 60 + interview.endMinute
            return blocks.first { ($0.startHour * 60 + $0.startMinute) >= interviewEndMinutes }
        }

        return blocks.first { ($0.startHour * 60 + $0.startMinute) > currentMinutes }
    }

    func todayBlocks() -> [ScheduleBlock] {
        // Treat blocks before 5 AM as late-night (sort after everything else)
        func sortKey(_ b: ScheduleBlock) -> Int {
            let minutes = b.startHour * 60 + b.startMinute
            return minutes < 300 ? minutes + 1440 : minutes
        }
        return blocks.sorted { sortKey($0) < sortKey($1) }
    }

    /// All unique subjects from the schedule, in schedule order
    func allSubjects() -> [Subject] {
        var seen = Set<String>()
        var result: [Subject] = []
        for block in todayBlocks() {
            if seen.insert(block.subject).inserted {
                result.append(Subject(name: block.subject))
            }
        }
        return result
    }

    // MARK: - Interview Blocks

    func loadInterviews() {
        guard FileManager.default.fileExists(atPath: interviewFileURL.path) else {
            interviewBlocks = []
            return
        }
        do {
            let data = try Data(contentsOf: interviewFileURL)
            interviewBlocks = try JSONDecoder().decode([InterviewBlock].self, from: data)
        } catch {
            interviewBlocks = []
        }
    }

    func saveInterviews() {
        do {
            let data = try JSONEncoder().encode(interviewBlocks)
            try data.write(to: interviewFileURL, options: .atomic)
        } catch {
            print("Failed to save interviews: \(error)")
        }
    }

    func addInterview(_ block: InterviewBlock) {
        interviewBlocks.append(block)
        interviewBlocks.sort { ($0.date, $0.startHour) < ($1.date, $1.startHour) }
        saveInterviews()
    }

    func removeInterview(_ block: InterviewBlock) {
        interviewBlocks.removeAll { $0.id == block.id }
        saveInterviews()
    }

    /// Returns the currently active interview (if any). Interviews override everything.
    func activeInterview() -> InterviewBlock? {
        interviewBlocks.first { $0.isActiveNow() }
    }

    /// Returns today's interviews sorted by time.
    func todayInterviews() -> [InterviewBlock] {
        interviewBlocks.filter { $0.isToday() }
            .sorted { $0.startHour * 60 + $0.startMinute < $1.startHour * 60 + $1.startMinute }
    }

    /// Returns upcoming interviews (today and future).
    func upcomingInterviews() -> [InterviewBlock] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return interviewBlocks.filter { $0.date >= startOfToday }
            .sorted { ($0.date, $0.startHour) < ($1.date, $1.startHour) }
    }

    // MARK: - Import from text format

    func importFromText(_ text: String) -> [String] {
        let result = ScheduleParser.parse(text)
        if !result.scheduleBlocks.isEmpty {
            blocks = result.scheduleBlocks
            save()
        }
        if !result.interviewBlocks.isEmpty {
            // Replace all interviews on import (not append)
            interviewBlocks = result.interviewBlocks
            // Deduplicate by date+time (same slot = same interview regardless of name)
            var seen = Set<String>()
            interviewBlocks = interviewBlocks.filter { block in
                let key = "\(block.dateString)-\(block.startHour):\(block.startMinute)-\(block.endHour):\(block.endMinute)"
                return seen.insert(key).inserted
            }
            interviewBlocks.sort { ($0.date, $0.startHour) < ($1.date, $1.startHour) }
            saveInterviews()
        }
        return result.errors
    }

    /// Export current schedule + interviews to the text format
    func exportToText() -> String {
        ScheduleParser.export(scheduleBlocks: blocks, interviewBlocks: interviewBlocks)
    }
}
