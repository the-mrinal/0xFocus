import Foundation
import SwiftData

@Model
final class StudySession {
    var id: UUID
    var subject: String
    var company: String?
    var startTime: Date
    var endTime: Date?

    var isActive: Bool {
        endTime == nil
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    init(subject: String, company: String? = nil) {
        self.id = UUID()
        self.subject = subject
        self.company = company
        self.startTime = Date()
        self.endTime = nil
    }
}
