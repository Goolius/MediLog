import XCTest
@testable import MediLog

@MainActor
final class MediLogUseCaseTests: XCTestCase {
    func test_recordDose_succeeds_whenScheduledDoseIsNotAlreadyRecorded() throws {
        let medication = makeMedication()
        let repository = InMemoryMedicationRepository(medications: [medication])
        let useCase = RecordMedicationDoseUseCase(repository: repository)
        let scheduledTime = Date(timeIntervalSince1970: 1_000)

        let record = try useCase.execute(
            medicationID: medication.id,
            scheduledTime: scheduledTime,
            takenAt: scheduledTime.addingTimeInterval(60)
        )

        XCTAssertEqual(record.medicationID, medication.id)
        XCTAssertEqual(repository.doseRecords.count, 1)
    }

    func test_recordDose_fails_whenDoseAlreadyRecordedForScheduledTime() throws {
        let medication = makeMedication()
        let scheduledTime = Date(timeIntervalSince1970: 2_000)
        let existingRecord = MedicationDoseRecord(
            medicationID: medication.id,
            scheduledTime: scheduledTime,
            takenAt: scheduledTime
        )
        let repository = InMemoryMedicationRepository(
            medications: [medication],
            doseRecords: [existingRecord]
        )
        let useCase = RecordMedicationDoseUseCase(repository: repository)

        XCTAssertThrowsError(
            try useCase.execute(
                medicationID: medication.id,
                scheduledTime: scheduledTime,
                takenAt: scheduledTime.addingTimeInterval(120)
            )
        ) { error in
            XCTAssertEqual(
                error as? RecordMedicationDoseUseCase.RecordMedicationDoseError,
                .duplicateDose
            )
        }
    }

    func test_recordDose_fails_whenMedicationIsNotInPatientList() {
        let repository = InMemoryMedicationRepository(medications: [])
        let useCase = RecordMedicationDoseUseCase(repository: repository)

        XCTAssertThrowsError(
            try useCase.execute(
                medicationID: UUID(),
                scheduledTime: Date(),
                takenAt: Date()
            )
        ) { error in
            XCTAssertEqual(
                error as? RecordMedicationDoseUseCase.RecordMedicationDoseError,
                .medicationNotFound
            )
        }
    }

    func test_recordDose_succeeds_whenPatientRecordsMedicationEarly() throws {
        let medication = makeMedication()
        let repository = InMemoryMedicationRepository(medications: [medication])
        let useCase = RecordMedicationDoseUseCase(repository: repository)
        let scheduledTime = Date(timeIntervalSince1970: 5_000)

        let record = try useCase.execute(
            medicationID: medication.id,
            scheduledTime: scheduledTime,
            takenAt: scheduledTime.addingTimeInterval(-20 * 60)
        )

        XCTAssertLessThan(record.takenAt, record.scheduledTime)
    }

    func test_scheduleMedicationReminder_succeeds_whenTimeIsValidAndNew() throws {
        let medication = makeMedication()
        let repository = InMemoryMedicationRepository(medications: [medication])
        let useCase = ScheduleMedicationReminderUseCase(repository: repository)

        let updatedMedication = try useCase.execute(
            medicationID: medication.id,
            hour: 21,
            minute: 15
        )

        XCTAssertTrue(updatedMedication.scheduledTimes.contains { $0.hour == 21 && $0.minute == 15 })
    }

    func test_scheduleMedicationReminder_fails_whenTimeIsOutsideValidClockRange() {
        let medication = makeMedication()
        let repository = InMemoryMedicationRepository(medications: [medication])
        let useCase = ScheduleMedicationReminderUseCase(repository: repository)

        XCTAssertThrowsError(
            try useCase.execute(medicationID: medication.id, hour: 25, minute: 0)
        ) { error in
            XCTAssertEqual(
                error as? ScheduleMedicationReminderUseCase.ScheduleMedicationReminderError,
                .invalidTime
            )
        }
    }

    func test_scheduleMedicationReminder_fails_whenReminderAlreadyExistsForMedication() {
        let medication = makeMedication(scheduledTimes: [MedicationSchedule(hour: 8, minute: 0)])
        let repository = InMemoryMedicationRepository(medications: [medication])
        let useCase = ScheduleMedicationReminderUseCase(repository: repository)

        XCTAssertThrowsError(
            try useCase.execute(medicationID: medication.id, hour: 8, minute: 0)
        ) { error in
            XCTAssertEqual(
                error as? ScheduleMedicationReminderUseCase.ScheduleMedicationReminderError,
                .duplicateReminderTime
            )
        }
    }

