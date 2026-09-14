import Foundation

enum ReminderFrequencyOption: String, CaseIterable, Identifiable {
    case daily
    case everyTwoDays
    case weekly

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .daily:
            return "Daily"
        case .everyTwoDays:
            return "Every 2 days"
        case .weekly:
            return "Once a week"
        }
    }

    func recurrence(startDate: Date, calendar: Calendar = .current) -> MedicationSchedule.Recurrence {
        switch self {
        case .daily:
            return .daily
        case .everyTwoDays:
            return .everyDays(2)
        case .weekly:
            return .weekly(calendar.component(.weekday, from: startDate))
        }
    }
}
