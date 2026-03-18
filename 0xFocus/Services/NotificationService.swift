import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    // Callback when user taps "Start" on a notification
    var onStartSubject: ((String) -> Void)?

    // ntfy.sh topic for mobile notifications
    var ntfyTopic: String {
        get { UserDefaults.standard.string(forKey: "ntfyTopic") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "ntfyTopic") }
    }

    var mobileNotificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "mobileNotifications") }
        set { UserDefaults.standard.set(newValue, forKey: "mobileNotifications") }
    }

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Block End Notifications

    func sendBlockEndNotification(completedSubject: String, nextBlock: ScheduleBlock?, breakMinutes: Int) {
        let title = "\(completedSubject) Complete!"
        var body: String

        if breakMinutes > 0, let next = nextBlock {
            let time = TimeFormatting.formatTime(hour: next.startHour, minute: next.startMinute)
            body = "Great work! Break until \(time), then \(next.subject)."
        } else if let next = nextBlock {
            let time = TimeFormatting.formatTime(hour: next.startHour, minute: next.startMinute)
            body = "Great work! \(next.subject) starts at \(time)."
        } else {
            body = "Great work! No more blocks scheduled today."
        }

        // Local notification
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let next = nextBlock, breakMinutes <= 0 {
            content.categoryIdentifier = "BLOCK_END_NEXT_READY"
            content.userInfo = ["nextSubject": next.subject]
        } else if breakMinutes > 0 {
            content.categoryIdentifier = "BLOCK_END_WITH_BREAK"
        } else {
            content.categoryIdentifier = "BLOCK_END_DONE"
        }
        scheduleLocal(content: content, id: "block-end")

        // Mobile
        sendMobile(title: title, body: body, priority: 3)
    }

    func sendBreakEndNotification(nextBlock: ScheduleBlock) {
        let title = "Break Over!"
        let body = "Time to start \(nextBlock.subject). Ready?"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "BREAK_END"
        content.userInfo = ["nextSubject": nextBlock.subject]
        scheduleLocal(content: content, id: "break-end")

        sendMobile(title: title, body: body, priority: 4)
    }

    func sendReminderNotification(subject: String) {
        let title = "Reminder"
        let body = "\(subject) was scheduled 5 min ago. Tap to start."

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "REMINDER"
        content.userInfo = ["nextSubject": subject]
        scheduleLocal(content: content, id: "reminder")

        sendMobile(title: title, body: body, priority: 4)
    }

    func sendInterviewReminder(company: String, countdown: String, threshold: String, priority: Int) {
        let title: String
        let body: String

        switch threshold {
        case "24h":
            title = "🎯 Interview Tomorrow"
            body = "Interview with \(company) \(countdown). Prepare well!"
        case "2h":
            title = "🎯 Interview in 2 Hours"
            body = "Interview with \(company) \(countdown). Wrap up and get ready!"
        case "30min":
            title = "🎯 Interview in 30 Minutes!"
            body = "Interview with \(company) starting soon. Get ready!"
        default:
            title = "🎯 Interview Reminder"
            body = "Interview with \(company) \(countdown)."
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "INTERVIEW_REMINDER"
        scheduleLocal(content: content, id: "interview-reminder")

        sendMobile(title: title, body: body, priority: priority)
    }

    func sendInterviewNotification(company: String) {
        let title = "🎯 Interview Time!"
        let body = "Your interview with \(company) is starting now. Good luck!"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "INTERVIEW"
        scheduleLocal(content: content, id: "interview")

        // Interviews get max priority on mobile
        sendMobile(title: title, body: body, priority: 5)
    }

    // MARK: - Local Notification Helper

    private func scheduleLocal(content: UNMutableNotificationContent, id: String) {
        let request = UNNotificationRequest(
            identifier: "\(id)-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Mobile (ntfy.sh)

    private func sendMobile(title: String, body: String, priority: Int) {
        guard mobileNotificationsEnabled else { return }
        let topic = ntfyTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty else { return }

        guard let url = URL(string: "https://ntfy.sh/\(topic)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue(String(priority), forHTTPHeaderField: "Priority")
        request.setValue("0xFocus", forHTTPHeaderField: "Tags")
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("ntfy error: \(error.localizedDescription)")
            }
        }.resume()
    }

    /// Send a test notification to verify ntfy setup
    func sendTestMobileNotification() {
        let topic = ntfyTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty, let url = URL(string: "https://ntfy.sh/\(topic)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("0xFocus Test", forHTTPHeaderField: "Title")
        request.setValue("3", forHTTPHeaderField: "Priority")
        request.httpBody = "Mobile notifications are working! 🎯".data(using: .utf8)

        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: - Notification Categories (action buttons)

    func registerCategories() {
        let startAction = UNNotificationAction(
            identifier: "START_ACTION",
            title: "Start",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Skip",
            options: []
        )

        let breakEndCategory = UNNotificationCategory(
            identifier: "BREAK_END",
            actions: [startAction, dismissAction],
            intentIdentifiers: []
        )
        let blockEndNextCategory = UNNotificationCategory(
            identifier: "BLOCK_END_NEXT_READY",
            actions: [startAction, dismissAction],
            intentIdentifiers: []
        )
        let reminderCategory = UNNotificationCategory(
            identifier: "REMINDER",
            actions: [startAction, dismissAction],
            intentIdentifiers: []
        )
        let blockEndBreakCategory = UNNotificationCategory(
            identifier: "BLOCK_END_WITH_BREAK",
            actions: [],
            intentIdentifiers: []
        )
        let blockEndDoneCategory = UNNotificationCategory(
            identifier: "BLOCK_END_DONE",
            actions: [],
            intentIdentifiers: []
        )
        let interviewCategory = UNNotificationCategory(
            identifier: "INTERVIEW",
            actions: [],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            breakEndCategory,
            blockEndNextCategory,
            reminderCategory,
            blockEndBreakCategory,
            blockEndDoneCategory,
            interviewCategory,
        ])
    }

    func cancelAllScheduled() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func rescheduleAll(blocks: [ScheduleBlock]) {
        cancelAllScheduled()
    }

    // MARK: - Delegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "START_ACTION" {
            if let subject = response.notification.request.content.userInfo["nextSubject"] as? String {
                DispatchQueue.main.async {
                    self.onStartSubject?(subject)
                }
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}
