import Foundation
import Combine

struct PatientMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ScheduledDose: Identifiable {
    let id: String
    let medication: Medication
    let schedule: MedicationSchedule
    let scheduledTime: Date
    let doseRecord: MedicationDoseRecord?

    var isRecorded: Bool {
        doseRecord != nil
    }

    var isTakenEarly: Bool {
        guard let doseRecord else {
            return false
        }

        return doseRecord.takenAt < scheduledTime
    }

    var isTakenLate: Bool {
        guard let doseRecord else {
            return false
        }

        return doseRecord.takenAt > scheduledTime
    }
}

struct ScheduledDoseSection: Identifiable {
    let id: Date
    let date: Date
    let doses: [ScheduledDose]
}

struct ExperiencedSideEffectEvent: Identifiable {
    let id: String
    let medicationName: String
    let sideEffectName: String
    let recordedAt: Date
    let severity: Int
    let notes: String
    let totalOccurrences: Int
    let averageSeverity: Double
}

@MainActor
final class MediLogViewModel: ObservableObject {
    @Published private(set) var medications: [Medication] = []
    @Published private(set) var doseRecords: [MedicationDoseRecord] = []
    @Published private(set) var sideEffectCheckIns: [SideEffectCheckIn] = []
    @Published private(set) var medicationSearchResults: [MedicationSearchResult] = []
    @Published private(set) var selectedMedicationLabelSummary: MedicationLabelSummary = .empty
    @Published private(set) var isSearchingMedications = false
    @Published private(set) var isLoadingMedicationLabel = false
    @Published var patientMessage: PatientMessage?

    private let repository: MedicationRepository
    private let lookupService: MedicationLookupService
    private let calendar: Calendar

    convenience init(calendar: Calendar = .current) {
        self.init(
            repository: LocalMedicationRepository(),
            lookupService: RxNormMedicationLookupService(),
            calendar: calendar
        )
    }

    init(
        repository: MedicationRepository,
        lookupService: MedicationLookupService = RxNormMedicationLookupService(),
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.lookupService = lookupService
        self.calendar = calendar
        refresh()
    }

    var todayScheduledDoses: [ScheduledDose] {
        scheduledDoses(on: Date())
    }

