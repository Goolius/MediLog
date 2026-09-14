import SwiftUI

struct MedicationDetailView: View {
    @ObservedObject var viewModel: MediLogViewModel
    let medicationID: UUID

    @State private var scheduleTimeframe: DetailScheduleTimeframeOption = .daily
    @State private var reminderTime = Date.nextHalfHour()
    @State private var hourlyInterval = 6
    @State private var weeklyDay = Calendar.current.component(.weekday, from: Date.nextHalfHour())

    var body: some View {
        Group {
            if let medication = viewModel.medication(withID: medicationID) {
                List {
                    Section("Medication") {
                        LabeledContent("Name", value: medication.name)
                        LabeledContent("Dosage", value: medication.dosage)
                    }

                    Section("Reminder Times") {
                        ForEach(medication.scheduledTimes) { schedule in
                            Label(schedule.displaySchedule, systemImage: "bell")
                        }

                        Picker("Timeframe", selection: $scheduleTimeframe) {
                            ForEach(DetailScheduleTimeframeOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }

                        switch scheduleTimeframe {
                        case .hourly:
                            Stepper("Every \(hourlyInterval) hours", value: $hourlyInterval, in: 1...24)
                            DatePicker("Starting At", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        case .daily:
                            DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        case .weekly:
                            Picker("Day", selection: $weeklyDay) {
                                ForEach(1...7, id: \.self) { weekday in
                                    Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
                                }
                            }
                            DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        }

                        Button {
                            let schedule = makeSchedule()
                            viewModel.scheduleReminder(
                                for: medication.id,
                                hour: schedule.hour,
                                minute: schedule.minute,
                                recurrence: schedule.recurrence,
                                startDate: schedule.startDate
                            )
                        } label: {
                            Label("Add Reminder", systemImage: "plus.circle")
                        }
                    }

                    Section("Tracked Side Effects") {
                        ForEach(medication.trackedSideEffects) { sideEffect in
                            Label(sideEffect.name, systemImage: "stethoscope")
                        }
                    }
                }
                .navigationTitle(medication.name)
            } else {
                ContentUnavailableView(
                    "Medication Not Found",
                    systemImage: "pills",
                    description: Text("Return to today's schedule and choose a current medication.")
                )
            }
        }
    }

    private func makeSchedule() -> MedicationSchedule {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = components.hour ?? 8
        let minute = components.minute ?? 0

        switch scheduleTimeframe {
        case .hourly:
            return MedicationSchedule(
                hour: hour,
                minute: minute,
                recurrence: .hourly(hourlyInterval),
                startDate: reminderTime
            )
        case .daily:
            return MedicationSchedule(
                hour: hour,
                minute: minute,
                recurrence: .daily,
                startDate: reminderTime
            )
        case .weekly:
            return MedicationSchedule(
                hour: hour,
                minute: minute,
                recurrence: .weekly(weeklyDay),
                startDate: reminderTime
            )
        }
    }
}

private enum DetailScheduleTimeframeOption: String, CaseIterable, Identifiable {
    case hourly
    case daily
    case weekly

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .hourly:
            return "Hourly"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        }
    }
}

private extension Date {
    static func nextHalfHour(calendar: Calendar = .current) -> Date {
        let now = Date()
        let minute = calendar.component(.minute, from: now)
        let minutesToAdd = minute < 30 ? 30 - minute : 60 - minute
        let rounded = calendar.date(byAdding: .minute, value: minutesToAdd, to: now) ?? now
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rounded)
        return calendar.date(from: components) ?? rounded
    }
}

#Preview {
    NavigationStack {
        MedicationDetailView(
            viewModel: MediLogViewModel(),
            medicationID: InMemoryMedicationRepository.sampleMedications[0].id
        )
    }
}
