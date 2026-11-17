import SwiftUI

// The SDK also exports a State macro whose plug-in is absent from Command Line Tools.
// Name the existing property-wrapper type explicitly to keep the macOS 13 build independent of it.
private typealias ViewState<Value> = SwiftUI.State<Value>

final class NotchLayout: ObservableObject {
    enum Tab: String, CaseIterable {
        case media = "Média", calendar = "Calendrier", focus = "Focus", countdown = "Compte à rebours"
        var symbol: String {
            switch self { case .media: return "music.note"; case .calendar: return "calendar"; case .focus: return "timer"; case .countdown: return "hourglass" }
        }
    }
    @Published var expanded = false
    @Published var pinned = false
    @Published var tab: Tab = .media { didSet { if tab != oldValue { geometryChanged?() } } }
    @Published var width: CGFloat = 302
    @Published var height: CGFloat = 34
    @Published var notchWidth: CGFloat = 190
    @Published var notchHeight: CGFloat = 32
    @Published var availableWidth: CGFloat = 400
    @Published var availableHeight: CGFloat = 700
    @Published var renderActive = true
    let wingWidth: CGFloat = 54
    var expandedWidth: CGFloat { min(availableWidth, max(360, width)) }
    var contentHeight: CGFloat { tab == .countdown ? 218 : (tab == .calendar ? 198 : 166) }
    var expandedHeight: CGFloat { min(availableHeight, height + contentHeight) }
    var hoverChanged: ((Bool) -> Void)?
    var geometryChanged: (() -> Void)?

    func configure(notchWidth: CGFloat, notchHeight: CGFloat, margin: CGFloat,
                   availableWidth: CGFloat, availableHeight: CGFloat) {
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        width = min(availableWidth, notchWidth + 2 * (wingWidth + margin))
        height = notchHeight + margin
    }
}

struct NotchContour: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(10.0, rect.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - r), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

struct NotchView: View {
    @ObservedObject var model: SpotifyModel
    @ObservedObject var focus: FocusModel
    @ObservedObject var calendar: CalendarModel
    @ObservedObject var countdown: CountdownModel
    @ObservedObject var layout: NotchLayout
    @ObservedObject var appearance: Appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var countdownLabel = ""
    @ViewState private var countdownDate = Date().addingTimeInterval(86400)
    @ViewState private var seeking = false
    @ViewState private var seekPosition = 0.0
    private var accent: Color { focus.started ? .purple : appearance.color }
    private var visualWidth: CGFloat { layout.expanded ? layout.expandedWidth : layout.width }
    private var visualHeight: CGFloat { layout.expanded ? layout.expandedHeight : layout.height }

