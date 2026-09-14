import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: MediLogViewModel

    var body: some View {
        List {
            if !viewModel.experiencedSideEffectEvents.isEmpty {
                Section("Side Effects Experienced") {
                    ForEach(viewModel.experiencedSideEffectEvents) { event in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.sideEffectName)
                                        .font(.headline)
                                    Text(event.medicationName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("Severity \(event.severity)/5")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.orange.opacity(0.18), in: Capsule())
                                    .foregroundStyle(.orange)
                            }

                            Text("Experienced \(event.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 14) {
                                Label("\(event.totalOccurrences) total", systemImage: "number.circle")
                                Label(String(format: "%.1f avg severity", event.averageSeverity), systemImage: "chart.line.uptrend.xyaxis")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if !event.notes.isEmpty {
                                Text(event.notes)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }

            Section("Medication Dose History") {
                if viewModel.doseRecords.isEmpty {
                    ContentUnavailableView(
                        "No Medications Recorded",
                        systemImage: "checkmark.circle",
                        description: Text("Recorded medications will appear here after the patient confirms a scheduled medication.")
                    )
                } else {
                    ForEach(viewModel.doseRecords) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(viewModel.medicationName(for: record.medicationID))
                                    .font(.headline)

                                Spacer()

                                if record.takenAt < record.scheduledTime {
                                    Text("Taken early")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.16), in: Capsule())
                                        .foregroundStyle(.green)
                                }
                            }

                            Text("Scheduled \(record.scheduledTime.formatted(date: .abbreviated, time: .shortened))")
                                .foregroundStyle(.secondary)
                            Text("Taken \(record.takenAt.formatted(date: .abbreviated, time: .shortened))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}

#Preview {
    NavigationStack {
        HistoryView(viewModel: MediLogViewModel())
    }
}
