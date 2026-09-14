import Foundation

/// Stores medication data on the device so the patient's plan and history
/// survive app restarts.
final class LocalMedicationRepository: MedicationRepository {
    private struct Store: Codable {
        var medications: [Medication] = []
        var doseRecords: [MedicationDoseRecord] = []
        var sideEffectCheckIns: [SideEffectCheckIn] = []
    }

    private let fileURL: URL
    private var store: Store

    var medications: [Medication] {
        store.medications
    }

    var doseRecords: [MedicationDoseRecord] {
        store.doseRecords
    }

    var sideEffectCheckIns: [SideEffectCheckIn] {
        store.sideEffectCheckIns
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.store = Self.loadStore(from: self.fileURL)
    }

    func medication(withID id: UUID) -> Medication? {
        store.medications.first { $0.id == id }
    }

    func saveMedication(_ medication: Medication) {
        if let index = store.medications.firstIndex(where: { $0.id == medication.id }) {
            store.medications[index] = medication
        } else {
            store.medications.append(medication)
        }
        save()
    }

    func saveDoseRecord(_ record: MedicationDoseRecord) {
        store.doseRecords.append(record)
        save()
    }

    func saveSideEffectCheckIn(_ checkIn: SideEffectCheckIn) {
        store.sideEffectCheckIns.append(checkIn)
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder.medilog.encode(store)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save medication store: \(error)")
        }
    }

    private static func loadStore(from fileURL: URL) -> Store {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder.medilog.decode(Store.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return Store()
        } catch {
            assertionFailure("Failed to load medication store: \(error)")
            return Store()
        }
    }

    private static var defaultFileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("medilog-store.json")
    }
}

private extension JSONEncoder {
    static var medilog: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var medilog: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