    private var showCountdown: Bool {
        countdown.showsWhenIdle(playing: model.playing, focusStarted: focus.started, meeting: calendar.nextMeeting != nil)
    }
    @ViewBuilder private func countdownClock<Content: View>(@ViewBuilder content: @escaping (Date) -> Content) -> some View {
        if layout.renderActive {
            TimelineView(.periodic(from: .now, by: 1)) { context in content(context.date) }
        } else { content(.now) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if model.playing && layout.renderActive && !focus.started {
                    TimelineView(.periodic(from: .now, by: layout.expanded ? 1 : 0.5)) { context in contour(at: context.date) }
                } else { contour(at: .now) }
            }
            .frame(width: visualWidth, height: visualHeight)

            glance
                .frame(width: layout.width, height: layout.notchHeight)
            if layout.expanded {
                VStack(spacing: 10) {
                    tabs
                    Group {
                        switch layout.tab {
                        case .media:
                            if showCountdown { countdownSummary } else { media }
                        case .calendar: agenda
                        case .focus: focusPanel
                        case .countdown: countdownPanel
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, 16)
                .padding(.top, 7)
                .padding(.bottom, 14)
                .frame(width: layout.expandedWidth, height: layout.expandedHeight - layout.height)
                .padding(.top, layout.height)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onHover { layout.hoverChanged?($0) }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.9), value: layout.expanded)
    }

    private var glance: some View {
        HStack(spacing: 0) {
            Group {
                if focus.started {
                    Image(systemName: focus.phase.symbol).foregroundStyle(.purple)
                } else if calendar.nextMeeting != nil {
                    Image(systemName: "calendar").foregroundStyle(.blue)
                } else if showCountdown {
                    Image(systemName: "heart.fill").foregroundStyle(appearance.color)
                } else { artwork(size: min(26, layout.notchHeight - 4)) }
            }
            .frame(width: layout.wingWidth)
            // This gap is the measured physical camera area, never a hard-coded model width.
            Spacer(minLength: layout.notchWidth)
            Group {
                if focus.started {
                    Text(focus.time).font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.purple)
                } else if let event = calendar.nextMeeting {
                    Text(event.start, style: .time).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.blue).lineLimit(1)
                } else if showCountdown {
                    countdownClock { date in
                        Text(countdown.remaining(at: date).compact)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .multilineTextAlignment(.center).foregroundStyle(appearance.color)
                    }
                } else {
                    Image(systemName: model.playing ? "waveform" : "pause.fill")
                        .font(.system(size: 14)).foregroundStyle(appearance.color.opacity(model.available ? 1 : 0.4))
                }
            }
            .frame(width: layout.wingWidth)
        }
        .padding(.horizontal, appearance.margin)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(focus.started ? "\(focus.phase.title), \(focus.time)\(focus.running ? "" : ", en pause")" : (calendar.nextMeeting.map { "Prochain événement : \($0.title)" } ?? (showCountdown ? "\(countdown.target?.label ?? ""), \(countdown.remaining(at: .now).full)" : "\(model.title), \(model.artist)" )))
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(NotchLayout.Tab.allCases, id: \.self) { tab in
                Button {
                    layout.tab = tab
                    if tab == .calendar { calendar.refresh() }
                } label: {
                    Group {
                        if tab == .countdown { Image(systemName: tab.symbol) }
                        else { Label(tab.rawValue, systemImage: tab.symbol) }
                    }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6).frame(height: 26)
                        .background(layout.tab == tab ? Color.white.opacity(0.14) : .clear, in: Capsule())
                }.buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .help(tab.rawValue)
                .accessibilityAddTraits(layout.tab == tab ? .isSelected : [])
            }
            Spacer(minLength: 0)
            Button { layout.pinned.toggle() } label: {
                Image(systemName: layout.pinned ? "pin.fill" : "pin").font(.system(size: 11)).frame(width: 24, height: 26)
            }.buttonStyle(.plain)
                .foregroundStyle(layout.pinned ? appearance.color : .white.opacity(0.5))
                .help(layout.pinned ? "Détacher le panneau" : "Garder le panneau ouvert")
                .accessibilityLabel(layout.pinned ? "Détacher le panneau" : "Garder le panneau ouvert")
        }
    }

    private func artwork(size: CGFloat) -> some View {
        Group {
            if let artwork = model.artwork { Image(nsImage: artwork).resizable().scaledToFill() }
            else {
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "music.note").foregroundStyle(appearance.color)
                }
            }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size > 30 ? 7 : 5))
    }

    private var media: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                artwork(size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(model.artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if let message = model.message {
                Text(message).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(3)
            } else {
                HStack(spacing: 13) {
                    Group {
                        if model.playing && layout.renderActive {
                            TimelineView(.periodic(from: .now, by: 1)) { context in Text(model.times(at: context.date)) }
                        } else { Text(model.times(at: .now)) }
                    }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    Spacer(minLength: 0)
                    mediaControl("backward.end.fill", label: "Morceau précédent", command: .previous)
                    mediaControl(model.playing ? "pause.fill" : "play.fill", label: model.playing ? "Pause" : "Lecture", command: .playpause)
                    mediaControl("forward.end.fill", label: "Morceau suivant", command: .next)
                }
                if model.playing && layout.renderActive {
                    TimelineView(.periodic(from: .now, by: 1)) { context in seekBar(at: context.date) }
                } else { seekBar(at: .now) }
            }
        }.tint(appearance.color)
    }

    private func seekBar(at date: Date) -> some View {
        Slider(value: Binding(get: { seeking ? seekPosition : model.progress(at: date) },
                              set: { value in
                                  seekPosition = value
                                  // Keyboard/accessibility edits do not necessarily enter a drag session.
                                  if !seeking { model.seek(to: value) }
                              }), in: 0...1, onEditingChanged: { editing in
            if editing { seekPosition = model.progress(at: Date()) }
            else { model.seek(to: seekPosition) }
            seeking = editing
        })
        .controlSize(.mini).disabled(!model.available)
        .accessibilityLabel("Position de lecture")
    }

    private var countdownSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(countdown.target?.label ?? "Compte à rebours", systemImage: "heart.fill")
                .font(.system(size: 14, weight: .medium)).lineLimit(1)
            countdownClock { date in
                Text(countdown.remaining(at: date).full)
                    .font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            if let target = countdown.target {
                Text(target.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Button("Modifier…") { layout.tab = .countdown; layout.pinned = true }
                .font(.system(size: 11))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var countdownPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ex. Vacances", text: $countdownLabel)
                .textFieldStyle(.roundedBorder).font(.system(size: 12))
                .accessibilityLabel("Nom du compte à rebours")
                .onChange(of: countdownLabel) { value in
                    if value.count > 40 { countdownLabel = String(value.prefix(40)) }
                }
                .onTapGesture { layout.pinned = true }
            DatePicker("Objectif", selection: $countdownDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.field).font(.system(size: 11))
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .onTapGesture { layout.pinned = true }
            if countdown.target != nil {
                countdownClock { date in
                    Text(countdown.remaining(at: date).full)
                        .font(.system(size: 12, weight: .medium)).monospacedDigit()
                }
            } else {
                Text("Affiché lorsque Spotify ne joue pas.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack {
                Button("Enregistrer") {
                    if countdown.save(label: countdownLabel, date: countdownDate) { layout.tab = .media }
                }.disabled(countdownLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || countdownDate <= Date())
                if countdown.target != nil {
                    Button("Supprimer") { countdown.clear() }
                }
            }.font(.system(size: 11))
        }
        .onAppear {
            countdownLabel = countdown.target?.label ?? ""
            countdownDate = countdown.target?.date ?? Date().addingTimeInterval(86400)
            layout.pinned = true
        }
    }

    private var focusPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Label(focus.phase.title, systemImage: focus.phase.symbol)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.purple)
                if focus.started && !focus.running { Text("En pause").font(.system(size: 10)).foregroundStyle(.secondary) }
                Spacer()
                Text(focus.time).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            ProgressView(value: focus.progress).tint(.purple)
            HStack(spacing: 6) {
                utilityButton(focus.running ? "Pause" : (focus.started ? "Reprendre" : "Démarrer"), symbol: focus.running ? "pause.fill" : "play.fill") { focus.toggle() }
                utilityButton(focus.phase == .focus ? "À la pause" : "Au focus", symbol: "forward.end.fill") { focus.skip() }
                Button { focus.reset() } label: { Image(systemName: "arrow.counterclockwise").frame(width: 27, height: 26) }
                    .buttonStyle(.plain).accessibilityLabel("Réinitialiser le focus").help("Réinitialiser")
            }
            HStack(spacing: 7) {
                ForEach([15, 25, 50], id: \.self) { minutes in
                    let rest = minutes == 50 ? 10 : 5
                    Button("\(minutes)/\(rest)") { focus.configure(work: minutes, rest: rest) }
                        .buttonStyle(.plain).font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(focus.workMinutes == minutes && focus.breakMinutes == rest ? Color.purple.opacity(0.25) : Color.white.opacity(0.07), in: Capsule())
                }
                Menu {
                    Section("Focus") {
                        ForEach([10, 15, 20, 25, 30, 45, 50, 60, 90], id: \.self) { value in
                            Button("\(value) min") { focus.configure(work: value, rest: focus.breakMinutes) }
                        }
                    }
                    Section("Pause") {
                        ForEach([3, 5, 10, 15, 20], id: \.self) { value in
                            Button("\(value) min") { focus.configure(work: focus.workMinutes, rest: value) }
                        }
                    }
                } label: { Text("Durées…").font(.system(size: 10)) }
                .menuStyle(.borderlessButton).fixedSize()
                Spacer(minLength: 0)
                Text("\(focus.workMinutes)/\(focus.breakMinutes) min").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .disabled(focus.started)
            .help(focus.started ? "Réinitialisez la session pour changer les durées" : "Durée du focus / de la pause")
        }
    }

    @ViewBuilder private var agenda: some View {
        switch calendar.access {
        case .ready:
            if calendar.events.isEmpty {
                calendarMessage("Aucun événement dans les 7 prochains jours.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(calendar.events) { event in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: event.color)).frame(width: 3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                    Text(event.subtitle()).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }.frame(height: 34)
                        }
                    }
                }
                .accessibilityLabel(calendar.demo ? "Calendrier de démonstration" : "Événements des 7 prochains jours")
            }
        case .loading:
            HStack { ProgressView().controlSize(.small); Text("Chargement du calendrier…").font(.system(size: 11)) }
        case .unrequested:
            VStack(alignment: .leading, spacing: 8) {
                calendarMessage("Les prochains événements des calendriers configurés sur ce Mac, avec votre autorisation.")
                Button("Connecter le calendrier") { layout.pinned = true; calendar.connect() }
                    .font(.system(size: 11))
            }
        case .denied, .restricted:
            VStack(alignment: .leading, spacing: 8) {
                calendarMessage(calendar.access == .restricted ? "L’accès au calendrier est restreint sur ce Mac." : "Autorisez Notch Musique dans Confidentialité et sécurité → Calendriers.")
                Button("Réglages Calendriers") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") { NSWorkspace.shared.open(url) }
                }.font(.system(size: 11))
                Button("Réessayer") { calendar.refresh() }.font(.system(size: 11))
            }
        case .failed:
            VStack(alignment: .leading, spacing: 8) {
                calendarMessage(calendar.errorMessage ?? "Connexion au calendrier impossible.")
                Button("Réessayer") { calendar.connect() }.font(.system(size: 11))
            }
        }
    }
    private func calendarMessage(_ message: String) -> some View {
        Text(message).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    private func utilityButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 9).frame(height: 26)
                .background(Color.white.opacity(0.1), in: Capsule())
        }.buttonStyle(.plain)
    }
    private func mediaControl(_ symbol: String, label: String, command: SpotifyModel.Command) -> some View {
        Button { model.command(command) } label: {
            Image(systemName: symbol).font(.system(size: 12)).frame(width: 25, height: 26).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!model.available).help(label).accessibilityLabel(label)
    }
    private func contour(at date: Date) -> some View {
        ZStack {
            NotchBackground().fill(.black)
            NotchContour().stroke(.white.opacity(0.12), lineWidth: 1)
            NotchContour().trim(from: 0, to: focus.started ? focus.progress : (showCountdown ? 0 : model.progress(at: date)))
                .stroke(accent.opacity(focus.started || model.playing ? 0.85 : 0.32), style: StrokeStyle(lineWidth: appearance.thickness, lineCap: .round))
        }
        .padding(.horizontal, appearance.thickness / 2 + 0.5)
        .padding(.bottom, appearance.thickness / 2 + 0.5)
    }
}

struct NotchBackground: Shape {
    func path(in rect: CGRect) -> Path {
        var p = NotchContour().path(in: rect)
        p.closeSubpath()
        return p
    }
}
