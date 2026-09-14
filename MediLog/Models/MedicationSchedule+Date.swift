import Foundation

extension MedicationSchedule {
    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        let requestedDay = calendar.startOfDay(for: date)
        let firstDay = calendar.startOfDay(for: startDate)

        guard requestedDay >= firstDay else {
            return false
        }

        switch recurrence {
        case .hourly:
            return !scheduledDates(on: date, calendar: calendar).isEmpty
        case .daily:
            return true
        case .everyDays(let interval):
            guard interval > 0 else {
                return false
            }
            let daysSinceStart = calendar.dateComponents([.day], from: firstDay, to: requestedDay).day ?? 0
            return daysSinceStart % interval == 0
        case .weekly(let weekday):
            return calendar.component(.weekday, from: requestedDay) == weekday
        }
    }

    func scheduledDates(on date: Date, calendar: Calendar = .current) -> [Date] {
        switch recurrence {
        case .hourly(let interval):
            guard interval > 0 else {
                return []
            }

            let dayStart = calendar.startOfDay(for: date)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return []
            }

            var dates: [Date] = []
            var nextDose = startDate

            while nextDose < dayStart {
                guard let advanced = calendar.date(byAdding: .hour, value: interval, to: nextDose) else {
                    return dates
                }
                nextDose = advanced
            }

            while nextDose < nextDay {
                if nextDose >= dayStart {
                    dates.append(nextDose)
                }

                guard let advanced = calendar.date(byAdding: .hour, value: interval, to: nextDose) else {
                    break
                }
                nextDose = advanced
            }

            return dates
        default:
            guard occurs(on: date, calendar: calendar) else {
                return []
            }
            return [scheduledDate(on: date, calendar: calendar)]
        }
    }

    func scheduledDate(on date: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    var displayTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    func displayRecurrence(calendar: Calendar = .current) -> String {
        switch recurrence {
        case .hourly(let interval):
            return interval == 1 ? "Every hour" : "Every \(interval) hours"
        case .daily:
            return "Daily"
        case .everyDays(let interval):
            return interval == 2 ? "Every 2 days" : "Every \(interval) days"
        case .weekly(let weekday):
            return "Weekly on \(weekdayName(for: weekday, calendar: calendar))"
        }
    }

    var displaySchedule: String {
        "\(displayTime) • \(displayRecurrence())"
    }

    private func weekdayName(for weekday: Int, calendar: Calendar) -> String {
        let symbols = calendar.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return "selected day"
        }
        return symbols[weekday - 1]
    }
}
