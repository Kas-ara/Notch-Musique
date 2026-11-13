import AppKit
import SwiftUI
import ImageIO
import ServiceManagement

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class HoverHostingView: NSHostingView<NotchView> {
    var hoverChanged: ((Bool) -> Void)?
    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero,
                                 options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
                                 owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { hoverChanged?(true) }
    override func mouseExited(with event: NSEvent) { hoverChanged?(false) }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var panel: NotchPanel!
    private var statusItem: NSStatusItem!
    private var model: SpotifyModel!
    private let layout = NotchLayout()
    private let appearance = Appearance()
    private var settingsWindow: NSWindow?
    private var transitionID = 0
    private var screen: NSScreen?
    private var centerX: CGFloat = 0
    private var topY: CGFloat = 0
    private var collapseTask: DispatchWorkItem?
    private var displaySleeping = false
    private var hoverFallback: Timer?
    private var exportingScreenshots = false
    private var suspended = false
    private let demo = CommandLine.arguments.contains("--demo")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Évite deux overlays superposés lors d’un second lancement.
        let peers = NSRunningApplication.runningApplications(withBundleIdentifier: "local.notchmusique.app")
        if peers.contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        model = SpotifyModel(demo: demo)
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.isReleasedWhenClosed = false
        appearance.geometryChanged = { [weak self] in self?.positionOnScreen() }
        let hostingView = HoverHostingView(rootView: NotchView(model: model, layout: layout, appearance: appearance))
        hostingView.hoverChanged = { [weak self] inside in
            guard let self else { return }
            self.collapseTask?.cancel()
            guard !self.suspended, !self.displaySleeping, !self.exportingScreenshots else { return }
            if inside {
                self.setExpanded(true)
            } else {
                let task = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.collapseTask = nil
                    // Une seule lecture à la sortie évite un faux repli pendant le zoom.
                    if !self.panel.frame.contains(NSEvent.mouseLocation) { self.setExpanded(false) }
                }
                self.collapseTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: task)
            }
        }
        layout.hoverChanged = hostingView.hoverChanged
        panel.contentView = hostingView
        configureMenu()
        positionOnScreen()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(displayDidSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(displayDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hoverFallback?.invalidate()
        collapseTask?.cancel()
    }

    private func checkPointer() {
        guard panel.isVisible, layout.renderActive else { return }
        let width = layout.expanded ? layout.expandedWidth : layout.width
        let height = layout.expanded ? layout.expandedHeight : layout.height
        let frame = NSRect(x: centerX - width / 2, y: topY - height, width: width, height: height)
        let inside = frame.contains(NSEvent.mouseLocation)
        if inside {
            collapseTask?.cancel()
            collapseTask = nil
            setExpanded(true)
        } else if layout.expanded && collapseTask == nil {
            layout.hoverChanged?(false)
        }
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Notch Musique")
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: demo ? "Notch Musique · Simulation" : "Notch Musique · Spotify", action: nil, keyEquivalent: "")
        menu.addItem(title)
        menu.addItem(.separator())
        add(menu, "Ouvrir Spotify", action: #selector(openSpotify))
        add(menu, "Réessayer la connexion Spotify", action: #selector(retry))
        add(menu, "Apparence…", action: #selector(showAppearance), key: ",")
        add(menu, "Démarrer avec le système", action: #selector(toggleLaunchAtLogin))
        add(menu, "Masquer le contour", action: #selector(toggleVisible))
        menu.addItem(.separator())
        add(menu, "Quitter Notch Musique", action: #selector(quit), key: "q")
        statusItem.menu = menu
        // Un menu d’application natif rend les raccourcis et l’accès clavier
        // aux réglages disponibles, même pour une application sans Dock.
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "Notch Musique", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "Notch Musique")
        add(appMenu, "Apparence…", action: #selector(showAppearance), key: ",")
        add(appMenu, "Exporter des captures…", action: #selector(exportScreenshots))
        appMenu.addItem(.separator())
        add(appMenu, "Quitter Notch Musique", action: #selector(quit), key: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    private func add(_ menu: NSMenu, _ title: String, action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let status = SMAppService.mainApp.status
        for item in menu.items where item.action == #selector(toggleLaunchAtLogin) {
            item.state = status == .enabled ? .on : (status == .requiresApproval ? .mixed : .off)
            item.title = status == .requiresApproval
                ? "Démarrer avec le système (autorisation requise…)"
                : "Démarrer avec le système"
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                showLoginApproval()
                return
            default:
                try service.register()
            }
            if service.status == .requiresApproval { showLoginApproval() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Impossible de modifier le démarrage automatique"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    private func showLoginApproval() {
        let alert = NSAlert()
        alert.messageText = "Autoriser le démarrage automatique"
        alert.informativeText = "Activez Notch Musique dans Réglages Système → Général → Ouverture. Vous pouvez aussi y désactiver le démarrage automatique."
        alert.addButton(withTitle: "Ouvrir les réglages")
        alert.addButton(withTitle: "Plus tard")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func positionOnScreen() {
        // Ne dessine pas de fausse encoche sur les écrans externes.
        screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
        guard let screen,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            panel.orderOut(nil)
            setActivity(false)
            statusItem.button?.toolTip = "Aucun écran avec encoche détecté"
            return
        }
        let notchWidth = right.minX - left.maxX
        guard notchWidth > 0 else { panel.orderOut(nil); setActivity(false); return }
        centerX = (left.maxX + right.minX) / 2
        topY = screen.frame.maxY
        layout.width = notchWidth + appearance.margin * 2
        layout.height = screen.safeAreaInsets.top + appearance.margin
        resize()
        if !suspended { panel.orderFrontRegardless() }
        setActivity(!suspended && !displaySleeping)
    }

    private func resize() {
        let width = layout.expanded ? layout.expandedWidth : layout.width
        let height = layout.expanded ? layout.expandedHeight : layout.height
        panel.setFrame(NSRect(x: centerX - width / 2, y: topY - height, width: width, height: height), display: true)
    }

    private func setExpanded(_ expanded: Bool) {
        guard expanded != layout.expanded else { return }
        transitionID += 1
        let currentTransition = transitionID
        if expanded {
            // La fenêtre est agrandie avant le dessin pour ne pas couper le zoom.
            panel.setFrame(NSRect(x: centerX - layout.expandedWidth / 2,
                                  y: topY - layout.expandedHeight,
                                  width: layout.expandedWidth, height: layout.expandedHeight), display: true)
            layout.expanded = true
        } else {
            layout.expanded = false
            // Le cadre transparent reste disponible jusqu’à la fin du repli.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self, self.transitionID == currentTransition, !self.layout.expanded else { return }
                self.resize()
            }
        }
    }

    private func setActivity(_ active: Bool) {
        if layout.renderActive != active { layout.renderActive = active }
        model.setActive(active)
        if active && hoverFallback == nil {
            // Secours tolérant pour les événements manqués autour du notch.
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.checkPointer() }
            timer.tolerance = 0.05
            RunLoop.main.add(timer, forMode: .common)
            hoverFallback = timer
        } else if !active {
            hoverFallback?.invalidate()
            hoverFallback = nil
        }
    }

    @objc private func displayDidSleep() {
        displaySleeping = true
        collapseTask?.cancel()
        layout.expanded = false
        setActivity(false)
        panel.orderOut(nil)
    }
    @objc private func displayDidWake() { displaySleeping = false; positionOnScreen() }

    @objc private func screenChanged() { layout.expanded = false; positionOnScreen() }
    @objc private func openSpotify() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    @objc private func retry() { model.retry() }
    @objc private func exportScreenshots() {
        let picker = NSOpenPanel()
        picker.title = "Exporter les captures de Notch Musique"
        picker.prompt = "Exporter ici"
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        picker.begin { [weak self] response in
            guard response == .OK, let folder = picker.url, let self else { return }
            self.writeScreenshots(to: folder)
        }
    }

    private func writeScreenshots(to folder: URL) {
        guard panel.isVisible else { return }
        exportingScreenshots = true
        collapseTask?.cancel()
        let wasExpanded = layout.expanded
        let settingsWereVisible = settingsWindow?.isVisible == true
        var failures: [String] = []
        func save(_ view: NSView?, name: String) {
            guard let view,
                  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                failures.append(name); return
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                failures.append(name); return
            }
            do { try png.write(to: folder.appendingPathComponent(name), options: .atomic) }
            catch { failures.append(name) }
        }
        setExpanded(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            save(panel.contentView, name: "contour.png")
            setExpanded(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
                save(panel.contentView, name: "lecteur.png")
                showAppearance()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                    save(settingsWindow?.contentView, name: "apparence.png")
                    if !settingsWereVisible { settingsWindow?.close() }
                    setExpanded(wasExpanded)
                    exportingScreenshots = false
                    if failures.isEmpty {
                        statusItem.button?.toolTip = "Captures exportées dans \(folder.lastPathComponent)"
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "Export incomplet"
                        alert.informativeText = "Impossible d’enregistrer : " + failures.joined(separator: ", ")
                        alert.runModal()
                    }
                }
            }
        }
    }
    @objc private func showAppearance() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Notch Musique — Apparence"
            window.isReleasedWhenClosed = false
            window.delegate = self
            let host = NSHostingView(rootView: AppearanceView(appearance: appearance))
            window.contentView = host
            window.setContentSize(host.fittingSize)
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        // Libère la hiérarchie SwiftUI au lieu de la garder après fermeture.
        window.contentView = nil
        settingsWindow = nil
    }
    @objc private func toggleVisible(_ sender: NSMenuItem) {
        suspended.toggle()
        sender.title = suspended ? "Afficher le contour" : "Masquer le contour"
        layout.expanded = false
        collapseTask?.cancel()
        if suspended { panel.orderOut(nil); setActivity(false) } else { positionOnScreen() }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

if CommandLine.arguments.contains("--self-test") {
    let model = SpotifyModel(demo: true)
    let now = Date()
    precondition(abs(model.progress(at: now) - 94.0 / 240) < 0.01, "Progression initiale incorrecte")
    precondition(model.progress(at: now.addingTimeInterval(500)) == 1, "Fin de titre non bornée")
    precondition(model.progress(at: now.addingTimeInterval(-500)) == 0, "Position négative non bornée")
    model.command(.playpause)
    precondition(!model.playing, "Pause non appliquée")
    precondition(model.progress(at: now) == model.progress(at: now.addingTimeInterval(60)), "La progression doit rester figée en pause")
    model.command(.playpause)
    precondition(model.playing, "Reprise non appliquée")
    precondition(model.times(at: now).hasSuffix("/ 4:00"), "Durée incorrecte")
    // Vérifie la mémoire des pochettes sans réseau ni accès à Spotify.
    let bitmap = CGContext(data: nil, width: 1024, height: 512, bitsPerComponent: 8,
                           bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let png = NSMutableData()
    let destination = CGImageDestinationCreateWithData(png, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, bitmap.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination), "Encodage de la fixture impossible")
    let thumbnail = SpotifyModel.thumbnail(data: png as Data)
    precondition(thumbnail?.width == 128 && thumbnail?.height == 64, "La pochette doit être réduite en conservant ses proportions")
    precondition(SpotifyModel.thumbnail(data: Data([0, 1, 2])) == nil, "Une pochette invalide doit être ignorée")
    print("10 vérifications réussies : lecture en simulation, réduction des pochettes et données invalides.")
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
