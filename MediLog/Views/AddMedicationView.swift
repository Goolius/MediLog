import SwiftUI

struct AddMedicationView: View {
    @ObservedObject var viewModel: MediLogViewModel

    @State private var searchText = ""
    @State private var medicationToConfigure: MedicationSearchResult?

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Type medication name", text: $searchText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .submitLabel(.next)
                        .onSubmit {
                            continueWithTypedMedication()
                        }

                    Button {
                        continueWithTypedMedication()
                    } label: {
                        Image(systemName: "arrow.forward.circle.fill")
                    }
                    .disabled(trimmedSearchText.isEmpty)
                }
            } header: {
                Text("Medication")
            } footer: {
                Text("Medication search is temporarily turned off. Enter the medication name manually.")
            }
        }
        .navigationTitle("Add Medication")
        .navigationDestination(item: $medicationToConfigure) { result in
            MedicationSettingsView(
                viewModel: viewModel,
                medicationResult: result,
                onSaved: resetSearch
            )
        }
    }

    private func continueWithTypedMedication() {
        let query = trimmedSearchText
        guard !query.isEmpty else {
            return
        }

        openSettings(
            for: MedicationSearchResult(
                id: "custom-\(query.lowercased())",
                name: query,
                suggestedDosage: "Confirm from prescription label",
                source: "Custom"
            )
        )
    }

    private func openSettings(for result: MedicationSearchResult) {
        medicationToConfigure = result
    }

    private func resetSearch() {
        searchText = ""
        medicationToConfigure = nil
        viewModel.clearMedicationSearch()
    }
}

private struct MedicationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: MediLogViewModel
    let medicationResult: MedicationSearchResult
    let onSaved: () -> Void

    @State private var customDosage = ""
    @State private var scheduleTimeframe: ScheduleTimeframeOption = .daily
    @State private var hourlyStartTime = Date.nextHalfHour()
    @State private var hourlyInterval = 6
    @State private var dailyTimes: [Date] = [Date.nextHalfHour()]
    @State private var weeklyTimes: [WeeklyScheduleDraft] = [WeeklyScheduleDraft()]
    @State private var trackedSideEffects: [String] = []
    @State private var newSideEffect = ""
    @State private var didLoadDefaults = false

    private var isCustomMedication: Bool {
        medicationResult.source == "Custom"
    }

    private var dosageForSave: String {
        let trimmedDosage = customDosage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDosage.isEmpty ? medicationResult.suggestedDosage : trimmedDosage
    }

    var body: some View {
        Form {
            Section("Medication Details") {
                LabeledContent("Medication", value: medicationResult.name)

                TextField("Dosage", text: $customDosage, prompt: Text(medicationResult.suggestedDosage))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                Picker("Timeframe", selection: $scheduleTimeframe) {
                    ForEach(ScheduleTimeframeOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }

            Section("Schedule") {
                switch scheduleTimeframe {
                case .hourly:
                    Stepper("Every \(hourlyInterval) hours", value: $hourlyInterval, in: 1...24)
                    DatePicker("Starting At", selection: $hourlyStartTime, displayedComponents: .hourAndMinute)
                case .daily:
                    ForEach(dailyTimes.indices, id: \.self) { index in
                        HStack {
                            DatePicker("Dose \(index + 1)", selection: $dailyTimes[index], displayedComponents: .hourAndMinute)

                            if dailyTimes.count > 1 {
                                Button {
                                    dailyTimes.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        dailyTimes.append(Date.nextHalfHour())
                    } label: {
                        Label("Add Another Time", systemImage: "plus.circle")
                    }
                case .weekly:
                    ForEach(weeklyTimes.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Day", selection: $weeklyTimes[index].weekday) {
                                ForEach(1...7, id: \.self) { weekday in
                                    Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
                                }
                            }

                            HStack {
                                DatePicker("Time", selection: $weeklyTimes[index].time, displayedComponents: .hourAndMinute)

                                if weeklyTimes.count > 1 {
                                    Button {
                                        weeklyTimes.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Button {
                        weeklyTimes.append(WeeklyScheduleDraft())
                    } label: {
                        Label("Add Weekly Dose", systemImage: "plus.circle")
                    }
                }
            }

            Section("Tracked Side Effects") {
                if viewModel.isLoadingMedicationLabel {
                    ProgressView("Loading common side effects")
                }

                if trackedSideEffects.isEmpty {
                    Text(isCustomMedication ? "Add any side effects you want to track." : "No default side effects found. You can add your own.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(trackedSideEffects, id: \.self) { sideEffect in
                        HStack {
                            Text(sideEffect)
                            Spacer()
                            Button {
                                remove(sideEffect)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    TextField("Add side effect", text: $newSideEffect)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                    Button {
                        addCustomSideEffect()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newSideEffect.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section {
                Button {
                    let saved = viewModel.addMedicationToPlan(
                        name: medicationResult.name,
                        dosage: dosageForSave,
                        schedules: makeSchedules(),
                        trackedSideEffectNames: trackedSideEffects
                    )

                    if saved {
                        onSaved()
                        dismiss()
                    }
                } label: {
                    Label("Add Medication to Plan", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            } footer: {
                Text("Use the dosage from your prescription label. Side effects are for your own tracking and can be changed later.")
            }
        }
        .navigationTitle("Medication Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDefaultsIfNeeded()
        }
    }

    private func loadDefaultsIfNeeded() async {
        guard !didLoadDefaults else {
            return
        }

        didLoadDefaults = true
        guard !isCustomMedication else {
            return
        }

        await viewModel.loadLabelSummary(for: medicationResult)
        trackedSideEffects = viewModel.selectedMedicationLabelSummary.suggestedSideEffects
    }

    private func addCustomSideEffect() {
        let trimmedSideEffect = newSideEffect.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSideEffect.isEmpty else {
            return
        }

        if !trackedSideEffects.contains(where: { $0.caseInsensitiveCompare(trimmedSideEffect) == .orderedSame }) {
            trackedSideEffects.append(trimmedSideEffect)
        }
        newSideEffect = ""
    }

    private func remove(_ sideEffect: String) {
        trackedSideEffects.removeAll { $0 == sideEffect }
    }

    private func makeSchedules() -> [MedicationSchedule] {
        switch scheduleTimeframe {
        case .hourly:
            let components = Calendar.current.dateComponents([.hour, .minute], from: hourlyStartTime)
            return [
                MedicationSchedule(
                    hour: components.hour ?? 8,
                    minute: components.minute ?? 0,
                    recurrence: .hourly(hourlyInterval),
                    startDate: hourlyStartTime
                )
            ]
        case .daily:
            return dailyTimes.map { time in
                let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                return MedicationSchedule(
                    hour: components.hour ?? 8,
                    minute: components.minute ?? 0,
                    recurrence: .daily,
                    startDate: time
                )
            }
        case .weekly:
            return weeklyTimes.map { draft in
                let components = Calendar.current.dateComponents([.hour, .minute], from: draft.time)
                return MedicationSchedule(
                    hour: components.hour ?? 8,
                    minute: components.minute ?? 0,
                    recurrence: .weekly(draft.weekday),
                    startDate: draft.time
                )
            }
        }
    }
}

private enum ScheduleTimeframeOption: String, CaseIterable, Identifiable {
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

private struct WeeklyScheduleDraft: Identifiable {
    let id = UUID()
    var weekday = Calendar.current.component(.weekday, from: Date.nextHalfHour())
    var time = Date.nextHalfHour()
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
        AddMedicationView(viewModel: MediLogViewModel())
    }
}
