import SwiftUI
import Combine

struct DashboardView: View {
    @ObservedObject var viewModel: MediLogViewModel

    @State private var doseBeingConfirmed: ScheduledDose?
    @State private var daysToShow = 21
    @State private var didPositionSchedule = false
    @State private var now = Date()

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var todayDoses: [ScheduledDose] {
        viewModel.todayScheduledDoses
    }

    private var takenTodayDoses: [ScheduledDose] {
        todayDoses.filter(\.isRecorded)
    }

    private var completedMedicationCount: Int {
        takenTodayDoses.count
    }

    private var nextMedication: ScheduledDose? {
        viewModel
            .scheduledDoseSections(daysToShow: daysToShow)
            .flatMap(\.doses)
            .first
    }

    private var doseSections: [ScheduledDoseSection] {
        viewModel.scheduledDoseSections(daysToShow: daysToShow)
    }

    var body: some View {
        VStack(spacing: 0) {
            banner
                .padding(.horizontal)
                .padding(.top, -8)
                .padding(.bottom, 10)

            dashboardHeader
                .padding(.horizontal)
                .padding(.bottom, 10)

            if todayDoses.isEmpty && doseSections.isEmpty {
                ContentUnavailableView(
                    "No Medications Scheduled",
                    systemImage: "calendar.badge.clock",
                    description: Text("Add a medication to start building your schedule.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            if !takenTodayDoses.isEmpty {
                                ScheduleSection(
                                    title: "Taken Today",
                                    doses: takenTodayDoses,
                                    viewModel: viewModel,
                                    now: now,
                                    onConfirm: { doseBeingConfirmed = $0 },
                                    onLoadMore: Optional<() -> Void>.none
                                )
                            }

                            ForEach(doseSections) { section in
                                ScheduleSection(
                                    title: title(for: section.date),
                                    doses: section.doses,
                                    viewModel: viewModel,
                                    now: now,
                                    onConfirm: { doseBeingConfirmed = $0 },
                                    onLoadMore: loadMoreAction(for: section)
                                )
                                .id(sectionID(for: section.date))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .onAppear {
                        guard !didPositionSchedule else {
                            return
                        }

                        didPositionSchedule = true
                        DispatchQueue.main.async {
                            proxy.scrollTo(sectionID(for: Date()), anchor: .top)
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(clock) { currentDate in
            now = currentDate
        }
        .sheet(item: $doseBeingConfirmed) { dose in
            NavigationStack {
                DoseConfirmationView(viewModel: viewModel, scheduledDose: dose)
            }
        }
    }

    private var banner: some View {
        Image("MediLogBanner")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
            )
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today")
                        .font(.largeTitle.weight(.bold))
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "cross.case.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.teal, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 12) {
                SummaryTile(
                    title: "Taken",
                    value: "\(completedMedicationCount)/\(todayDoses.count)",
                    symbol: "checkmark.circle.fill",
                    color: .green
                )

                SummaryTile(
                    title: "Next Medication",
                    value: nextMedication.map { timeFormatter.string(from: $0.scheduledTime) } ?? "Done",
                    symbol: "clock.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var summaryText: String {
        guard let nextMedication else {
            return todayDoses.isEmpty ? "No medications scheduled yet." : "All medications for today are recorded."
        }

        return "Next medication: \(nextMedication.medication.name) at \(timeFormatter.string(from: nextMedication.scheduledTime))"
    }

    private func loadMoreDays() {
        daysToShow += 21
    }

    private func loadMoreAction(for section: ScheduledDoseSection) -> (() -> Void)? {
        guard section.id == doseSections.last?.id else {
            return nil
        }

        return { loadMoreDays() }
    }

    private func title(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func sectionID(for date: Date) -> String {
        "section-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)"
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ScheduleSection: View {
    let title: String
    let doses: [ScheduledDose]
    let viewModel: MediLogViewModel
    let now: Date
    let onConfirm: (ScheduledDose) -> Void
    let onLoadMore: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))

            ForEach(doses) { dose in
                DoseRow(
                    dose: dose,
                    viewModel: viewModel,
                    now: now,
                    onConfirm: { onConfirm(dose) }
                )
            }
        }
        .onAppear {
            onLoadMore?()
        }
    }
}

private struct DoseRow: View {
    let dose: ScheduledDose
    let viewModel: MediLogViewModel
    let now: Date
    let onConfirm: () -> Void

    private var status: DoseDisplayStatus {
        if dose.isTakenEarly {
            return .takenEarly
        }

        if dose.isTakenLate {
            return .takenLate
        }

        if dose.isRecorded {
            return .taken
        }

        if dose.scheduledTime < now {
            return .overdue
        }

        return .upcoming
    }

    var body: some View {
        HStack(spacing: 12) {
            timeBlock

            VStack(alignment: .leading, spacing: 7) {
                Text(dose.medication.name)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(dose.medication.dosage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                NavigationLink {
                    MedicationDetailView(viewModel: viewModel, medicationID: dose.medication.id)
                } label: {
                    Label("Details", systemImage: "info.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.teal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onConfirm()
            } label: {
                Image("TakenIcon")
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .frame(width: 62, height: 62)
            }
            .buttonStyle(TakenIconButtonStyle(color: status.buttonColor))
            .disabled(dose.isRecorded)
            .accessibilityLabel("Mark medication as taken")
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(status.borderColor, lineWidth: status.borderWidth)
        )
        .opacity(dose.isRecorded ? 0.62 : 1)
    }

    private var timeBlock: some View {
        VStack(spacing: 3) {
            Text(countdownText)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()

            Text(dose.scheduledTime, format: .dateTime.hour().minute())
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()

            if let label = status.label {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(status.labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: 78, height: 72)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var countdownText: String {
        guard !dose.isRecorded else {
            return "Taken"
        }

        let secondsUntilDue = dose.scheduledTime.timeIntervalSince(now)
        guard secondsUntilDue > 0 else {
            return "Now"
        }

        if secondsUntilDue < 3600 {
            let minutes = max(1, Int(ceil(secondsUntilDue / 60)))
            return "\(minutes)min"
        }

        let hours = max(1, Int(secondsUntilDue / 3600))
        return "\(hours)h"
    }
}

private struct TakenIconButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(color.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(configuration.isPressed ? 0.85 : 0), lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum DoseDisplayStatus {
    case upcoming
    case overdue
    case taken
    case takenEarly
    case takenLate

    var label: String? {
        switch self {
        case .upcoming:
            return nil
        case .overdue:
            return "Overdue"
        case .taken:
            return "Taken"
        case .takenEarly:
            return "Taken early"
        case .takenLate:
            return "Taken late"
        }
    }

    var labelColor: Color {
        switch self {
        case .upcoming:
            return .secondary
        case .overdue:
            return .red
        case .taken:
            return .green
        case .takenEarly:
            return .blue
        case .takenLate:
            return .red
        }
    }

    var borderColor: Color {
        switch self {
        case .upcoming:
            return .clear
        case .overdue:
            return .red
        case .taken, .takenEarly, .takenLate:
            return .green
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .upcoming:
            return 0
        case .overdue, .taken, .takenEarly, .takenLate:
            return 2
        }
    }

    var buttonColor: Color {
        switch self {
        case .overdue:
            return .red
        case .upcoming, .taken, .takenEarly, .takenLate:
            return .green
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(viewModel: MediLogViewModel())
    }
}
