import SwiftUI

struct DoseConfirmationView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: MediLogViewModel
    let scheduledDose: ScheduledDose

    @State private var experiencedSideEffectIDs: Set<UUID> = []
    @State private var severityBySideEffectID: [UUID: Int] = [:]
    @State private var notes = ""
    @State private var isAddingSideEffect = false
    @State private var newSideEffectName = ""

    private var medication: Medication {
        viewModel.medication(withID: scheduledDose.medication.id) ?? scheduledDose.medication
    }

    var body: some View {
        Form {
            Section("Medication") {
                LabeledContent("Medication", value: medication.name)
                LabeledContent("Dosage", value: medication.dosage)
                LabeledContent("Scheduled", value: scheduledDose.scheduledTime.formatted(date: .omitted, time: .shortened))
            }

            Section {
                if isAddingSideEffect {
                    HStack {
                        TextField("Side effect you're feeling", text: $newSideEffectName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                            .submitLabel(.done)
                            .onSubmit(addSideEffect)

                        Button {
                            addSideEffect()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .disabled(newSideEffectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if medication.trackedSideEffects.isEmpty {
                    Text("No side effects are being tracked for this medication.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(medication.trackedSideEffects) { sideEffect in
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(sideEffect.name, isOn: binding(for: sideEffect.id))

                            if experiencedSideEffectIDs.contains(sideEffect.id) {
                                Stepper(
                                    "Severity \(severityBySideEffectID[sideEffect.id, default: 3]) of 5",
                                    value: severityBinding(for: sideEffect.id),
                                    in: 1...5
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("Side Effects")
                    Spacer()
                    Button {
                        isAddingSideEffect.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add side effect")
                }
            } footer: {
                Text("Select anything you're feeling now. You can add something new if it is not already listed.")
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .autocorrectionDisabled(true)
                    .frame(minHeight: 90)
            }
        }
        .navigationTitle("Confirm Medication")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    confirmMedication()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel("Confirm medication")
            }
        }
    }

    private func confirmMedication() {
        let confirmed = viewModel.confirmDose(
            for: scheduledDose,
            experiencedSideEffectIDs: experiencedSideEffectIDs,
            severityBySideEffectID: severityBySideEffectID,
            notes: notes
        )

        if confirmed {
            dismiss()
        }
    }

    private func addSideEffect() {
        guard let sideEffect = viewModel.addTrackedSideEffect(
            to: scheduledDose.medication.id,
            name: newSideEffectName
        ) else {
            return
        }

        experiencedSideEffectIDs.insert(sideEffect.id)
        severityBySideEffectID[sideEffect.id] = severityBySideEffectID[sideEffect.id] ?? 3
        newSideEffectName = ""
        isAddingSideEffect = false
    }

    private func binding(for sideEffectID: UUID) -> Binding<Bool> {
        Binding(
            get: { experiencedSideEffectIDs.contains(sideEffectID) },
            set: { isExperienced in
                if isExperienced {
                    experiencedSideEffectIDs.insert(sideEffectID)
                    severityBySideEffectID[sideEffectID] = severityBySideEffectID[sideEffectID] ?? 3
                } else {
                    experiencedSideEffectIDs.remove(sideEffectID)
                    severityBySideEffectID[sideEffectID] = nil
                }
            }
        )
    }

    private func severityBinding(for sideEffectID: UUID) -> Binding<Int> {
        Binding(
            get: { severityBySideEffectID[sideEffectID, default: 3] },
            set: { severityBySideEffectID[sideEffectID] = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        Text("Dose confirmation preview")
    }
}
