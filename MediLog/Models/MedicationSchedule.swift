import Foundation

/// Represents a planned time of day when the patient should take a medication.
///
/// Business rule: `hour` should use 24-hour time from 0 to 23, and `minute`
/// should be from 0 to 59. Use cases are responsible for validating those
/// values before schedules are saved.
struct MedicationSchedule: Identifiable, Codable, Equatable {
    enum Recurrence: Codable, Equatable, Hashable {
        case hourly(Int)
        case daily
        case everyDays(Int)
        case weekly(Int)
    }

    let id: UUID
    var hour: Int
    var minute: Int
    var recurrence: Recurrence
    var startDate: Date

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        recurrence: Recurrence = .daily,
        startDate: Date = Date()
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.recurrence = recurrence
        self.startDate = startDate
    }
}
