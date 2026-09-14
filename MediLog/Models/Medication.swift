import Foundation

/// Represents a medication the patient is currently tracking at home.
///
/// A medication owns its planned administration times and the side effects the
/// patient has been asked to monitor while taking it.
struct Medication: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var dosage: String
    var scheduledTimes: [MedicationSchedule]
    var trackedSideEffects: [SideEffect]

    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        scheduledTimes: [MedicationSchedule] = [],
        trackedSideEffects: [SideEffect] = []
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.scheduledTimes = scheduledTimes
        self.trackedSideEffects = trackedSideEffects
    }
}
