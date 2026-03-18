import SwiftUI
import SwiftData

struct MenuContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(ScheduleStore.self) private var scheduleStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stateHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Upcoming interviews card (next 7 days)
            if case .interview = sessionManager.state {
                // Already showing interview in header
            } else {
                let upcoming = scheduleStore.upcomingInterviews().filter { $0.timeUntilStart() != nil }
                if !upcoming.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UPCOMING INTERVIEWS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)

                        ForEach(upcoming.prefix(5)) { interview in
                            HStack(spacing: 6) {
                                Text("🎯")
                                    .font(.caption)
                                Text(interview.company)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(interview.countdownText())
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.06))
                }
            }

            Divider()

            VStack(spacing: 2) {
                ForEach(scheduleStore.allSubjects()) { subject in
                    subjectRow(subject)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)

            Divider()

            todayStats
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            VStack(spacing: 2) {
                Button {
                    sessionManager.toggleShowSeconds()
                } label: {
                    HStack {
                        Label(
                            sessionManager.showSeconds ? "Hide Seconds" : "Show Seconds",
                            systemImage: sessionManager.showSeconds ? "clock.badge.checkmark" : "clock"
                        )
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "schedule-editor")
                } label: {
                    Label("Edit Schedule...", systemImage: "calendar")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "weekly-summary")
                } label: {
                    Label("Weekly Summary...", systemImage: "chart.bar")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "mobile-settings")
                } label: {
                    Label("Mobile Notifications...", systemImage: "iphone")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit 0xFocus", systemImage: "power")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .padding(.vertical, 4)
        }
        .frame(width: 300)
    }

    // MARK: - State Header

    private var stateHeader: some View {
        Group {
            switch sessionManager.state {
            case .interview(let company):
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("🎯")
                        Text("Interview @ \(company)")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    Text(TimeFormatting.formatDuration(sessionManager.elapsedTime, showSeconds: sessionManager.showSeconds))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text("All schedules paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .studying(let subjectName):
                let subject = Subject.from(rawValue: subjectName)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle().fill(subject.color).frame(width: 8, height: 8)
                        Text("Active: \(subject.displayName)")
                            .font(.headline)
                        Spacer()
                        Button("Stop") { sessionManager.stopSession() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Text(TimeFormatting.formatDuration(sessionManager.elapsedTime, showSeconds: sessionManager.showSeconds))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(subject.color)
                }

            case .overtime(let subjectName):
                let subject = Subject.from(rawValue: subjectName)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("\(subject.displayName) — Overtime")
                            .font(.headline)
                        Spacer()
                        Button("Stop") { sessionManager.stopSession() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Text(TimeFormatting.formatDuration(sessionManager.elapsedTime, showSeconds: sessionManager.showSeconds))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.yellow)
                }

            case .onBreak(let nextSubject, _):
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("☕")
                        Text("On Break")
                            .font(.headline)
                        Spacer()
                    }
                    Text("\(TimeFormatting.formatDuration(max(0, sessionManager.breakTimeRemaining), showSeconds: sessionManager.showSeconds)) until \(nextSubject)")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

            case .pendingStart(let subjectName, _):
                let subject = Subject.from(rawValue: subjectName)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("\(subject.displayName) Scheduled")
                            .font(.headline)
                        Spacer()
                    }
                    Button {
                        sessionManager.startSession(subject: subject)
                    } label: {
                        Text("Start \(subject.displayName)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

            case .idle:
                HStack {
                    Image(systemName: "pause.circle")
                        .foregroundStyle(.secondary)
                    Text("No active session")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Subject Row

    private func subjectRow(_ subject: Subject) -> some View {
        let isInterview = { if case .interview = sessionManager.state { return true }; return false }()
        let isActive: Bool = {
            switch sessionManager.state {
            case .studying(let s), .overtime(let s):
                return s == subject.rawValue
            default:
                return false
            }
        }()
        let isOvertime: Bool = {
            if case .overtime(let s) = sessionManager.state { return s == subject.rawValue }
            return false
        }()
        let todayDuration = sessionManager.todayDuration(for: subject.rawValue)
        let blocks = scheduleStore.todayBlocks().filter { $0.subject == subject.rawValue }
        let scheduledDuration = blocks.reduce(0) { $0 + $1.durationInterval }

        return Button {
            sessionManager.toggleSession(subject: subject)
        } label: {
            HStack(spacing: 8) {
                Text(subject.emoji)
                Text(subject.displayName)
                    .fontWeight(isActive ? .semibold : .regular)
                Spacer()

                if isActive {
                    Text(TimeFormatting.formatDuration(sessionManager.elapsedTime, showSeconds: sessionManager.showSeconds))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(isOvertime ? .yellow : subject.color)
                } else if todayDuration > 0 {
                    Text(TimeFormatting.formatDuration(todayDuration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .foregroundStyle(.quaternary)
                }

                if scheduledDuration > 0 {
                    Text("/ \(TimeFormatting.formatDuration(scheduledDuration))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? (isOvertime ? Color.yellow.opacity(0.12) : subject.color.opacity(0.15)) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isInterview)
        .opacity(isInterview ? 0.4 : 1)
    }

    // MARK: - Today's Stats

    private var todayStats: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Total")
                Spacer()
                Text(TimeFormatting.formatDuration(sessionManager.todayTotalDuration()))
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
            }
        }
    }
}
