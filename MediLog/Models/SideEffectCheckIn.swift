import Foundation

/// Represents one patient check-in for medication side effects.
///
/// Each check-in records whether the patient experienced the side effects being
/// tracked for a medication, optional severity ratings, and any patient notes.
struct SideEffectCheckIn: Identifiable, Codable, Equatable {
    let id: UUID
    let medicationID: UUID
    let recordedAt: Date
    var responses: [SideEffectResponse]
    var notes: String

    init(
        id: UUID = UUID(),
        medicationID: UUID,
        recordedAt: Date = Date(),
        responses: [SideEffectResponse],
        notes: String = ""
    ) {
        self.id = id
        self.medicationID = medicationID
        self.recordedAt = recordedAt
        self.responses = responses
        self.notes = notes
    }
}

/// Represents the patient's answer for a single monitored side effect.
///
/// Business rule: severity should only be provided when the patient experienced
/// the side effect, and valid severity values should be defined by the use case.
struct SideEffectResponse: Identifiable, Codable, Equatable {
    let id: UUID
    let sideEffectID: UUID
    var isExperienced: Bool
    var severity: Int?

    init(
        id: UUID = UUID(),
        sideEffectID: UUID,
        isExperienced: Bool,
        severity: Int? = nil
    ) {
        self.id = id
        self.sideEffectID = sideEffectID
        self.isExperienced = isExperienced
        self.severity = severity
    }
}
