import Foundation

/// Records a patient side-effect check-in for a medication.
///
/// This use case protects clinical usefulness by requiring severity values only
/// when the patient experienced a tracked side effect.
struct RecordSideEffectCheckInUseCase {
    enum RecordSideEffectCheckInError: LocalizedError, Equatable {
        case medicationNotFound
        case noResponsesProvided
        case untrackedSideEffect
        case missingSeverity(sideEffectName: String)
        case invalidSeverity(sideEffectName: String)
        case severityProvidedWhenNotExperienced(sideEffectName: String)

        var errorDescription: String? {
            switch self {
            case .medicationNotFound:
                return "This medication is no longer in your medication list. Return to the check-in screen and choose a current medication."
            case .noResponsesProvided:
                return "Answer at least one side-effect question before saving your check-in."
            case .untrackedSideEffect:
                return "One of the responses does not match the side effects tracked for this medication. Start the check-in again from the medication list."
            case .missingSeverity(let name):
                return "You marked \(name) as experienced. Choose a severity from 1 to 5 so your history is useful later."
            case .invalidSeverity(let name):
                return "The severity for \(name) must be between 1 and 5. Adjust the rating before saving."
            case .severityProvidedWhenNotExperienced(let name):
                return "\(name) is marked as not experienced, so remove its severity rating before saving the check-in."
            }
        }
    }

    private let repository: MedicationRepository

    init(repository: MedicationRepository) {
        self.repository = repository
    }

    func execute(
        medicationID: UUID,
        responses: [SideEffectResponse],
        notes: String = "",
        recordedAt: Date = Date()
    ) throws -> SideEffectCheckIn {
        guard let medication = repository.medication(withID: medicationID) else {
            throw RecordSideEffectCheckInError.medicationNotFound
        }

        guard !responses.isEmpty else {
            throw RecordSideEffectCheckInError.noResponsesProvided
        }

        let trackedSideEffects = Dictionary(uniqueKeysWithValues: medication.trackedSideEffects.map { ($0.id, $0) })

        for response in responses {
            guard let sideEffect = trackedSideEffects[response.sideEffectID] else {
                throw RecordSideEffectCheckInError.untrackedSideEffect
            }

            if response.isExperienced {
                guard let severity = response.severity else {
                    throw RecordSideEffectCheckInError.missingSeverity(sideEffectName: sideEffect.name)
                }

                guard (1...5).contains(severity) else {
                    throw RecordSideEffectCheckInError.invalidSeverity(sideEffectName: sideEffect.name)
                }
            } else if response.severity != nil {
                throw RecordSideEffectCheckInError.severityProvidedWhenNotExperienced(sideEffectName: sideEffect.name)
            }
        }

        let checkIn = SideEffectCheckIn(
            medicationID: medicationID,
            recordedAt: recordedAt,
            responses: responses,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        repository.saveSideEffectCheckIn(checkIn)
        return checkIn
    }
}
