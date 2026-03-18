import Foundation
import SwiftData
import Observation

enum SessionState: Equatable {
    case idle
    case studying(subject: String)
    case onBreak(nextSubject: String, breakEndsAt: Date)
    case overtime(subject: String)
    case pendingStart(subject: String, scheduledAt: Date)
    case interview(company: String)
}

@Observable
final class SessionManager {
    var activeSession: StudySession?
    var elapsedTime: TimeInterval = 0
    var activeCompany: String?
    var showSeconds: Bool = UserDefaults.standard.bool(forKey: "showSeconds")
    var state: SessionState = .idle
    var breakTimeRemaining: TimeInterval = 0

    private var timer: Timer?
    private var modelContext: ModelContext?

    var scheduleStore: ScheduleStore?

    private var notifiedBlockEndIds: Set<UUID> = []
    private var notifiedBreakEndIds: Set<UUID> = []
    private var notifiedReminderIds: Set<UUID> = []
    private var interviewNotified: Bool = false
    // Track which interview reminder thresholds we've already sent (keyed by "interviewId-threshold")
    private var sentInterviewReminders: Set<String> = []

    private var sessionStartedAt: Date?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func toggleShowSeconds() {
        showSeconds.toggle()
        UserDefaults.standard.set(showSeconds, forKey: "showSeconds")
    }

    // MARK: - Menu Bar Text

    /// Nearest upcoming interview within 24 hours (for menu bar suffix)
    var nearestUpcomingInterview: InterviewBlock? {
        scheduleStore?.upcomingInterviews().first { $0.isWithinHours(24) && $0.timeUntilStart() != nil }
    }

    var menuBarText: String {
        // Interview active — full takeover
        if case .interview(let company) = state {
            let elapsed = TimeFormatting.formatDuration(elapsedTime, showSeconds: showSeconds)
            return "🎯 Interview @ \(company)  \(elapsed)"
        }

        var base: String

        switch state {
        case .studying(let subject):
            let sub = Subject.from(rawValue: subject)
            let elapsed = TimeFormatting.formatDuration(elapsedTime, showSeconds: showSeconds)
            if let block = currentScheduledBlock(for: subject) {
                let scheduled = TimeFormatting.formatDuration(block.durationInterval)
                base = "\(sub.emoji) \(sub.displayName)  \(elapsed) / \(scheduled)"
            } else {
                base = "\(sub.emoji) \(sub.displayName)  \(elapsed)"
            }

        case .overtime(let subject):
            let sub = Subject.from(rawValue: subject)
            let elapsed = TimeFormatting.formatDuration(elapsedTime, showSeconds: showSeconds)
            base = "⚠️ \(sub.displayName) (overtime)  \(elapsed)"

        case .onBreak(let nextSubject, _):
            let remaining = TimeFormatting.formatDuration(max(0, breakTimeRemaining), showSeconds: showSeconds)
            base = "☕ Break  \(remaining) → \(nextSubject)"

        case .pendingStart(let subject, _):
            base = "⚠️ \(subject) scheduled — tap to start"

        case .idle:
            if let next = scheduleStore?.nextBlock() {
                let time = TimeFormatting.formatTime(hour: next.startHour, minute: next.startMinute)
                base = "Next: \(next.subject) at \(time)"
            } else {
                base = "⏸ Break"
            }

        case .interview:
            base = ""
        }

        // Append nearest interview countdown (within 24h)
        if let interview = nearestUpcomingInterview {
            base += "  •  🎯 \(interview.company) \(interview.countdownText())"
        }

        return base
    }

    // MARK: - Session Control

    func startSession(subject: Subject, company: String? = nil) {
        // Interview blocks cannot be overridden
        if case .interview = state { return }

        stopSession(silent: true)

        let session = StudySession(subject: subject.rawValue, company: company)
        activeSession = session
        activeCompany = company
        elapsedTime = 0
        sessionStartedAt = Date()
        state = .studying(subject: subject.rawValue)

        modelContext?.insert(session)
        try? modelContext?.save()

        startTimer()
    }

