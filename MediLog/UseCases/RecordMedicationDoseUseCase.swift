import Foundation

/// Records that a patient has taken a scheduled medication dose.
///
/// This use case protects the patient from accidentally recording the same
/// scheduled dose twice, which could make their medication history misleading.
struct RecordMedicationDoseUseCase {
    enum RecordMedicationDoseError: LocalizedError, Equatable {
        case medicationNotFound
        case duplicateDose

        var errorDescription: String? {
            switch self {
            case .medicationNotFound:
                return "This medication is no longer in your medication list. Return to today's schedule and try again."
            case .duplicateDose:
                return "A dose has already been recorded for this medication at this scheduled time. Check your medication history before adding another dose."
            }
        }
    }

    private let repository: MedicationRepository
    private let calendar: Calendar

    init(repository: MedicationRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
    }

    func execute(
        medicationID: UUID,
        scheduledTime: Date,
        takenAt: Date = Date()
    ) throws -> MedicationDoseRecord {
        guard repository.medication(withID: medicationID) != nil else {
            throw RecordMedicationDoseError.medicationNotFound
        }

        let alreadyRecorded = repository.doseRecords.contains { record in
            record.medicationID == medicationID
                && calendar.isDate(record.scheduledTime, equalTo: scheduledTime, toGranularity: .minute)
        }

        guard !alreadyRecorded else {
            throw RecordMedicationDoseError.duplicateDose
        }

        let record = MedicationDoseRecord(
            medicationID: medicationID,
            scheduledTime: scheduledTime,
            takenAt: takenAt
        )
        repository.saveDoseRecord(record)
        return record
    }
}
