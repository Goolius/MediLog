import Foundation

/// Represents a medication option returned from a public medication catalog.
///
/// The suggested dosage is informational only. The patient can edit it to match
/// their prescription label before the medication is added to their plan.
struct MedicationSearchResult: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let suggestedDosage: String
    let source: String

    init(id: String, name: String, suggestedDosage: String, source: String = "RxNorm") {
        self.id = id
        self.name = name
        self.suggestedDosage = suggestedDosage
        self.source = source
    }
}
