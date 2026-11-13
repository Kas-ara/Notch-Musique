import AppKit
import Combine
import ImageIO

final class SpotifyModel: ObservableObject {
    @Published var title = "Spotify"
    @Published var artist = "Lance un morceau pour commencer"
    @Published var artwork: NSImage?
    @Published var playing = false
    @Published var available = false
    @Published var message: String?
    private var duration: Double = 0
    private var position: Double = 0
    private var sampledAt = Date()
    private var timer: Timer?
    private var artworkURL = ""
    private var artworkTask: URLSessionDataTask?
    private var permissionDenied = false
    private var active = true
    private var spotifyRunning = false
    private var refreshing = false
    private var scripts: [String: NSAppleScript] = [:]
    private var playbackObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol] = []
    private lazy var artworkSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
    let demo: Bool

    init(demo: Bool) {
        self.demo = demo
        if demo {
            title = "Aperçu du lecteur"
            artist = "Simulation · aucune lecture Spotify"
            duration = 240
            position = 94
            playing = true
            available = true
        } else {
            // Signal présent dans le binaire Spotify installé. Optimisation
            // opportuniste : le polling de secours ne dépend pas de ce signal.
            playbackObserver = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main
            ) { [weak self] _ in self?.refresh() }
            let workspace = NSWorkspace.shared.notificationCenter
            for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
                workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                    if app?.bundleIdentifier == "com.spotify.client" { self?.refresh() }
                })
            }
            refresh()
        }
    }

    deinit {
        timer?.invalidate()
        artworkTask?.cancel()
        if let playbackObserver { DistributedNotificationCenter.default().removeObserver(playbackObserver) }
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    func setActive(_ value: Bool) {
        guard value != active else { return }
        active = value
        if value { refresh() } else {
            timer?.invalidate()
            timer = nil
            artworkTask?.cancel()
            artworkTask = nil
            if artwork == nil { artworkURL = "" }
        }
    }

    private func scheduleRefresh() {
        timer?.invalidate()
        timer = nil
        guard active, !demo, !permissionDenied, spotifyRunning else { return }
        // Synchronisation du seek si une notification est perdue ou non émise.
        let interval: TimeInterval = available && !playing ? 30 : 10
        let next = Timer(timeInterval: interval, repeats: false) { [weak self] _ in self?.refresh() }
        next.tolerance = 1
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsed(at: date) / duration))
    }

    func elapsed(at date: Date) -> Double {
        min(duration, max(0, position + (playing ? date.timeIntervalSince(sampledAt) : 0)))
    }

    func times(at date: Date) -> String {
        func format(_ value: Double) -> String {
            let seconds = Int(max(0, value))
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        return "\(format(elapsed(at: date))) / \(format(duration))"
    }

    private func execute(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let script: NSAppleScript
        if let cached = scripts[source] { script = cached }
        else {
            guard let compiled = NSAppleScript(source: source) else { return nil }
            scripts[source] = compiled
            script = compiled
        }
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
            permissionDenied = code == -1743
            message = permissionDenied
                ? "Autorise Spotify dans Réglages Système → Confidentialité et sécurité → Automatisation."
                : "Spotify ne répond pas. Nouvelle tentative automatique."
            if playing { playing = false }
            if available { available = false }
            return nil
        }
        if message != nil { message = nil }
        return result
    }

    func refresh() {
        guard !demo, active, !refreshing else { return }
        refreshing = true
        defer { refreshing = false; scheduleRefresh() }
        guard !permissionDenied else { return }
        spotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        guard spotifyRunning else {
            if title != "Spotify est fermé" { title = "Spotify est fermé" }
            if artist != "Ouvre Spotify pour afficher ta musique" { artist = "Ouvre Spotify pour afficher ta musique" }
            if playing { playing = false }
            if available { available = false }
            if artwork != nil { artwork = nil }
            artworkURL = ""
            artworkTask?.cancel()
            position = 0
            duration = 0
            if message != nil { message = nil }
            return
        }
        // Données séparées dans une liste Apple Event : aucun découpage du titre.
        let source = """
        with timeout of 1 seconds
            tell application id "com.spotify.client"
                if player state is stopped then return {"stopped"}
                set t to current track
                return {(player state as text), (name of t), (artist of t), (duration of t), player position, (artwork url of t)}
            end tell
        end timeout
        """
        guard let result = execute(source) else { return }
        guard result.numberOfItems == 6 else {
            if playing { playing = false }
            if available { available = false }
            if title != "Aucun morceau" { title = "Aucun morceau" }
            if artist != "Choisis une musique dans Spotify" { artist = "Choisis une musique dans Spotify" }
            duration = 0
            position = 0
            if artwork != nil { artwork = nil }
            artworkURL = ""
            artworkTask?.cancel()
            return
        }
        let newTitle = result.atIndex(2)?.stringValue ?? "Titre inconnu"
        let newArtist = result.atIndex(3)?.stringValue ?? ""
        let newPlaying = result.atIndex(1)?.stringValue == "playing"
        let newPosition = result.atIndex(5)?.doubleValue ?? 0
        // Le seek en pause doit redessiner la vue même sans horloge active.
        if !newPlaying && abs(newPosition - elapsed(at: Date())) > 0.1 { objectWillChange.send() }
        if title != newTitle { title = newTitle }
        if artist != newArtist { artist = newArtist }
        duration = (result.atIndex(4)?.doubleValue ?? 0) / 1000
        position = newPosition
        sampledAt = Date()
        if playing != newPlaying { playing = newPlaying }
        if !available { available = true }
        loadArtwork(result.atIndex(6)?.stringValue ?? "")
    }

    private func loadArtwork(_ value: String) {
        guard value != artworkURL else { return }
        artworkURL = value
        artwork = nil
        artworkTask?.cancel()
        guard let url = URL(string: value), url.scheme == "https" else { return }
        artworkTask = artworkSession.dataTask(with: url) { [weak self] data, _, _ in
            let thumbnail = data.flatMap { Self.thumbnail(data: $0) }
            DispatchQueue.main.async {
                guard let self, self.artworkURL == value else { return }
                self.artworkTask = nil
                self.artwork = thumbnail.map { NSImage(cgImage: $0, size: NSSize(width: 46, height: 46)) }
            }
        }
        artworkTask?.resume()
    }

    static func thumbnail(data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 128,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }

    func retry() {
        permissionDenied = false
        refresh()
    }

    func command(_ command: Command) {
        guard available else { return }
        if demo {
            if command == .playpause {
                position = elapsed(at: Date())
                sampledAt = Date()
                playing.toggle()
            }
            return
        }
        guard execute("""
        with timeout of 1 seconds
            tell application id "com.spotify.client" to \(command.rawValue)
        end timeout
        """) != nil else { return }
        refresh()
    }

    enum Command: String {
        case previous = "previous track"
        case playpause = "playpause"
        case next = "next track"
    }
}