    func stopSession(silent: Bool = false) {
        // Cannot stop an interview via normal stop
        if case .interview = state, !silent { return }

        timer?.invalidate()
        timer = nil

        if let session = activeSession {
            session.endTime = Date()
            try? modelContext?.save()
        }

        activeSession = nil
        activeCompany = nil
        elapsedTime = 0
        breakTimeRemaining = 0
        sessionStartedAt = nil

        if !silent {
            state = .idle
        }
    }

    func toggleSession(subject: Subject, company: String? = nil) {
        // Can't toggle during interview
        if case .interview = state { return }

        if let active = activeSession, active.subject == subject.rawValue {
            stopSession()
        } else {
            startSession(subject: subject, company: company)
        }
    }

    func enterBreak(nextBlock: ScheduleBlock) {
        stopSession(silent: true)

        guard let breakEnd = nextBlock.startTimeToday() else {
            state = .idle
            return
        }

        state = .onBreak(nextSubject: nextBlock.subject, breakEndsAt: breakEnd)
        breakTimeRemaining = breakEnd.timeIntervalSinceNow
        startTimer()
    }

    func startFromNotification(subjectName: String) {
        let subject = Subject.from(rawValue: subjectName)
        startSession(subject: subject)
    }

    // MARK: - Interview Control

    func startInterview(company: String) {
        // Force-stop everything — interview overrides all
        timer?.invalidate()
        timer = nil
        if let session = activeSession {
            session.endTime = Date()
            try? modelContext?.save()
        }
        activeSession = nil
        activeCompany = nil
        breakTimeRemaining = 0

        // Log interview as a special session
        let session = StudySession(subject: "Interview", company: company)
        activeSession = session
        activeCompany = company
        elapsedTime = 0
        sessionStartedAt = Date()
        state = .interview(company: company)

        modelContext?.insert(session)
        try? modelContext?.save()

        startTimer()
    }

    func endInterview() {
        timer?.invalidate()
        timer = nil
        if let session = activeSession {
            session.endTime = Date()
            try? modelContext?.save()
        }
        activeSession = nil
        activeCompany = nil
        elapsedTime = 0
        sessionStartedAt = nil
        interviewNotified = false
        state = .idle
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        let now = Date()

        // Check for interview override FIRST — interviews trump everything
        if case .interview = state {
            // Interview running — just update elapsed
            if let session = activeSession {
                elapsedTime = now.timeIntervalSince(session.startTime)
            }
            // Check if interview block ended
            if let store = scheduleStore, store.activeInterview() == nil {
                // Interview time slot is over
                endInterview()
            }
            return
        }

        // Check if an interview just started (override everything)
        if let store = scheduleStore, let interview = store.activeInterview(), !interviewNotified {
            interviewNotified = true
            startInterview(company: interview.company)
            NotificationService.shared.sendInterviewNotification(company: interview.company)
            return
        }

        // Check interview countdown reminders (24h, 2h, 30min before)
        checkInterviewReminders(now: now)

        switch state {
        case .studying(let subject):
            if let session = activeSession {
                elapsedTime = now.timeIntervalSince(session.startTime)
            }
            checkBlockEnd(subject: subject, now: now)

        case .overtime:
            if let session = activeSession {
                elapsedTime = now.timeIntervalSince(session.startTime)
            }

        case .onBreak(let nextSubject, let breakEndsAt):
            breakTimeRemaining = breakEndsAt.timeIntervalSince(now)
            if breakTimeRemaining <= 0 {
                handleBreakEnd(nextSubject: nextSubject, now: now)
            }

        case .pendingStart(let subject, let scheduledAt):
            if now.timeIntervalSince(scheduledAt) >= 300 {
                if let block = findBlock(for: subject), !notifiedReminderIds.contains(block.id) {
                    notifiedReminderIds.insert(block.id)
                    NotificationService.shared.sendReminderNotification(subject: subject)
                }
            }

        case .idle, .interview:
            break
        }
    }

    // MARK: - Interview Countdown Reminders

