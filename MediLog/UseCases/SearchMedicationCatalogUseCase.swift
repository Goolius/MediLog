import Foundation

/// Searches a public medication catalog for possible matches while the patient
/// adds a medication to their plan.
struct SearchMedicationCatalogUseCase {
    enum SearchMedicationCatalogError: LocalizedError, Equatable {
        case searchTermTooShort
        case lookupUnavailable

        var errorDescription: String? {
            switch self {
            case .searchTermTooShort:
                return "Enter at least two letters of the medication name before searching."
            case .lookupUnavailable:
                return "Medication search is currently unavailable. You can try again later or enter the medication details manually."
            }
        }
    }

    private let lookupService: MedicationLookupService

    init(lookupService: MedicationLookupService) {
        self.lookupService = lookupService
    }

    func execute(query: String) async throws -> [MedicationSearchResult] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            throw SearchMedicationCatalogError.searchTermTooShort
        }

        do {
            return try await lookupService.searchMedications(matching: query)
        } catch {
            throw SearchMedicationCatalogError.lookupUnavailable
        }
    }
}
