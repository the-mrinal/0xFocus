import SwiftUI

struct ScheduleEditorWindow: View {
    @Environment(ScheduleStore.self) private var scheduleStore
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var editingBlocks: [ScheduleBlock] = []
    @State private var editingInterviews: [InterviewBlock] = []
    @State private var showingAddSheet = false
    @State private var showingAddInterviewSheet = false
    @State private var showingImportSheet = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Schedule").tag(0)
                    Text("Interviews").tag(1)
                    Text("Import / Export").tag(2)
                    Text("Summary").tag(3)
                    Text("Settings").tag(4)
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case 0:
                    scheduleTab
                case 1:
                    interviewsTab
                case 2:
                    importExportTab
                case 3:
                    WeeklySummaryView()
                case 4:
                    settingsTab
                default:
                    EmptyView()
                }

                // Footer (only for schedule/interview tabs)
                if selectedTab <= 2 {
                    HStack {
                        if selectedTab == 0 {
                            Button("Reset to Default") {
                                editingBlocks = ScheduleBlock.defaultSchedule()
                                editingInterviews = []
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Cancel") {
                            dismiss()
                        }

                        Button("Save") {
                            scheduleStore.blocks = editingBlocks
                            scheduleStore.save()
                            scheduleStore.interviewBlocks = editingInterviews
                            scheduleStore.saveInterviews()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
        }
        .frame(minWidth: 580, minHeight: 500)
        .onAppear {
            editingBlocks = scheduleStore.blocks
            editingInterviews = scheduleStore.interviewBlocks
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Display section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DISPLAY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1.5)

                        Toggle("Show seconds in timer", isOn: Binding(
                            get: { sessionManager.showSeconds },
                            set: { _ in sessionManager.toggleShowSeconds() }
                        ))

                        Toggle("Colored subject rows", isOn: Binding(
                            get: { sessionManager.coloredRows },
                            set: { _ in sessionManager.toggleColoredRows() }
                        ))
                    }

                    Divider()

                    // Mobile notifications section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOBILE NOTIFICATIONS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1.5)

                        MobileSettingsInline()
                    }

                    Divider()

                    // Data section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DATA")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(1.5)

                        Button {
                            exportAndReset()
                        } label: {
                            Label("Export Data & Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)

                        Text("Exports all session history to CSV, then clears everything for a fresh start.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
            }
        }
    }

    private func exportAndReset() {
        let alert = NSAlert()
        alert.messageText = "Export & Reset All Data"
        alert.informativeText = "This will export all session history to a CSV file and then clear all data for a fresh start."
        alert.addButton(withTitle: "Export & Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let csv = sessionManager.exportToCSV()

        let savePanel = NSSavePanel()
        savePanel.title = "Export Session Data"
        savePanel.nameFieldStringValue = "0xFocus-sessions.csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }

        sessionManager.resetAllData()
    }

    // MARK: - Schedule Tab

    private var scheduleTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Daily Schedule")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if editingBlocks.isEmpty {
                Spacer()
                Text("No schedule blocks yet.\nClick + to add one.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(editingBlocks) { block in
                        ScheduleRowView(block: block) { updated in
                            if let index = editingBlocks.firstIndex(where: { $0.id == block.id }) {
                                editingBlocks[index] = updated
                            }
                        }
                    }
                    .onDelete { indexSet in
                        editingBlocks.remove(atOffsets: indexSet)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddBlockSheet { newBlock in
                editingBlocks.append(newBlock)
                editingBlocks.sort { ($0.startHour * 60 + $0.startMinute) < ($1.startHour * 60 + $1.startMinute) }
            }
        }
    }

    // MARK: - Interviews Tab

    private var interviewsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Interview Blocks")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("Interviews override all schedules")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button {
                    showingAddInterviewSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if editingInterviews.isEmpty {
                Spacer()
                Text("No interviews scheduled.\nClick + to add one.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(editingInterviews) { interview in
                        HStack(spacing: 12) {
                            Text("🎯")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(interview.company)
                                    .fontWeight(.medium)
                                Text(interview.displayDateString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 120, alignment: .leading)

                            Text(interview.startTimeString)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Image(systemName: "arrow.right")
                                .foregroundStyle(.quaternary)

                            Text(interview.endTimeString)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(TimeFormatting.formatDuration(TimeInterval(interview.durationMinutes * 60)))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        editingInterviews.remove(atOffsets: indexSet)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showingAddInterviewSheet) {
            AddInterviewSheet { newInterview in
                editingInterviews.append(newInterview)
                editingInterviews.sort { ($0.date, $0.startHour) < ($1.date, $1.startHour) }
            }
        }
    }

    // MARK: - Import/Export Tab

    private var importExportTab: some View {
        ImportExportView(
            scheduleStore: scheduleStore,
            editingBlocks: $editingBlocks,
            editingInterviews: $editingInterviews
        )
    }
}

// MARK: - Import/Export View

struct ImportExportView: View {
    let scheduleStore: ScheduleStore
    @Binding var editingBlocks: [ScheduleBlock]
    @Binding var editingInterviews: [InterviewBlock]

    @State private var textContent: String = ""
    @State private var parseErrors: [String] = []
    @State private var showSuccess = false
    @State private var copiedFormat = false

    private let formatHintText = """
// 0xFocus Schedule Format
// Lines starting with // are comments (ignored)
// Empty lines are ignored

# Daily Schedule
// Format: HH:MM-HH:MM SubjectName
// Optional: add "@ CompanyName" to tag a block for a specific company
// Gaps between blocks are treated as breaks automatically
// Subjects can be anything: DSA, LLD, HLD, Golang, System Design, etc.
06:00-08:00 DSA
08:30-10:00 LLD
10:30-12:30 HLD
14:00-16:00 Golang
16:30-18:00 Company Prep @ Google
19:00-20:00 System Design @ Uber

# Interview Blocks
// Format: YYYY-MM-DD HH:MM-HH:MM Interview @ CompanyName
// Interview blocks override ALL scheduled blocks and breaks
// No other session can run during an interview
// Multiple interviews can be scheduled on different dates
2026-03-20 14:00-15:00 Interview @ Google
2026-03-22 10:00-11:30 Interview @ Uber
2026-03-25 16:00-17:00 Interview @ Amazon
"""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Import / Export Schedule")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("Export Current") {
                    textContent = ScheduleParser.export(
                        scheduleBlocks: editingBlocks,
                        interviewBlocks: editingInterviews
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Text("Paste your schedule in the format below. Generate it with AI or write it by hand.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            // Format hint with copy button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Format:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatHintText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(formatHintText, forType: .string)
                    copiedFormat = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedFormat = false }
                } label: {
                    Label(copiedFormat ? "Copied!" : "Copy Format", systemImage: copiedFormat ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(6)
            .padding(.horizontal)

            // Text editor
            TextEditor(text: $textContent)
                .font(.system(.body, design: .monospaced))
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.15))
                )
                .padding(.horizontal)

            // Errors
            if !parseErrors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(parseErrors, id: \.self) { error in
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)
            }

            if showSuccess {
                Text("Schedule imported successfully!")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal)
            }

            // Import button
            HStack {
                Spacer()
                Button("Import") {
                    let result = ScheduleParser.parse(textContent)
                    parseErrors = result.errors

                    if !result.scheduleBlocks.isEmpty {
                        editingBlocks = result.scheduleBlocks
                    }
                    if !result.interviewBlocks.isEmpty {
                        // Replace interviews on import
                        editingInterviews = result.interviewBlocks
                        // Dedup by date+time slot
                        var seen = Set<String>()
                        editingInterviews = editingInterviews.filter { block in
                            let key = "\(block.dateString)-\(block.startHour):\(block.startMinute)-\(block.endHour):\(block.endMinute)"
                            return seen.insert(key).inserted
                        }
                        editingInterviews.sort { ($0.date, $0.startHour) < ($1.date, $1.startHour) }
                    }

                    if parseErrors.isEmpty && (!result.scheduleBlocks.isEmpty || !result.interviewBlocks.isEmpty) {
                        showSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showSuccess = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Supporting Views

struct ScheduleRowView: View {
    let block: ScheduleBlock
    let onUpdate: (ScheduleBlock) -> Void

    var body: some View {
        HStack(spacing: 12) {
            let subject = Subject.from(rawValue: block.subject)
            Text(subject.emoji)

            VStack(alignment: .leading) {
                Text(block.subject)
                    .fontWeight(.medium)
                if let company = block.company, !company.isEmpty {
                    Text("@ \(company)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, alignment: .leading)

            Text(TimeFormatting.formatTime(hour: block.startHour, minute: block.startMinute))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.right")
                .foregroundStyle(.quaternary)

            Text(TimeFormatting.formatTime(hour: block.endHour, minute: block.endMinute))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Text(TimeFormatting.formatDuration(block.durationInterval))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct AddBlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (ScheduleBlock) -> Void

    @State private var subjectName: String = ""
    @State private var startDate = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    @State private var endDate = Calendar.current.date(from: DateComponents(hour: 10, minute: 0))!

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Schedule Block")
                .font(.headline)

            TextField("Subject Name (e.g. DSA, LLD, Golang)", text: $subjectName)
                .textFieldStyle(.roundedBorder)

            DatePicker("Start Time", selection: $startDate, displayedComponents: .hourAndMinute)
            DatePicker("End Time", selection: $endDate, displayedComponents: .hourAndMinute)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let startComponents = Calendar.current.dateComponents([.hour, .minute], from: startDate)
                    let endComponents = Calendar.current.dateComponents([.hour, .minute], from: endDate)
                    let block = ScheduleBlock(
                        id: UUID(),
                        subject: subjectName.trimmingCharacters(in: .whitespaces),
                        startHour: startComponents.hour ?? 9,
                        startMinute: startComponents.minute ?? 0,
                        endHour: endComponents.hour ?? 10,
                        endMinute: endComponents.minute ?? 0
                    )
                    onAdd(block)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(subjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
    }
}

struct AddInterviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (InterviewBlock) -> Void

    @State private var company: String = ""
    @State private var date = Date()
    @State private var startDate = Calendar.current.date(from: DateComponents(hour: 14, minute: 0))!
    @State private var endDate = Calendar.current.date(from: DateComponents(hour: 15, minute: 0))!

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Interview Block")
                .font(.headline)

            TextField("Company Name", text: $company)
                .textFieldStyle(.roundedBorder)

            DatePicker("Date", selection: $date, displayedComponents: .date)
            DatePicker("Start Time", selection: $startDate, displayedComponents: .hourAndMinute)
            DatePicker("End Time", selection: $endDate, displayedComponents: .hourAndMinute)

            Text("Interviews override all scheduled blocks")
                .font(.caption)
                .foregroundStyle(.orange)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let startComponents = Calendar.current.dateComponents([.hour, .minute], from: startDate)
                    let endComponents = Calendar.current.dateComponents([.hour, .minute], from: endDate)
                    let interview = InterviewBlock(
                        id: UUID(),
                        company: company.isEmpty ? "Unknown" : company,
                        date: date,
                        startHour: startComponents.hour ?? 14,
                        startMinute: startComponents.minute ?? 0,
                        endHour: endComponents.hour ?? 15,
                        endMinute: endComponents.minute ?? 0
                    )
                    onAdd(interview)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(company.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
    }
}
