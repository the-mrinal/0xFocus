import SwiftUI
import SwiftData

@main
struct _0xFocusApp: App {
    @State private var sessionManager = SessionManager()
    @State private var scheduleStore = ScheduleStore()

    let container: ModelContainer

    init() {
        let container = try! ModelContainer(for: StudySession.self)
        self.container = container

        if !UserDefaults.standard.bool(forKey: "showSecondsSet") {
            UserDefaults.standard.set(true, forKey: "showSeconds")
            UserDefaults.standard.set(true, forKey: "showSecondsSet")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(sessionManager)
                .environment(scheduleStore)
                .modelContainer(container)
                .task {
                    let context = ModelContext(container)
                    sessionManager.setModelContext(context)
                    sessionManager.scheduleStore = scheduleStore
                    sessionManager.showSeconds = UserDefaults.standard.bool(forKey: "showSeconds")

                    // Setup notifications
                    NotificationService.shared.requestPermission()
                    NotificationService.shared.registerCategories()

                    // Wire up notification "Start" action → start session
                    NotificationService.shared.onStartSubject = { subjectName in
                        sessionManager.startFromNotification(subjectName: subjectName)
                    }
                }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: sessionManager.menuBarIcon)
                    .font(.system(size: 10))
                Text(sessionManager.menuBarText)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)

        Window("0xFocus Settings", id: "schedule-editor") {
            ScheduleEditorWindow()
                .environment(scheduleStore)
                .environment(sessionManager)
                .modelContainer(container)
                .onAppear { NSApp.setActivationPolicy(.regular) }
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if NSApp.windows.filter({ $0.isVisible && $0.title != "" }).isEmpty {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
        }
        .defaultSize(width: 580, height: 500)

        Window("Weekly Summary", id: "weekly-summary") {
            WeeklySummaryView()
                .modelContainer(container)
                .onAppear { NSApp.setActivationPolicy(.regular) }
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if NSApp.windows.filter({ $0.isVisible && $0.title != "" }).isEmpty {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
        }
        .defaultSize(width: 420, height: 350)

        Window("Mobile Notifications", id: "mobile-settings") {
            MobileSettingsView()
                .onAppear { NSApp.setActivationPolicy(.regular) }
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if NSApp.windows.filter({ $0.isVisible && $0.title != "" }).isEmpty {
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }
        }
        .defaultSize(width: 480, height: 420)
    }
}
