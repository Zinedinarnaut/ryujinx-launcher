import Foundation

struct Game: Identifiable, Hashable {
    let id: String
    let title: String
    let titleId: String?
    let fileURL: URL
    let hoursPlayed: Double
    let lastPlayed: Date?

    var formattedHoursPlayed: String {
        if hoursPlayed <= 0.01 {
            return "0.0 hrs"
        }
        return String(format: "%.1f hrs", hoursPlayed)
    }

    var formattedLastPlayed: String? {
        guard let lastPlayed else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastPlayed, relativeTo: Date())
    }
}
