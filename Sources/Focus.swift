import AppKit
import Combine

/// Wall-clock deadlines keep a session accurate across display sleep and delayed timer callbacks.
final class FocusModel: ObservableObject {
    enum Phase: String { case focus, rest
        var title: String { self == .focus ? L10n.text("tab.focus") : L10n.text("focus.break") }
        var symbol: String { self == .focus ? "timer" : "cup.and.saucer.fill" }
    }
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var running = false
    @Published private(set) var started = false
    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published private(set) var workMinutes: Int
    @Published private(set) var breakMinutes: Int
    var phaseChanged: (() -> Void)?
    private var deadline: Date?
    private var timer: Timer?
    private var visible = true
    private let defaults: UserDefaults?
    private let automaticTimer: Bool

    init(defaults: UserDefaults? = .standard, automaticTimer: Bool = true) {
        self.defaults = defaults
        self.automaticTimer = automaticTimer
        let work = defaults?.integer(forKey: "focus.work") ?? 0
        let rest = defaults?.integer(forKey: "focus.break") ?? 0
        workMinutes = (1...120).contains(work) ? work : 25
        breakMinutes = (1...60).contains(rest) ? rest : 5
        remaining = Double(workMinutes * 60)
    }
    deinit { timer?.invalidate() }
    var duration: TimeInterval { Double((phase == .focus ? workMinutes : breakMinutes) * 60) }
    var progress: Double { min(1, max(0, 1 - remaining / duration)) }
    var time: String {
        let seconds = Int(ceil(max(0, remaining)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    func configure(work: Int, rest: Int) {
        guard !started else { return }
        workMinutes = min(120, max(1, work))
        breakMinutes = min(60, max(1, rest))
        defaults?.set(workMinutes, forKey: "focus.work")
        defaults?.set(breakMinutes, forKey: "focus.break")
        reset()
    }
    func toggle(at now: Date = Date()) {
        if running {
            tick(at: now)
            running = false
            deadline = nil
        } else {
            started = true
            running = true
            deadline = now.addingTimeInterval(remaining)
        }
        schedule()
    }
    func reset() {
        running = false
        started = false
        deadline = nil
        phase = .focus
        remaining = duration
        schedule()
    }
    func skip(at now: Date = Date()) {
        // First settle overdue phases; skipping always advances from the current phase.
        tick(at: now)
        phase = phase == .focus ? .rest : .focus
        remaining = duration
        if running { deadline = now.addingTimeInterval(remaining) }
        phaseChanged?()
    }
    func tick(at now: Date = Date()) {
        guard running, let end = deadline else { return }
        guard now >= end else { remaining = end.timeIntervalSince(now); return }
        phase = phase == .focus ? .rest : .focus
        let cycle = Double((workMinutes + breakMinutes) * 60)
        // Skip complete cycles without looping after a long sleep.
        let overdue = now.timeIntervalSince(end).truncatingRemainder(dividingBy: cycle)
        if overdue >= duration {
            let firstDuration = duration
            phase = phase == .focus ? .rest : .focus
            remaining = duration - (overdue - firstDuration)
        } else {
            remaining = duration - overdue
        }
        deadline = now.addingTimeInterval(remaining)
        phaseChanged?()
    }
    func setVisible(_ value: Bool, at now: Date = Date()) {
        visible = value
        tick(at: now)
        schedule()
    }
    private func schedule() {
        timer?.invalidate()
        timer = nil
        guard automaticTimer, visible, running else { return }
        let next = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        next.tolerance = 0.1
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }
}
