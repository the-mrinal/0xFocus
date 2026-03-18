import SwiftUI

struct Subject: Identifiable, Hashable {
    let name: String

    var id: String { name }
    var displayName: String { name }

    var emoji: String {
        let lower = name.lowercased()
        if lower.contains("dsa") { return "📗" }
        if lower.contains("lld") || lower.contains("low level") || lower.contains("machine coding") { return "📘" }
        if lower.contains("hld") || lower.contains("high level") || lower.contains("system design") { return "📙" }
        if lower.contains("golang") || lower.contains("go ") { return "🐹" }
        if lower.contains("interview") { return "🎯" }
        if lower.contains("revision") || lower.contains("revise") { return "🔄" }
        return "🏢"
    }

    var color: Color {
        let lower = name.lowercased()
        if lower.contains("dsa") { return .green }
        if lower.contains("lld") || lower.contains("low level") || lower.contains("machine coding") { return .blue }
        if lower.contains("hld") || lower.contains("high level") || lower.contains("system design") { return .orange }
        if lower.contains("golang") || lower.contains("go ") { return .cyan }
        if lower.contains("revision") || lower.contains("revise") { return .mint }
        return .purple
    }

    var rawValue: String { name }

    static func from(rawValue: String) -> Subject {
        Subject(name: rawValue)
    }
}
