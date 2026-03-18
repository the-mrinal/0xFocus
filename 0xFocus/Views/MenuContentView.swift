import SwiftUI
import SwiftData

struct MenuContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(ScheduleStore.self) private var scheduleStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // State header in a glass card
            stateHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 8)
                .padding(.top, 8)

            // Date + time header
            HStack {
                Text(currentDateString())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currentTimeString())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)

            // Upcoming interviews
            if case .interview = sessionManager.state {
            } else {
                let upcoming = scheduleStore.upcomingInterviews().filter { $0.timeUntilStart() != nil }
                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("UPCOMING INTERVIEWS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange.opacity(0.8))
                            .tracking(1.5)

                        ForEach(upcoming.prefix(5)) { interview in
                            HStack(spacing: 6) {
                                Text("🎯")
                                    .font(.caption2)
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.orange.opacity(0.15), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 8)
                }
            }

            // Subject list
            VStack(spacing: 4) {
                ForEach(scheduleStore.todayBlocks()) { block in
                    blockRow(block)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 8)

            // Today's stats
            todayStats
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 8)

            // Actions
            VStack(spacing: 1) {
                menuButton(icon: "gearshape", label: "Settings...") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "schedule-editor")
                }

                Divider()
                    .padding(.horizontal, 8)

                menuButton(icon: "power", label: "Quit 0xFocus") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 310)
        .frame(maxHeight: 600)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
        )
    }

    // MARK: - Menu Button

    private func menuButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(label)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassButtonStyle())
    }

    // MARK: - State Header

    private var stateHeader: some View {
        Group {
            switch sessionManager.state {
            case .interview(let company):
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("🎯")
                        Text("Interview @ \(company)")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    Text(TimeFormatting.formatDuration(sessionManager.elapsedTime, showSeconds: sessionManager.showSeconds))
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.light)
                        .foregroundStyle(.orange)
                    Text("All schedules paused")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

            case .studying(let subjectName):
                let subject = Subject.from(rawValue: subjectName)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(subject.color)
                            .frame(width: 8, height: 8)
                            .shadow(color: subject.color.opacity(0.6), radius: 4)
                        Text(subject.displayName)
                            .font(.headline)
                        Spacer()
                        Button("Stop") { sessionManager.stopSession() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(subject.color)
                    }
                    Text(TimeFormatting.formatDuration(sessionManager.elapsedTime, showSeconds: sessionManager.showSeconds))
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.light)
                        .foregroundStyle(subject.color)
                }

            case .overtime(let subjectName):
                let subject = Subject.from(rawValue: subjectName)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.4), radius: 4)
                        Text("\(subject.displayName) — Overtime")
                            .font(.headline)
                        Spacer()
                        Button("Stop") { sessionManager.stopSession() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Text(TimeFormatting.formatDuration(sessionManager.elapsedTime, showSeconds: sessionManager.showSeconds))
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.light)
                        .foregroundStyle(.yellow)
                }

            case .onBreak(let nextSubject, _):
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("☕")
                        Text("On Break")
                            .font(.headline)
                        Spacer()
                    }
                    Text(TimeFormatting.formatDuration(max(0, sessionManager.breakTimeRemaining), showSeconds: sessionManager.showSeconds))
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.light)
                        .foregroundStyle(.secondary)
                    Text("until \(nextSubject)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

            case .pendingStart(let subjectName, _):
                let subject = Subject.from(rawValue: subjectName)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .shadow(color: .orange.opacity(0.4), radius: 4)
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
                    .tint(subject.color)
                }

            case .idle:
                HStack(spacing: 8) {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(.tertiary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No active session")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Click a subject to start")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Block Row

    private func blockRow(_ block: ScheduleBlock) -> some View {
        let subject = Subject(name: block.subject)
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
        let scheduledDuration = block.durationInterval

        let scheduleTimeStr: String = {
            let start = TimeFormatting.formatTime(hour: block.startHour, minute: block.startMinute)
            let end = TimeFormatting.formatTime(hour: block.endHour, minute: block.endMinute)
            return "\(start) – \(end)"
        }()

        return Button {
            sessionManager.toggleSession(subject: subject)
        } label: {
            HStack(spacing: 8) {
                Text(subject.emoji)
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 1) {
                    Text(subject.displayName)
                        .font(.subheadline)
                        .fontWeight(isActive ? .semibold : .regular)
                    Text(scheduleTimeStr)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    if isActive {
                        Text(TimeFormatting.formatDuration(sessionManager.elapsedTime, showSeconds: sessionManager.showSeconds))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(isOvertime ? .yellow : subject.color)
                            .shadow(color: (isOvertime ? Color.yellow : subject.color).opacity(0.3), radius: 3)
                    } else if todayDuration > 0 {
                        Text(TimeFormatting.formatDuration(todayDuration))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                    }

                    if scheduledDuration > 0 {
                        Text("/ \(TimeFormatting.formatDuration(scheduledDuration))")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill({
                        if isActive {
                            return isOvertime ? Color.yellow.opacity(0.15) : subject.color.opacity(0.15)
                        } else if sessionManager.coloredRows {
                            return subject.color.opacity(0.06)
                        } else {
                            return Color.clear
                        }
                    }())
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                {
                                    if isActive {
                                        return isOvertime ? Color.yellow.opacity(0.25) : subject.color.opacity(0.25)
                                    } else if sessionManager.coloredRows {
                                        return subject.color.opacity(0.1)
                                    } else {
                                        return Color.clear
                                    }
                                }(),
                                lineWidth: 0.5
                            )
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassButtonStyle())
        .disabled(isInterview)
        .opacity(isInterview ? 0.35 : 1)
    }

    // MARK: - Date/Time Helpers

    private func currentDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: Date())
    }

    private func currentTimeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }

    // MARK: - Today's Stats

    @State private var confirmingReset = false

    private var todayStats: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(1.5)
                Text("Total Study Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if sessionManager.todayTotalDuration() > 0 {
                if confirmingReset {
                    Button {
                        sessionManager.resetTodayData()
                        confirmingReset = false
                    } label: {
                        Text("Confirm")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    Button {
                        confirmingReset = false
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        confirmingReset = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reset today's study time")
                }
            }
            Text(TimeFormatting.formatDuration(sessionManager.todayTotalDuration()))
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear)
            )
    }
}

// MARK: - NSVisualEffectView Wrapper

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
