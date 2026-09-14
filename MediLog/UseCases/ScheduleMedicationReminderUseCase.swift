import Foundation

/// Adds a medication reminder time to the patient's medication plan.
///
/// This use case validates clock-time rules so the patient does not create an
/// impossible or duplicated medication reminder.
struct ScheduleMedicationReminderUseCase {
    enum ScheduleMedicationReminderError: LocalizedError, Equatable {
        case medicationNotFound
        case invalidTime
        case duplicateReminderTime

        var errorDescription: String? {
            switch self {
            case .medicationNotFound:
                return "This medication is no longer in your medication list. Return to today's schedule and try again."
            case .invalidTime:
                return "Choose a valid reminder time between 00:00 and 23:59."
            case .duplicateReminderTime:
                return "This medication already has a reminder at that time. Choose a different reminder time or keep the current schedule."
            }
        }
    }

    private let repository: MedicationRepository

    init(repository: MedicationRepository) {
        self.repository = repository
    }

    func execute(
        medicationID: UUID,
        hour: Int,
        minute: Int,
        recurrence: MedicationSchedule.Recurrence = .daily,
        startDate: Date = Date()
    ) throws -> Medication {
        guard var medication = repository.medication(withID: medicationID) else {
            throw ScheduleMedicationReminderError.medicationNotFound
        }

        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw ScheduleMedicationReminderError.invalidTime
        }

        guard recurrence.isValid else {
            throw ScheduleMedicationReminderError.invalidTime
        }

        let alreadyScheduled = medication.scheduledTimes.contains {
            $0.hour == hour && $0.minute == minute && $0.recurrence == recurrence
        }

        guard !alreadyScheduled else {
            throw ScheduleMedicationReminderError.duplicateReminderTime
        }

        medication.scheduledTimes.append(
            MedicationSchedule(
                hour: hour,
                minute: minute,
                recurrence: recurrence,
                startDate: startDate
            )
        )
        medication.scheduledTimes.sort {
            if $0.hour == $1.hour {
                return $0.minute < $1.minute
            }
            return $0.hour < $1.hour
        }
        repository.saveMedication(medication)
        return medication
    }
}

private extension MedicationSchedule.Recurrence {
    var isValid: Bool {
        switch self {
        case .hourly(let interval):
            return (1...24).contains(interval)
        case .daily:
            return true
        case .everyDays(let interval):
            return interval > 0
        case .weekly(let weekday):
            return (1...7).contains(weekday)
        }
    }
}
