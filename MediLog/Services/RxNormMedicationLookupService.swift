import Foundation

/// Looks up medications using RxNorm/RxNav and optional public FDA labeling.
///
/// RxNorm is used for medication search. openFDA is used best-effort for label
/// text that may suggest common adverse reactions.
struct RxNormMedicationLookupService: MedicationLookupService {
    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func searchMedications(matching query: String) async throws -> [MedicationSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            return []
        }

        var components = URLComponents(string: "https://rxnav.nlm.nih.gov/REST/drugs.json")
        components?.queryItems = [
            URLQueryItem(name: "name", value: trimmedQuery)
        ]

        guard let url = components?.url else {
            return []
        }

        let (data, _) = try await urlSession.data(from: url)
        let response = try decoder.decode(RxNavDrugResponse.self, from: data)
        let concepts = response.drugGroup.conceptGroup?
            .flatMap { $0.conceptProperties ?? [] } ?? []

        var seenIDs = Set<String>()
        return concepts
            .filter { concept in
                guard !seenIDs.contains(concept.rxcui) else {
                    return false
                }
                seenIDs.insert(concept.rxcui)
                return true
            }
            .prefix(12)
            .map { concept in
                MedicationSearchResult(
                    id: concept.rxcui,
                    name: concept.name,
                    suggestedDosage: Self.suggestedDosage(from: concept.name)
                )
            }
    }

    func labelSummary(for result: MedicationSearchResult) async throws -> MedicationLabelSummary {
        var components = URLComponents(string: "https://api.fda.gov/drug/label.json")
        components?.queryItems = [
            URLQueryItem(name: "search", value: "openfda.rxcui:\"\(result.id)\""),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components?.url else {
            return .empty
        }

        do {
            let (data, _) = try await urlSession.data(from: url)
            let response = try decoder.decode(OpenFDALabelResponse.self, from: data)
            guard let label = response.results.first else {
                return .empty
            }

            return MedicationLabelSummary(
                suggestedSideEffects: Self.sideEffectNames(from: label.adverseReactions?.joined(separator: "\n") ?? ""),
                dosageInformation: label.dosageAndAdministration?.first
            )
        } catch {
            return .empty
        }
    }

    private static func suggestedDosage(from name: String) -> String {
        let pattern = #"\b\d+(\.\d+)?\s?(MG|MCG|G|ML|UNT|MEQ)\b"#
        guard let range = name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return "Confirm from prescription label"
        }
        return String(name[range]).uppercased()
    }

    private static func sideEffectNames(from text: String) -> [String] {
        let commonEffects = [
            "Nausea",
            "Vomiting",
            "Diarrhea",
            "Headache",
            "Dizziness",
            "Fatigue",
            "Rash",
            "Insomnia",
            "Drowsiness",
            "Constipation",
            "Abdominal pain",
            "Dry mouth"
        ]

        let lowercasedText = text.lowercased()
        return commonEffects.filter { lowercasedText.contains($0.lowercased()) }
    }
}

private struct RxNavDrugResponse: Decodable {
    let drugGroup: RxNavDrugGroup
}

private struct RxNavDrugGroup: Decodable {
    let conceptGroup: [RxNavConceptGroup]?
}

private struct RxNavConceptGroup: Decodable {
    let conceptProperties: [RxNavConcept]?
}

private struct RxNavConcept: Decodable {
    let rxcui: String
    let name: String
}

private struct OpenFDALabelResponse: Decodable {
    let results: [OpenFDALabel]
}

private struct OpenFDALabel: Decodable {
    let adverseReactions: [String]?
    let dosageAndAdministration: [String]?

    enum CodingKeys: String, CodingKey {
        case adverseReactions = "adverse_reactions"
        case dosageAndAdministration = "dosage_and_administration"
    }
}
