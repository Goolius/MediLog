# MediLog

MediLog is a SwiftUI iOS MVP for patients managing medication at home. The app helps a patient track what medication is due, confirm when it has been taken, record side effects, and review medication history later.

## Domain Problem

Patients taking medication at home may forget doses, take medication late or early, or lose track of side effects over time. MediLog is designed around that patient workflow. Instead of being a generic task tracker, the app uses healthcare-specific concepts such as medications, schedules, dose records, side effects, severity ratings, and check-ins.

## Main Features

- Add a medication to a personal medication plan.
- Set flexible schedules:
  - hourly intervals
  - daily times
  - weekly day/time schedules
- View medications grouped by date on the home screen.
- See live countdowns and status labels such as overdue, taken, taken early, and taken late.
- Confirm a medication as taken.
- Record side effects, severity, and notes during confirmation.
- Add a new side effect while confirming a medication.
- Review medication history and side-effect history.
- Store medication data locally on the device.

## App Screens

- **Dashboard**: Shows today's progress, next medication, upcoming medication sections, and taken medications.
- **Add Medication**: Lets the patient manually enter a medication.
- **Medication Settings**: Lets the patient configure dosage, schedule, and side effects.
- **Confirm Medication**: Lets the patient confirm a medication and record side effects.
- **Medication Detail**: Shows medication details and reminders.
- **History**: Shows medication records and experienced side effects.

## Architecture

MediLog uses MVVM with a Use Case layer:

```text
Patient
  ↓
SwiftUI Views
  ↓
MediLogViewModel
  ↓
Use Cases
  ↓
Domain Models + Repository
  ↓
Local JSON Data
```

The SwiftUI views handle presentation and user interaction. `MediLogViewModel` prepares data for the interface and coordinates use cases. Use cases contain the main business rules. Repositories handle storage.

## Key Use Cases

- `AddMedicationToPlanUseCase`
  - Adds a medication to the patient plan.
  - Validates medication name, dosage, schedule, and duplicates.

- `RecordMedicationDoseUseCase`
  - Records that a medication was taken.
  - Prevents duplicate records for the same medication and scheduled time.
  - Allows early medication recording so the app reflects real patient behaviour.

- `RecordSideEffectCheckInUseCase`
  - Records side-effect responses.
  - Requires severity when a side effect is experienced.
  - Validates severity is between 1 and 5.

- `ScheduleMedicationReminderUseCase`
  - Adds reminder schedules to existing medications.
  - Validates time, recurrence, and duplicate reminders.

## Domain Models

Important models include:

- `Medication`
- `MedicationSchedule`
- `MedicationDoseRecord`
- `SideEffect`
- `SideEffectCheckIn`
- `SideEffectResponse`

These names are intentionally domain-specific so the code reflects the real healthcare workflow.

## Data Storage

The app uses `MedicationRepository` as a storage abstraction.

- `LocalMedicationRepository` stores medication data as JSON in the app documents directory.
- `InMemoryMedicationRepository` is used for previews and tests.

## Testing

The project includes unit tests in `MediLogTests`. The tests focus on business rules, including:

- valid medication recording
- duplicate medication record prevention
- early medication recording
- reminder scheduling validation
- local repository persistence
- hourly and recurring schedules
- side-effect severity validation

## How To Run

1. Open `MediLog.xcodeproj` in Xcode.
2. Select the `MediLog` scheme.
3. Choose an iPhone Simulator.
4. Press Run.

If the Simulator becomes unstable, quit Simulator and relaunch it from Xcode.

## Assessment Notes

This project was built as a domain-centred iOS MVP. The main goal is to show how SwiftUI, MVVM, Use Cases, domain models, repositories, error handling, and tests can work together to solve a realistic patient medication-tracking problem.
