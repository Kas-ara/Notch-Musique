import Foundation
import Combine

/// One locally saved target. The remaining time is always derived from its absolute deadline.
final class CountdownModel: ObservableObject {
    struct Target: Codable, Equatable {
        let label: String
        let date: Date
    }
    struct Remaining: Equatable {
        let weeks: Int
        let days: Int
        let hours: Int
        let minutes: Int
        let arrived: Bool
        var full: String { arrived ? "C’est le moment !" : "\(weeks) sem · \(days) j · \(hours) h · \(minutes) min" }
        var compact: String { arrived ? "♥" : "\(weeks)s \(days)j\n\(hours)h \(minutes)m" }
    }
    @Published private(set) var target: Target?
    private let defaults: UserDefaults?
    private static let key = "countdown.target"

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Target.self, from: data),
           !saved.label.isEmpty, saved.date.timeIntervalSince1970.isFinite {
            target = saved
        }
    }
    @discardableResult func save(label: String, date: Date) -> Bool {
        let clean = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !clean.isEmpty, date.timeIntervalSince1970.isFinite else { return false }
        let value = Target(label: clean, date: date)
        guard let data = try? JSONEncoder().encode(value) else { return false }
        defaults?.set(data, forKey: Self.key)
        target = value
        return true
    }
    func clear() {
        defaults?.removeObject(forKey: Self.key)
        target = nil
    }
    func remaining(at now: Date) -> Remaining {
        let interval = target?.date.timeIntervalSince(now) ?? 0
        // Round up to the next minute so a future target never appears to have arrived early.
        let total = Int(min(Double(Int.max / 2), ceil(max(0, interval) / 60)))
        return Remaining(weeks: total / 10080, days: total / 1440 % 7,
                         hours: total / 60 % 24, minutes: total % 60, arrived: interval <= 0)
    }
    func showsWhenIdle(playing: Bool, focusStarted: Bool, meeting: Bool) -> Bool {
        target != nil && !playing && !focusStarted && !meeting
    }
}
