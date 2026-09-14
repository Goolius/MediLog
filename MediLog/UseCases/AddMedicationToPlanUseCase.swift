import Foundation

/// Adds a confirmed medication to the patient's home medication plan.
///
/// The patient can accept the suggested dosage or replace it with the dosage
/// from their prescription label. Side effects are also editable before saving.
struct AddMedicationToPlanUseCase {
    enum AddMedicationToPlanError: LocalizedError, Equatable {
        case missingMedicationName
        case missingDosage
        case missingSchedule
        case invalidSchedule
        case duplicateMedication

        var errorDescription: String? {
            switch self {
            case .missingMedicationName:
                return "Enter the medication name before adding it to your plan."
            case .missingDosage:
                return "Confirm the dosage from your prescription label before adding this medication."
            case .missingSchedule:
                return "Add at least one reminder schedule before saving this medication."
            case .invalidSchedule:
                return "Use a valid reminder time and frequency before saving this medication."
            case .duplicateMedication:
                return "This medication is already in your medication plan. Open its details if you need to change reminders or tracked side effects."
            }
        }
    }

    private let repository: MedicationRepository

    init(repository: MedicationRepository) {
        self.repository = repository
    }

    func execute(
        name: String,
        dosage: String,
        schedules: [MedicationSchedule],
        trackedSideEffectNames: [String]
    ) throws -> Medication {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw AddMedicationToPlanError.missingMedicationName
        }

        guard !trimmedDosage.isEmpty else {
            throw AddMedicationToPlanError.missingDosage
        }

        guard !schedules.isEmpty else {
            throw AddMedicationToPlanError.missingSchedule
        }

        guard schedules.allSatisfy(\.isValid) else {
            throw AddMedicationToPlanError.invalidSchedule
        }

        let alreadyExists = repository.medications.contains {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }

        guard !alreadyExists else {
            throw AddMedicationToPlanError.duplicateMedication
        }

        let sideEffects = trackedSideEffectNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .removingDuplicates()
            .map { SideEffect(name: $0) }

        let medication = Medication(
            name: trimmedName,
            dosage: trimmedDosage,
            scheduledTimes: schedules,
            trackedSideEffects: sideEffects
        )
        repository.saveMedication(medication)
        return medication
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension MedicationSchedule {
    var isValid: Bool {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return false
        }

        switch recurrence {
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
