import AppKit

final class PairBox: NSObject {
    let pair: FavoritePair
    init(_ pair: FavoritePair) { self.pair = pair }
}

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate, @unchecked Sendable {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var settings: SettingsWindowController?
    private var projects: [MiteProject] = []
    private var services: [MiteService] = []
    private var catalogLoaded = false
    private var tracker: TrackerSnapshot?
    private var trackerEpoch = 0
    private var isBusy = false
    private var tick: Timer?
    private var poll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.autoenablesItems = false
        menu.delegate = self
        if let button = statusItem.button {
            let symbol = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            if let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "mite")?.withSymbolConfiguration(symbol) {
                image.isTemplate = true
                button.image = image
            }
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.toolTip = "mite"
        }
        statusItem.menu = menu
        updateStatusItem()
        refreshCatalog()
        refreshTracker()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshTracker()
        }
        RunLoop.main.add(timer, forMode: .common)
        poll = timer
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let config: AppConfig
        do {
            config = try FavoritesStore.load()
        } catch {
            menu.addItem(disabled("Config file could not be read"))
            menu.addItem(disabled(error.localizedDescription))
            addFooter(connected: false)
            return
        }

        let connected = !config.account.isEmpty && Keychain.load() != nil
        if let tracker {
            if !tracker.headline.isEmpty {
                menu.addItem(disabled(tracker.headline))
            }
            if !tracker.note.isEmpty {
                menu.addItem(disabled(tracker.note))
            }
            let stop = NSMenuItem(title: "Stop", action: #selector(stopTimer), keyEquivalent: "")
            stop.target = self
            stop.isEnabled = !isBusy
            menu.addItem(stop)
            menu.addItem(.separator())
        }

        if config.pairs.isEmpty {
            menu.addItem(disabled(connected ? "No pairs yet" : "Not connected"))
        } else {
            for pair in config.pairs {
                let title = menuTitle(for: pair)
                let available = isPairAvailable(pair)
                let item = NSMenuItem(title: available ? title : "\(title) (unavailable)", action: #selector(startPair(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = PairBox(pair)
                item.isEnabled = !isBusy && available
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        addFooter(connected: connected)
    }

    private func addFooter(connected: Bool) {
        let connect = NSMenuItem(
            title: connected ? "Add pair…" : "Connect…",
            action: #selector(showSettings),
            keyEquivalent: ""
        )
        connect.target = self
        menu.addItem(connect)

        let open = NSMenuItem(title: "Open config", action: #selector(openConfig), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func menuTitle(for pair: FavoritePair) -> String {
        let title = pair.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "(untitled)" : title
    }

    private func isPairAvailable(_ pair: FavoritePair) -> Bool {
        guard catalogLoaded else { return true }
        let projectOk = projects.contains { $0.id == pair.projectId }
        let serviceOk = services.contains { $0.id == pair.serviceId }
        return projectOk && serviceOk
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func showSettings() {
        if settings == nil {
            let controller = SettingsWindowController()
            controller.onCatalogUpdated = { [weak self] projects, services in
                self?.applyCatalog(projects: projects, services: services)
            }
            settings = controller
        }
        settings?.show(projects: projects, services: services)
    }

    @objc private func openConfig() {
        do {
            try FavoritesStore.ensureFile()
            NSWorkspace.shared.activateFileViewerSelecting([FavoritesStore.fileURL])
        } catch {
            presentError(error)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func startPair(_ sender: NSMenuItem) {
        guard !isBusy, let box = sender.representedObject as? PairBox else { return }
        let client: MiteClient
        do {
            client = try MiteClient.make()
        } catch {
            presentError(error)
            return
        }
        guard let note = NotePrompt.ask(title: menuTitle(for: box.pair)) else { return }
        let pair = box.pair
        beginTrackingChange()
        Task {
            do {
                let snapshot = try await client.start(
                    projectId: pair.projectId,
                    serviceId: pair.serviceId,
                    note: note,
                    headline: self.menuTitle(for: pair)
                )
                DispatchQueue.main.async {
                    self.tracker = snapshot
                    self.isBusy = false
                    self.updateStatusItem()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.updateStatusItem()
                    self.presentError(error)
                    self.refreshTracker()
                }
            }
        }
    }

    @objc private func stopTimer() {
        guard !isBusy, let entryId = tracker?.entryId else { return }
        let client: MiteClient
        do {
            client = try MiteClient.make()
        } catch {
            presentError(error)
            return
        }
        beginTrackingChange()
        Task {
            do {
                try await client.stop(entryId: entryId)
                DispatchQueue.main.async {
                    self.tracker = nil
                    self.isBusy = false
                    self.updateStatusItem()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.updateStatusItem()
                    self.presentError(error)
                    self.refreshTracker()
                }
            }
        }
    }

    private func refreshCatalog() {
        let client: MiteClient
        do {
            client = try MiteClient.make()
        } catch {
            return
        }
        Task {
            do {
                async let projects = client.projects()
                async let services = client.services()
                let loaded = try await (projects, services)
                DispatchQueue.main.async {
                    self.applyCatalog(projects: loaded.0, services: loaded.1)
                }
            } catch {
                return
            }
        }
    }

    private func applyCatalog(projects: [MiteProject], services: [MiteService]) {
        self.projects = projects
        self.services = services
        catalogLoaded = true
        settings?.updateCatalog(projects: projects, services: services)
    }

    private func beginTrackingChange() {
        trackerEpoch += 1
        isBusy = true
        updateStatusItem()
    }

    private func refreshTracker() {
        guard !isBusy else { return }
        let epoch = trackerEpoch
        let client: MiteClient
        do {
            client = try MiteClient.make()
        } catch {
            return
        }
        Task {
            do {
                let snapshot = try await client.currentTracker()
                DispatchQueue.main.async {
                    guard !self.isBusy, epoch == self.trackerEpoch else { return }
                    self.tracker = snapshot
                    self.updateStatusItem()
                }
            } catch {
                return
            }
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        if isBusy {
            button.title = " …"
            return
        }
        guard let tracker else {
            button.title = button.image == nil ? "mite" : ""
            button.toolTip = "mite"
            tick?.invalidate()
            tick = nil
            return
        }
        button.title = " " + formatElapsed(since: tracker.since)
        let detail = [tracker.headline, tracker.note].filter { !$0.isEmpty }.joined(separator: "\n")
        button.toolTip = detail.isEmpty ? "mite" : detail
        guard tick == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatusItem()
        }
        RunLoop.main.add(timer, forMode: .common)
        tick = timer
    }

    private func presentError(_ error: Error) {
        activateApp()
        let alert = NSAlert()
        alert.messageText = "mite menu"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.window.level = .floating
        alert.runModal()
    }
}

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
