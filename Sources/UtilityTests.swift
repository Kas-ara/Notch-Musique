import AppKit

func runUtilitySelfTests() -> Int {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        checks += 1
    }
    let start = Date(timeIntervalSince1970: 1_000_000)
    let focus = FocusModel(defaults: nil, automaticTimer: false)
    check(focus.time == "25:00" && focus.breakMinutes == 5 && !focus.started, "Default focus must be 25/5 and idle")
    focus.toggle(at: start)
    focus.tick(at: start.addingTimeInterval(60))
    check(focus.time == "24:00" && focus.running, "Running focus must follow its deadline")
    focus.toggle(at: start.addingTimeInterval(90))
    focus.tick(at: start.addingTimeInterval(900))
    check(focus.time == "23:30" && !focus.running && focus.started, "Pause must freeze remaining time")
    focus.toggle(at: start.addingTimeInterval(1000))
    focus.tick(at: start.addingTimeInterval(1001))
    check(focus.time == "23:29", "Resume must exclude paused time")
    focus.skip(at: start.addingTimeInterval(1002))
    check(focus.phase == .rest && focus.time == "05:00" && focus.running, "Skip must start the next phase while running")
    focus.tick(at: start.addingTimeInterval(1302))
    check(focus.phase == .focus && focus.time == "25:00", "Break must automatically return to focus")
    focus.reset()
    focus.toggle(at: start)
    focus.tick(at: start.addingTimeInterval(1500))
    check(focus.phase == .rest && focus.time == "05:00", "Focus must automatically enter break at its exact boundary")
    focus.tick(at: start.addingTimeInterval(1511))
    check(focus.phase == .rest && focus.time == "04:49", "Late callback must carry elapsed time into the next phase")
    focus.reset()
    focus.toggle(at: start)
    focus.setVisible(false, at: start)
    focus.setVisible(true, at: start.addingTimeInterval(1800 * 100 + 1507))
    check(focus.phase == .rest && focus.time == "04:53", "Long sleep must skip full cycles and preserve phase position")
    focus.toggle(at: start.addingTimeInterval(1800 * 100 + 1507))
    focus.skip(at: start.addingTimeInterval(1800 * 100 + 1600))
    check(focus.phase == .focus && focus.time == "25:00" && !focus.running, "Skip while paused must stay paused")
    focus.configure(work: 50, rest: 10)
    check(focus.workMinutes == 25, "Changing durations during a session must not discard it")
    focus.reset()
    focus.configure(work: 50, rest: 10)
    check(focus.time == "50:00" && focus.breakMinutes == 10 && !focus.started, "Alternative preset must reset idle duration")
    focus.configure(work: -2, rest: 200)
    check(focus.workMinutes == 1 && focus.breakMinutes == 60, "Durations must stay bounded")

    let countdown = CountdownModel(defaults: nil)
    check(!countdown.showsWhenIdle(playing: false, focusStarted: false, meeting: false), "No countdown until explicitly configured")
    check(!countdown.save(label: "  ", date: start), "Blank labels must be rejected")
    countdown.save(label: "  Vacances  ", date: start.addingTimeInterval(9 * 86400 + 3 * 3600 + 120))
    let remaining = countdown.remaining(at: start)
    check(countdown.target?.label == "Vacances" && remaining.weeks == 1 && remaining.days == 2 && remaining.hours == 3 && remaining.minutes == 2, "Countdown must trim label and decompose elapsed-duration weeks/days/hours/minutes")
    check(countdown.showsWhenIdle(playing: false, focusStarted: false, meeting: false), "Paused or closed Spotify must show configured countdown")
    check(!countdown.showsWhenIdle(playing: true, focusStarted: false, meeting: false), "Playing Spotify must retain media")
    check(!countdown.showsWhenIdle(playing: false, focusStarted: true, meeting: false) && !countdown.showsWhenIdle(playing: false, focusStarted: false, meeting: true), "Focus and meeting must retain priority")
    countdown.save(label: "Holiday", date: start.addingTimeInterval(1))
    check(countdown.remaining(at: start).minutes == 1 && !countdown.remaining(at: start).arrived, "A future target must not appear arrived when under one minute away")
    check(countdown.remaining(at: start.addingTimeInterval(1)).arrived && countdown.remaining(at: start.addingTimeInterval(100000)).weeks == 0, "Exact deadline and overdue targets must stop at zero")
    countdown.save(label: String(repeating: "a", count: 80), date: start)
    check(countdown.target?.label.count == 40, "Label length must stay bounded")
    let suiteName = "local.notchmusique.countdown-test.\(UUID().uuidString)"
    let isolated = UserDefaults(suiteName: suiteName)!
    defer { isolated.removePersistentDomain(forName: suiteName) }
    let savedCountdown = CountdownModel(defaults: isolated)
    savedCountdown.save(label: "Holiday", date: start)
    check(CountdownModel(defaults: isolated).target == savedCountdown.target, "Countdown must survive restart, including overdue targets")
    savedCountdown.clear()
    check(CountdownModel(defaults: isolated).target == nil, "Deleting a countdown must also remove its stored target")

    let layout = NotchLayout()
    layout.configure(notchWidth: 190, notchHeight: 32, margin: 3,
                     availableWidth: 1424, availableHeight: 876)
    check(layout.width == 304 && layout.height == 35, "Idle geometry must fit camera plus activity wings")
    check(layout.width - 2 * layout.wingWidth - 6 == layout.notchWidth, "Activity wings must not overlap the physical camera")
    check(layout.expandedWidth == 360 && layout.expandedHeight == 201, "Media panel must stay compact")
    layout.tab = .countdown
    check(layout.expandedWidth == 360 && layout.expandedHeight == 253, "Countdown editor must retain compact width and bounded height")
    layout.tab = .calendar
    check(layout.expandedHeight == 233, "Calendar must get only its bounded list height")
    layout.configure(notchWidth: 190, notchHeight: 32, margin: 3,
                     availableWidth: 320, availableHeight: 210)
    check(layout.expandedWidth <= 320 && layout.expandedHeight <= 210, "Expanded geometry must respect available screen bounds")
    return checks
}
