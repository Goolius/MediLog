import SwiftUI

struct SideEffectCheckInView: View {
    @ObservedObject var viewModel: MediLogViewModel

    @State private var selectedMedicationID: UUID?
    @State private var experiencedSideEffectIDs: Set<UUID> = []
    @State private var severityBySideEffectID: [UUID: Int] = [:]
    @State private var notes = ""

    private var selectedMedication: Medication? {
        guard let selectedMedicationID else {
            return viewModel.medications.first
        }
        return viewModel.medication(withID: selectedMedicationID)
    }

    var body: some View {
        Form {
            if viewModel.medications.isEmpty {
                ContentUnavailableView(
                    "No Medications",
                    systemImage: "pills",
                    description: Text("Add medication details before recording a side-effect check-in.")
                )
            } else {
                Section("Medication") {
                    Picker("Check-In For", selection: selectedMedicationBinding) {
                        ForEach(viewModel.medications) { medication in
                            Text(medication.name).tag(Optional(medication.id))
                        }
                    }
                }

                if let medication = selectedMedication {
                    Section("Side Effects") {
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

                Section("Patient Notes") {
                    TextEditor(text: $notes)
                        .autocorrectionDisabled(true)
                        .frame(minHeight: 90)
                }

                    Button {
                        viewModel.recordSideEffectCheckIn(
                            medicationID: medication.id,
                            experiencedSideEffectIDs: experiencedSideEffectIDs,
                            severityBySideEffectID: severityBySideEffectID,
                            notes: notes
                        )
                        clearCheckInForm()
                    } label: {
                        Label("Save Side-Effect Check-In", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .navigationTitle("Check-In")
        .onAppear {
            selectedMedicationID = selectedMedicationID ?? viewModel.medications.first?.id
        }
    }

    private var selectedMedicationBinding: Binding<UUID?> {
        Binding(
            get: { selectedMedicationID ?? viewModel.medications.first?.id },
            set: { newValue in
                selectedMedicationID = newValue
                clearCheckInForm()
            }
        )
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

    private func clearCheckInForm() {
        experiencedSideEffectIDs.removeAll()
        severityBySideEffectID.removeAll()
        notes = ""
    }
}

#Preview {
    NavigationStack {
        SideEffectCheckInView(viewModel: MediLogViewModel())
    }
}