    func scheduledDoses(on date: Date) -> [ScheduledDose] {
        return medications
            .flatMap { medication in
                medication.scheduledTimes
                    .flatMap { schedule in
                        schedule.scheduledDates(on: date, calendar: calendar).map { scheduledTime in
                            ScheduledDose(
                                id: "\(medication.id.uuidString)-\(schedule.id.uuidString)-\(scheduledTime.timeIntervalSince1970)",
                                medication: medication,
                                schedule: schedule,
                                scheduledTime: scheduledTime,
                                doseRecord: doseRecord(medicationID: medication.id, scheduledTime: scheduledTime)
                            )
                        }
                    }
            }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    func scheduledDoseSections(starting startDate: Date = Date(), daysToShow: Int) -> [ScheduledDoseSection] {
        let startOfToday = calendar.startOfDay(for: startDate)

        return (0..<daysToShow).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                return nil
            }

            let doses = scheduledDoses(on: date).filter { !$0.isRecorded }
            guard !doses.isEmpty else {
                return nil
            }

            return ScheduledDoseSection(id: date, date: date, doses: doses)
        }
    }

    func medication(withID id: UUID) -> Medication? {
        medications.first { $0.id == id }
    }

    func medicationName(for id: UUID) -> String {
        medication(withID: id)?.name ?? "Unknown medication"
    }

    func sideEffectName(for id: UUID, medicationID: UUID) -> String {
        medication(withID: medicationID)?
            .trackedSideEffects
            .first { $0.id == id }?
            .name ?? "Side effect"
    }

    func addTrackedSideEffect(to medicationID: UUID, name: String) -> SideEffect? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }

        guard var medication = medication(withID: medicationID) else {
            show(RecordSideEffectCheckInUseCase.RecordSideEffectCheckInError.medicationNotFound)
            return nil
        }

        if let existingSideEffect = medication.trackedSideEffects.first(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            return existingSideEffect
        }

        let sideEffect = SideEffect(name: trimmedName)
        medication.trackedSideEffects.append(sideEffect)
        repository.saveMedication(medication)
        refresh()
        return sideEffect
    }

    var experiencedSideEffectEvents: [ExperiencedSideEffectEvent] {
        let experiencedResponses = sideEffectCheckIns.flatMap { checkIn in
            checkIn.responses
                .filter(\.isExperienced)
                .compactMap { response -> ExperiencedSideEffectEventSeed? in
                    guard let severity = response.severity else {
                        return nil
                    }

                    return ExperiencedSideEffectEventSeed(
                        id: "\(checkIn.id.uuidString)-\(response.id.uuidString)",
                        medicationID: checkIn.medicationID,
                        medicationName: medicationName(for: checkIn.medicationID),
                        sideEffectID: response.sideEffectID,
                        sideEffectName: sideEffectName(for: response.sideEffectID, medicationID: checkIn.medicationID),
                        recordedAt: checkIn.recordedAt,
                        severity: severity,
                        notes: checkIn.notes
                    )
                }
        }

        return experiencedResponses
            .map { seed in
                let matchingResponses = experiencedResponses.filter {
                    $0.medicationID == seed.medicationID && $0.sideEffectID == seed.sideEffectID
                }
                let averageSeverity = Double(matchingResponses.map(\.severity).reduce(0, +)) / Double(matchingResponses.count)

                return ExperiencedSideEffectEvent(
                    id: seed.id,
                    medicationName: seed.medicationName,
                    sideEffectName: seed.sideEffectName,
                    recordedAt: seed.recordedAt,
                    severity: seed.severity,
                    notes: seed.notes,
                    totalOccurrences: matchingResponses.count,
                    averageSeverity: averageSeverity
                )
            }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func recordDose(for scheduledDose: ScheduledDose) {
        do {
            _ = try RecordMedicationDoseUseCase(repository: repository, calendar: calendar).execute(
                medicationID: scheduledDose.medication.id,
                scheduledTime: scheduledDose.scheduledTime
            )
            refresh()
            patientMessage = PatientMessage(
                title: "Medication Recorded",
                message: "\(scheduledDose.medication.name) \(scheduledDose.medication.dosage) has been added to your medication history."
            )
        } catch {
            show(error)
        }
    }

    func confirmDose(
        for scheduledDose: ScheduledDose,
        experiencedSideEffectIDs: Set<UUID>,
        severityBySideEffectID: [UUID: Int],
        notes: String
    ) -> Bool {
        do {
            let medication = medication(withID: scheduledDose.medication.id) ?? scheduledDose.medication

            _ = try RecordMedicationDoseUseCase(repository: repository, calendar: calendar).execute(
                medicationID: medication.id,
                scheduledTime: scheduledDose.scheduledTime
            )

            if !medication.trackedSideEffects.isEmpty {
                let responses = medication.trackedSideEffects.map { sideEffect in
                    SideEffectResponse(
                        sideEffectID: sideEffect.id,
                        isExperienced: experiencedSideEffectIDs.contains(sideEffect.id),
                        severity: experiencedSideEffectIDs.contains(sideEffect.id) ? severityBySideEffectID[sideEffect.id] : nil
                    )
                }

                _ = try RecordSideEffectCheckInUseCase(repository: repository).execute(
                    medicationID: medication.id,
                    responses: responses,
                    notes: notes
                )
            }

            refresh()
            patientMessage = PatientMessage(
                title: "Medication Confirmed",
                message: scheduledDose.scheduledTime > Date()
                    ? "\(medication.name) was recorded early with your side-effect check-in."
                    : "\(medication.name) was recorded with your side-effect check-in."
            )
            return true
        } catch {
            show(error)
            return false
        }
    }

    func scheduleReminder(
        for medicationID: UUID,
        hour: Int,
        minute: Int,
        recurrence: MedicationSchedule.Recurrence = .daily,
        startDate: Date = Date()
    ) {
        do {
            let medication = try ScheduleMedicationReminderUseCase(repository: repository).execute(
                medicationID: medicationID,
                hour: hour,
                minute: minute,
                recurrence: recurrence,
                startDate: startDate
            )
            refresh()
            patientMessage = PatientMessage(
                title: "Reminder Added",
                message: "\(medication.name) now has a reminder at \(String(format: "%02d:%02d", hour, minute))."
            )
        } catch {
            show(error)
        }
    }

    func recordSideEffectCheckIn(
        medicationID: UUID,
        experiencedSideEffectIDs: Set<UUID>,
        severityBySideEffectID: [UUID: Int],
        notes: String
    ) {
        guard let medication = medication(withID: medicationID) else {
            show(RecordSideEffectCheckInUseCase.RecordSideEffectCheckInError.medicationNotFound)
            return
        }

        let responses = medication.trackedSideEffects.map { sideEffect in
            SideEffectResponse(
                sideEffectID: sideEffect.id,
                isExperienced: experiencedSideEffectIDs.contains(sideEffect.id),
                severity: experiencedSideEffectIDs.contains(sideEffect.id) ? severityBySideEffectID[sideEffect.id] : nil
            )
        }

        do {
            _ = try RecordSideEffectCheckInUseCase(repository: repository).execute(
                medicationID: medicationID,
                responses: responses,
                notes: notes
            )
            refresh()
            patientMessage = PatientMessage(
                title: "Check-In Saved",
                message: "Your side-effect check-in for \(medication.name) has been added to your history."
            )
        } catch {
            show(error)
        }
    }

    func searchMedicationCatalog(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            medicationSearchResults = []
            return
        }

        isSearchingMedications = true
        defer { isSearchingMedications = false }

        do {
            medicationSearchResults = try await SearchMedicationCatalogUseCase(
                lookupService: lookupService
            ).execute(query: trimmedQuery)
        } catch {
            medicationSearchResults = []
            show(error)
        }
    }

    func loadLabelSummary(for result: MedicationSearchResult) async {
        isLoadingMedicationLabel = true
        defer { isLoadingMedicationLabel = false }

        do {
            selectedMedicationLabelSummary = try await lookupService.labelSummary(for: result)
        } catch {
            selectedMedicationLabelSummary = .empty
        }
    }

    func clearMedicationSearch() {
        medicationSearchResults = []
        selectedMedicationLabelSummary = .empty
    }

    func addMedicationToPlan(
        name: String,
        dosage: String,
        schedules: [MedicationSchedule],
        trackedSideEffectNames: [String]
    ) -> Bool {
        do {
            let medication = try AddMedicationToPlanUseCase(repository: repository).execute(
                name: name,
                dosage: dosage,
                schedules: schedules,
                trackedSideEffectNames: trackedSideEffectNames
            )
            refresh()
            clearMedicationSearch()
            patientMessage = PatientMessage(
                title: "Medication Added",
                message: "\(medication.name) has been added to today's medication schedule."
            )
            return true
        } catch {
            show(error)
            return false
        }
    }

    private func refresh() {
        medications = repository.medications
        doseRecords = repository.doseRecords.sorted { $0.takenAt > $1.takenAt }
        sideEffectCheckIns = repository.sideEffectCheckIns.sorted { $0.recordedAt > $1.recordedAt }
    }

    private func doseRecord(medicationID: UUID, scheduledTime: Date) -> MedicationDoseRecord? {
        doseRecords.first { record in
            record.medicationID == medicationID
                && calendar.isDate(record.scheduledTime, equalTo: scheduledTime, toGranularity: .minute)
        }
    }

    private func show(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? "The app could not complete that medication action. Check the details and try again."
        patientMessage = PatientMessage(title: "Action Needed", message: message)
    }
}

private struct ExperiencedSideEffectEventSeed {
    let id: String
    let medicationID: UUID
    let medicationName: String
    let sideEffectID: UUID
    let sideEffectName: String
    let recordedAt: Date
    let severity: Int
    let notes: String
}
