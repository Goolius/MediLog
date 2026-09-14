import Foundation

/// Represents a side effect the patient should monitor while taking medication.
struct SideEffect: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String

    init(
        id: UUID = UUID(),
        name: String
    ) {
        self.id = id
        self.name = name
    }
}
