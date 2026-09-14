import Foundation

protocol MedicationLookupService {
    func searchMedications(matching query: String) async throws -> [MedicationSearchResult]
    func labelSummary(for result: MedicationSearchResult) async throws -> MedicationLabelSummary
}
