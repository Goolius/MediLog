import Foundation

/// Represents label information that can help the patient set up tracking.
///
/// This is not medical advice; it is used to prefill editable fields so the
/// patient can confirm their medication plan against their prescription.
struct MedicationLabelSummary: Equatable {
    var suggestedSideEffects: [String]
    var dosageInformation: String?

    static let empty = MedicationLabelSummary(
        suggestedSideEffects: [],
        dosageInformation: nil
    )
}
