import Foundation

enum TimeFormat {
    /// Countdown style: `12:34`, `1:02:03`. Remaining time rounds up so the display
    /// reaches `0:00` exactly when the interval hits zero. Negative intervals are
    /// shown as overtime with a leading `+`.
    static func clock(_ interval: TimeInterval) -> String {
        let overtime = interval < 0
        let magnitude = abs(interval)
        let total = Int(overtime ? magnitude.rounded(.down) : magnitude.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        let body = hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
        return overtime ? "+" + body : body
    }

    /// Compact duration for lists: `45 min`, `1 h 30 min`, `2 min 30 s`.
    static func compact(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) h") }
        if minutes > 0 { parts.append("\(minutes) min") }
        if seconds > 0 && hours == 0 { parts.append("\(seconds) s") }
        if parts.isEmpty { parts.append("0 min") }
        return parts.joined(separator: " ")
    }

}
