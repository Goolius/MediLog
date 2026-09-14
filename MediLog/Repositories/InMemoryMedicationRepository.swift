import Foundation

/// MVP repository that keeps patient medication data in memory while the app is
/// running. It is deliberately small so the assessment focus stays on business
/// rules and workflow.
final class InMemoryMedicationRepository: MedicationRepository {
    private(set) var medications: [Medication]
    private(set) var doseRecords: [MedicationDoseRecord]
    private(set) var sideEffectCheckIns: [SideEffectCheckIn]

    init(
        medications: [Medication] = InMemoryMedicationRepository.sampleMedications,
        doseRecords: [MedicationDoseRecord] = [],
        sideEffectCheckIns: [SideEffectCheckIn] = []
    ) {
        self.medications = medications
        self.doseRecords = doseRecords
        self.sideEffectCheckIns = sideEffectCheckIns
    }

    func medication(withID id: UUID) -> Medication? {
        medications.first { $0.id == id }
    }

    func saveMedication(_ medication: Medication) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            medications[index] = medication
        } else {
            medications.append(medication)
        }
    }

    func saveDoseRecord(_ record: MedicationDoseRecord) {
        doseRecords.append(record)
    }

    func saveSideEffectCheckIn(_ checkIn: SideEffectCheckIn) {
        sideEffectCheckIns.append(checkIn)
    }
}

extension InMemoryMedicationRepository {
    static let sampleMedications: [Medication] = {
        let nausea = SideEffect(name: "Nausea")
        let dizziness = SideEffect(name: "Dizziness")
        let headache = SideEffect(name: "Headache")
        let fatigue = SideEffect(name: "Fatigue")

        return [
            Medication(
                name: "Amoxicillin",
                dosage: "500 mg",
                scheduledTimes: [
                    MedicationSchedule(hour: 8, minute: 0),
                    MedicationSchedule(hour: 20, minute: 0)
                ],
                trackedSideEffects: [nausea, dizziness]
            ),
            Medication(
                name: "Metformin",
                dosage: "850 mg",
                scheduledTimes: [
                    MedicationSchedule(hour: 7, minute: 30),
                    MedicationSchedule(hour: 18, minute: 30)
                ],
                trackedSideEffects: [nausea, headache, fatigue]
            )
        ]
    }()
}
