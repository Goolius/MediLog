import Foundation

/// Describes storage operations for medication schedules, dose records, and
/// side-effect check-ins.
protocol MedicationRepository: AnyObject {
    var medications: [Medication] { get }
    var doseRecords: [MedicationDoseRecord] { get }
    var sideEffectCheckIns: [SideEffectCheckIn] { get }

    func medication(withID id: UUID) -> Medication?
    func saveMedication(_ medication: Medication)
    func saveDoseRecord(_ record: MedicationDoseRecord)
    func saveSideEffectCheckIn(_ checkIn: SideEffectCheckIn)
}
