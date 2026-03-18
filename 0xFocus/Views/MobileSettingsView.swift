import SwiftUI

struct MobileSettingsView: View {
    @State private var enabled: Bool = NotificationService.shared.mobileNotificationsEnabled
    @State private var topic: String = NotificationService.shared.ntfyTopic
    @State private var testSent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Mobile Notifications")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Get 0xFocus notifications on your iPhone via ntfy.sh — free, no account needed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            // Setup steps
            VStack(alignment: .leading, spacing: 8) {
                Text("Setup (one time)")
                    .font(.headline)

                Label("Install the **ntfy** app on your iPhone from the App Store", systemImage: "1.circle.fill")
                    .font(.subheadline)

                Label("Open ntfy → tap **+** → Subscribe to a topic", systemImage: "2.circle.fill")
                    .font(.subheadline)

                Label("Enter the same topic name below", systemImage: "3.circle.fill")
                    .font(.subheadline)

                Label("Tap **Send Test** to verify it works", systemImage: "4.circle.fill")
                    .font(.subheadline)
            }

            Divider()

            // Toggle
            Toggle("Enable mobile notifications", isOn: $enabled)
                .onChange(of: enabled) { _, newValue in
                    NotificationService.shared.mobileNotificationsEnabled = newValue
                }

            // Topic field
            VStack(alignment: .leading, spacing: 4) {
                Text("ntfy Topic")
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack {
                    Text("ntfy.sh/")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("your-secret-topic", text: $topic)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: topic) { _, newValue in
                            NotificationService.shared.ntfyTopic = newValue
                        }
                }
                Text("Use something unique and hard to guess — this is your \"password\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Test button
            HStack {
                Button("Send Test Notification") {
                    NotificationService.shared.sendTestMobileNotification()
                    testSent = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        testSent = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if testSent {
                    Text("Sent! Check your phone.")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 450, minHeight: 380)
    }
}
