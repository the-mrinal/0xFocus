import SwiftUI
import SwiftData

struct WeeklySummaryView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var weekSessions: [StudySession] = []

    private var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? Date()
    }

    /// Unique subjects from this week's sessions, sorted by total duration descending
    private var weekSubjects: [Subject] {
        var durations: [String: TimeInterval] = [:]
        for session in weekSessions {
            durations[session.subject, default: 0] += session.duration
        }
        return durations
            .sorted { $0.value > $1.value }
            .map { Subject(name: $0.key) }
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            innerContent
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear { loadWeekSessions() }
    }

    private var innerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Summary")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .padding(.top)

            if weekSessions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No sessions logged this week yet.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                List {
                    ForEach(weekSubjects) { subject in
                        let duration = weekSessions
                            .filter { $0.subject == subject.rawValue }
                            .reduce(0) { $0 + $1.duration }

                        HStack {
                            Text(subject.emoji)
                            Text(subject.displayName)
                                .fontWeight(.medium)
                            Spacer()
                            Text(TimeFormatting.formatDuration(duration))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(subject.color)
                        }
                    }

                    Section("Total") {
                        HStack {
                            Text("All Subjects")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(TimeFormatting.formatDuration(
                                weekSessions.reduce(0) { $0 + $1.duration }
                            ))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func loadWeekSessions() {
        let start = startOfWeek
        let predicate = #Predicate<StudySession> { $0.startTime >= start }
        let descriptor = FetchDescriptor<StudySession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )
        weekSessions = (try? modelContext.fetch(descriptor)) ?? []
    }
}
