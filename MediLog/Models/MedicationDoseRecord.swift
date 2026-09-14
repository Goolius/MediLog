import Foundation

/// Represents one confirmed medication dose taken by the patient.
///
/// Business rule: a patient should not record more than one dose for the same
/// medication and scheduled time.
struct MedicationDoseRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let medicationID: UUID
    let scheduledTime: Date
    let takenAt: Date

    init(
        id: UUID = UUID(),
        medicationID: UUID,
        scheduledTime: Date,
        takenAt: Date
    ) {
        self.id = id
        self.medicationID = medicationID
        self.scheduledTime = scheduledTime
        self.takenAt = takenAt
    }
}
