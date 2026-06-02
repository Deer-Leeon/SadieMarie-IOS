import Foundation
import Observation

/// O(1) day lookup for calendar views. Rebuilds once per appointment batch.
@Observable
final class AppointmentCalendarStore {

  private struct DayKey: Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(date: Date, calendar: Calendar) {
      let start = calendar.startOfDay(for: date)
      let c = calendar.dateComponents([.year, .month, .day], from: start)
      year = c.year ?? 0
      month = c.month ?? 0
      day = c.day ?? 0
    }
  }

  private(set) var appointments: [Appointment] = []
  private(set) var revision: UInt = 0

  private let calendar: Calendar
  private var index: [DayKey: [Appointment]] = [:]

  init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  func replace(appointments: [Appointment], force: Bool = false) {
    let nextIDs = appointments.map(\.id)
    if !force, nextIDs == self.appointments.map(\.id) { return }
    self.appointments = appointments
    index = Self.buildIndex(appointments: appointments, calendar: calendar)
    revision &+= 1
  }

  func appointments(on day: Date) -> [Appointment] {
    index[DayKey(date: day, calendar: calendar)] ?? []
  }

  private static func buildIndex(
    appointments: [Appointment],
    calendar: Calendar
  ) -> [DayKey: [Appointment]] {
    var buckets: [DayKey: [Appointment]] = [:]
    buckets.reserveCapacity(min(appointments.count, 366))

    for appointment in appointments {
      guard
        let iso = appointment.bookingTime,
        let instant = BookingDisplay.iso8601Date(from: iso)
      else { continue }

      let key = DayKey(date: instant, calendar: calendar)
      buckets[key, default: []].append(appointment)
    }

    for key in buckets.keys {
      buckets[key]?.sort { ($0.bookingTime ?? "") < ($1.bookingTime ?? "") }
    }

    return buckets
  }
}
