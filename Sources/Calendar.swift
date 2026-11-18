import AppKit
import Combine
import EventKit

struct AgendaEvent: Identifiable {
    let id: String
    let title: String
    let calendar: String
    let start: Date
    let end: Date
    let allDay: Bool
    let color: NSColor

    func subtitle(at now: Date = Date()) -> String {
        let day: String
        if Calendar.current.isDateInToday(start) { day = L10n.text("calendar.today") }
        else if Calendar.current.isDateInTomorrow(start) { day = L10n.text("calendar.tomorrow") }
        else { day = start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(L10n.locale)) }
        let time = allDay ? L10n.text("calendar.allDay") : start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale))
        return "\(day) · \(time) · \(calendar)"
    }
}

final class CalendarModel: ObservableObject {
    enum Access { case unrequested, loading, ready, denied, restricted, failed }
    @Published private(set) var access: Access = .unrequested
    @Published private(set) var events: [AgendaEvent] = []
    @Published private(set) var errorMessage: String?
    private lazy var store = EKEventStore()
    private let queue = DispatchQueue(label: "local.notchmusique.calendar", qos: .userInitiated)
    private var observer: NSObjectProtocol?
    private var timer: Timer?
    private var active = false
    private var requestInFlight = false
    private var generation = 0
    let demo: Bool

    init(demo: Bool = false) {
        self.demo = demo
        if demo {
            access = .ready
            let now = Date()
            events = [AgendaEvent(id: "demo", title: L10n.text("demo.event"), calendar: L10n.text("demo.badge"),
                                  start: now.addingTimeInterval(3600), end: now.addingTimeInterval(5400),
                                  allDay: false, color: .systemBlue)]
        } else {
            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.active else { return }
                self.refresh()
            }
        }
    }
    deinit {
        timer?.invalidate()
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
    var nextMeeting: AgendaEvent? {
        let now = Date()
        return events.first { !$0.allDay && $0.end > now && $0.start <= now.addingTimeInterval(15 * 60) }
    }
    func setActive(_ value: Bool) {
        active = value
        timer?.invalidate()
        timer = nil
        if !value { generation += 1; return }
        refresh()
        guard !demo else { return }
        let next = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        next.tolerance = 5
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }
    func connect() {
        guard !demo, !requestInFlight else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        var canRequest = status == .notDetermined
        if #available(macOS 14.0, *) { canRequest = canRequest || status == .writeOnly }
        guard canRequest else { refresh(); return }
        requestInFlight = true
        access = .loading
        let completion: (Bool, Error?) -> Void = { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.requestInFlight = false
                if let error { self.errorMessage = error.localizedDescription; self.access = .failed }
                else { self.refresh() }
            }
        }
        if #available(macOS 14.0, *) { store.requestFullAccessToEvents(completion: completion) }
        else { store.requestAccess(to: .event, completion: completion) }
    }
    func refresh() {
        guard !demo, !requestInFlight else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        let allowed: Bool
        if #available(macOS 14.0, *) { allowed = status == .fullAccess }
        else { allowed = status == .authorized }
        guard allowed else {
            generation += 1
            events = []
            if status == .notDetermined { access = .unrequested }
            else if status == .restricted { access = .restricted }
            else { access = .denied }
            return
        }
        if access != .ready { access = .loading }
        generation += 1
        let request = generation
        let eventStore = store
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        queue.async { [weak self] in
            let predicate = eventStore.predicateForEvents(withStart: now, end: end, calendars: nil)
            let results = eventStore.events(matching: predicate)
                .filter { $0.endDate > now && $0.status != .canceled && !$0.attendeesDeclined }
                .sorted { $0.startDate < $1.startDate }
                .prefix(50)
                .enumerated().map { index, event in
                    AgendaEvent(id: "\(event.eventIdentifier ?? String(index))-\(event.startDate.timeIntervalSince1970)",
                                title: event.title ?? L10n.text("calendar.untitled"), calendar: event.calendar.title,
                                start: event.startDate, end: event.endDate, allDay: event.isAllDay,
                                color: NSColor(cgColor: event.calendar.cgColor) ?? .systemBlue)
                }
            DispatchQueue.main.async {
                guard let self, self.generation == request else { return }
                self.events = results
                self.errorMessage = nil
                self.access = .ready
            }
        }
    }
}

private extension EKEvent {
    var attendeesDeclined: Bool {
        attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }
}