    func test_localMedicationRepository_persistsSavedMedication() throws {
        let fileURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("medilog-test-\(UUID().uuidString).json")
        let medication = makeMedication()
        let repository = LocalMedicationRepository(fileURL: fileURL)

        repository.saveMedication(medication)

        let reloadedRepository = LocalMedicationRepository(fileURL: fileURL)
        XCTAssertEqual(reloadedRepository.medications, [medication])
    }

    func test_medicationSchedule_occursEveryTwoDaysFromStartDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 8)))
        let nextDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 8)))
        let secondDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 8)))
        let schedule = MedicationSchedule(
            hour: 8,
            minute: 0,
            recurrence: .everyDays(2),
            startDate: startDate
        )

        XCTAssertTrue(schedule.occurs(on: startDate, calendar: calendar))
        XCTAssertFalse(schedule.occurs(on: nextDay, calendar: calendar))
        XCTAssertTrue(schedule.occurs(on: secondDay, calendar: calendar))
    }

    func test_medicationSchedule_returnsMultipleHourlyDosesForDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 8)))
        let requestedDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 14)))
        let schedule = MedicationSchedule(
            hour: 8,
            minute: 0,
            recurrence: .hourly(6),
            startDate: startDate
        )

        let doseHours = schedule
            .scheduledDates(on: requestedDay, calendar: calendar)
            .map { calendar.component(.hour, from: $0) }

        XCTAssertEqual(doseHours, [2, 8, 14, 20])
    }

    func test_recordSideEffectCheckIn_succeeds_whenExperiencedSideEffectHasValidSeverity() throws {
        let sideEffect = SideEffect(name: "Nausea")
        let medication = makeMedication(sideEffects: [sideEffect])
        let repository = InMemoryMedicationRepository(medications: [medication])
        let useCase = RecordSideEffectCheckInUseCase(repository: repository)

        let checkIn = try useCase.execute(
            medicationID: medication.id,
            responses: [
                SideEffectResponse(
                    sideEffectID: sideEffect.id,
                    isExperienced: true,
                    severity: 3
                )
            ],
            notes: "Mild after breakfast"
        )

        XCTAssertEqual(checkIn.responses.count, 1)
        XCTAssertEqual(repository.sideEffectCheckIns.count, 1)
    }

    func test_recordSideEffectCheckIn_fails_whenExperiencedSideEffectHasNoSeverity() {
        let sideEffect = SideEffect(name: "Dizziness")
        let medication = makeMedication(sideEffects: [sideEffect])
        let repository = InMemoryMedicationRepository(medications: [medication])
        let useCase = RecordSideEffectCheckInUseCase(repository: repository)

        XCTAssertThrowsError(
            try useCase.execute(
                medicationID: medication.id,
                responses: [
                    SideEffectResponse(
                        sideEffectID: sideEffect.id,
                        isExperienced: true,
                        severity: nil
                    )
                ]
            )
        ) { error in
            XCTAssertEqual(
                error as? RecordSideEffectCheckInUseCase.RecordSideEffectCheckInError,
                .missingSeverity(sideEffectName: "Dizziness")
            )
        }
    }

    func test_recordSideEffectCheckIn_fails_whenSeverityIsOutsideAllowedRange() {
        let sideEffect = SideEffect(name: "Headache")
        let medication = makeMedication(sideEffects: [sideEffect])
        let repository = InMemoryMedicationRepository(medications: [medication])
        let useCase = RecordSideEffectCheckInUseCase(repository: repository)

        XCTAssertThrowsError(
            try useCase.execute(
                medicationID: medication.id,
                responses: [
                    SideEffectResponse(
                        sideEffectID: sideEffect.id,
                        isExperienced: true,
                        severity: 7
                    )
                ]
            )
        ) { error in
            XCTAssertEqual(
                error as? RecordSideEffectCheckInUseCase.RecordSideEffectCheckInError,
                .invalidSeverity(sideEffectName: "Headache")
            )
        }
    }

    private func makeMedication(
        scheduledTimes: [MedicationSchedule] = [MedicationSchedule(hour: 8, minute: 0)],
        sideEffects: [SideEffect] = [SideEffect(name: "Nausea")]
    ) -> Medication {
        Medication(
            name: "Test Medication",
            dosage: "10 mg",
            scheduledTimes: scheduledTimes,
            trackedSideEffects: sideEffects
        )
    }
}