    private func checkInterviewReminders(now: Date) {
        guard let store = scheduleStore else { return }

        // Thresholds: 24h, 2h, 30min (in seconds)
        let thresholds: [(seconds: TimeInterval, label: String, priority: Int)] = [
            (24 * 3600, "24h", 3),
            (2 * 3600, "2h", 4),
            (30 * 60, "30min", 5),
        ]

        for interview in store.upcomingInterviews() {
            guard let remaining = interview.timeUntilStart() else { continue }

            for threshold in thresholds {
                let key = "\(interview.id.uuidString)-\(threshold.label)"
                guard !sentInterviewReminders.contains(key) else { continue }

                if remaining <= threshold.seconds {
                    sentInterviewReminders.insert(key)
                    NotificationService.shared.sendInterviewReminder(
                        company: interview.company,
                        countdown: interview.countdownText(),
                        threshold: threshold.label,
                        priority: threshold.priority
                    )
                }
            }
        }
    }

    // MARK: - Schedule Transition Logic

    private func checkBlockEnd(subject: String, now: Date) {
        guard let store = scheduleStore else { return }
        guard let startedAt = sessionStartedAt else { return }

        let blocks = store.todayBlocks()
        guard let currentIndex = blocks.firstIndex(where: { $0.subject == subject }),
              let endTime = blocks[currentIndex].endTimeToday() else {
            return
        }

        let block = blocks[currentIndex]

        guard startedAt < endTime else { return }
        guard now >= endTime && !notifiedBlockEndIds.contains(block.id) else { return }

        notifiedBlockEndIds.insert(block.id)

        let nextBlock = currentIndex + 1 < blocks.count ? blocks[currentIndex + 1] : nil

        if let nextBlock = nextBlock {
            let breakMinutes = gapMinutes(from: block, to: nextBlock)

            NotificationService.shared.sendBlockEndNotification(
                completedSubject: subject,
                nextBlock: nextBlock,
                breakMinutes: breakMinutes
            )

            if breakMinutes > 0 {
                enterBreak(nextBlock: nextBlock)
            } else {
                state = .overtime(subject: subject)
            }
        } else {
            NotificationService.shared.sendBlockEndNotification(
                completedSubject: subject,
                nextBlock: nil,
                breakMinutes: 0
            )
            state = .overtime(subject: subject)
        }
    }

    private func handleBreakEnd(nextSubject: String, now: Date) {
        if let block = findBlock(for: nextSubject), !notifiedBreakEndIds.contains(block.id) {
            notifiedBreakEndIds.insert(block.id)
            NotificationService.shared.sendBreakEndNotification(nextBlock: block)
        }

        timer?.invalidate()
        timer = nil
        activeSession = nil
        sessionStartedAt = nil

        state = .pendingStart(subject: nextSubject, scheduledAt: now)
        startTimer()
    }

    // MARK: - Helpers

    private func currentScheduledBlock(for subject: String) -> ScheduleBlock? {
        scheduleStore?.todayBlocks().first { $0.subject == subject && $0.isActiveNow() }
    }

    private func gapMinutes(from block: ScheduleBlock, to next: ScheduleBlock) -> Int {
        let endMinutes = block.endHour * 60 + block.endMinute
        let startMinutes = next.startHour * 60 + next.startMinute
        return max(0, startMinutes - endMinutes)
    }

    private func findBlock(for subject: String) -> ScheduleBlock? {
        scheduleStore?.todayBlocks().first { $0.subject == subject }
    }

    // MARK: - Stats

    func todaySessions() -> [StudySession] {
        guard let context = modelContext else { return [] }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<StudySession> { $0.startTime >= startOfDay }
        let descriptor = FetchDescriptor<StudySession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func todayDuration(for subject: String) -> TimeInterval {
        todaySessions()
            .filter { $0.subject == subject }
            .reduce(0) { $0 + $1.duration }
    }

    func todayTotalDuration() -> TimeInterval {
        todaySessions().reduce(0) { $0 + $1.duration }
    }
}
