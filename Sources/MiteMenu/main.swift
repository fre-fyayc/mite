import AppKit

final class PairBox: NSObject {
    let pair: FavoritePair
    init(_ pair: FavoritePair) { self.pair = pair }
}

final class EntryBox: NSObject {
    let entry: TodayEntry
    init(_ entry: TodayEntry) { self.entry = entry }
}

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate, @unchecked Sendable {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var settings: SettingsWindowController?
    private var projects: [MiteProject] = []
    private var services: [MiteService] = []
    private var catalogLoaded = false
    private var keyIsStored = false
    private var tracker: TrackerSnapshot?
    private var trackerEpoch = 0
    private var todayEntries: [TodayEntry] = []
    private var todayLoaded = false
    private var todayError: String?
    private var todayEpoch = 0
    private var workday: Workday?
    private var pastDay: String?
    private var pastEntries: [TodayEntry] = []
    private var pastLoaded = false
    private var pastError: String?
    private var pastEpoch = 0
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
        workday = WorkdayStore.load()
        updateStatusItem()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        DispatchQueue.main.async { [weak self] in
            self?.warmCredentials(refreshTrackerIfNeeded: true)
        }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.normalizeWorkdayClock()
            self?.refreshTracker()
            self?.updateStatusItem()
        }
        RunLoop.main.add(timer, forMode: .common)
        poll = timer
    }

    func menuWillOpen(_ menu: NSMenu) {
        normalizeWorkdayClock()
        rebuildMenu()
        refreshToday()
        refreshPastEntries()
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

        let connected = !config.account.isEmpty && keyIsStored
        addWorkday(config: config, connected: connected)
        if let tracker {
            if !tracker.headline.isEmpty {
                menu.addItem(disabled(tracker.headline))
            }
            if !tracker.note.isEmpty {
                menu.addItem(disabled(tracker.note))
            }
            if tracker.minutesAlready > 0 {
                menu.addItem(disabled("\(tracker.minutesAlready) min already saved"))
            }
            if let increment = config.roundUpMinutes, increment > 0 {
                menu.addItem(action("Pause", #selector(pauseTimer)))
                menu.addItem(action(finishTitle(for: tracker, increment: increment), #selector(finishTimer)))
            } else {
                menu.addItem(action("Stop", #selector(pauseTimer)))
            }
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

        if connected {
            menu.addItem(.separator())
            addToday(except: tracker?.entryId)
        }

        menu.addItem(.separator())
        addFooter(connected: connected)
    }

    private func addWorkday(config: AppConfig, connected: Bool) {
        let now = Date()
        menu.addItem(disabled(workdayHeader(config: config, now: now)))
        if let workday, WorkdayMath.isPast(workday, now: now), workday.phase != .running {
            menu.addItem(action("Start working time", #selector(startWorkday)))
        } else {
            switch workday?.phase {
            case .running:
                menu.addItem(action("Pause working time", #selector(pauseWorkday)))
                menu.addItem(action("Stop working time", #selector(stopWorkday)))
            case .paused:
                menu.addItem(action("Resume working time", #selector(startWorkday)))
                menu.addItem(action("Stop working time", #selector(stopWorkday)))
            case .stopped:
                menu.addItem(action("Resume working time", #selector(startWorkday)))
            case nil:
                menu.addItem(action("Start working time", #selector(startWorkday)))
            }
        }
        addDifference(config: config, connected: connected, now: now)
        menu.addItem(.separator())
    }

    private func workdayHeader(config: AppConfig, now: Date) -> String {
        guard let workday else { return "Working time" }
        var clock = formatDuration(workday.elapsed(at: now))
        if let standard = config.standardMinutes, standard > 0 {
            clock += " of \(WorkdayMath.formatTarget(standard))"
        }
        var parts = ["Working time"]
        if let phrase = WorkdayMath.dayPhrase(for: workday.day, now: now) {
            parts.append(phrase)
        }
        parts.append(clock)
        switch workday.phase {
        case .paused where !WorkdayMath.isPast(workday, now: now):
            parts.append("paused")
        case .stopped where WorkdayMath.stoppedAtLimit(workday):
            parts.append("stopped at \(WorkdayMath.formatTarget(Int(WorkdayMath.maximumDuration / 60)))")
        case .stopped:
            parts.append("stopped")
        case .running, .paused:
            break
        }
        if WorkdayMath.isOvertime(elapsed: workday.elapsed(at: now), standardMinutes: config.standardMinutes) {
            parts.append("overtime")
        }
        return parts.joined(separator: " · ")
    }

    private func addDifference(config: AppConfig, connected: Bool, now: Date) {
        guard let workday, connected else { return }
        // Less than a minute cannot produce a difference, so there is nothing to load yet.
        guard workday.elapsed(at: now) >= 60 else { return }
        guard differenceIsLoaded(now: now) else {
            let title = differenceError(now: now) == nil
                ? "Loading the difference…"
                : "The difference could not be loaded"
            menu.addItem(disabled(title))
            return
        }
        let gap = currentGapMinutes(now: now)
        guard gap > 0 else { return }
        guard let pair = config.differencePair else {
            menu.addItem(action("Choose a pair for the difference…", #selector(showSettings)))
            return
        }
        let title = "Add \(gap) min to \(menuTitle(for: pair))"
        guard isPairAvailable(pair) else {
            menu.addItem(disabled("\(title) (unavailable)"))
            return
        }
        menu.addItem(action(title, #selector(bookDifference)))
    }

    private func addToday(except runningId: Int?) {
        menu.addItem(disabled("Today"))
        guard todayLoaded else {
            menu.addItem(disabled(todayError ?? "Loading today…"))
            return
        }
        let rows = todayEntries.filter { $0.id != runningId }
        if rows.isEmpty {
            menu.addItem(disabled(runningId == nil ? "Nothing tracked today" : "Nothing else today"))
            return
        }
        for entry in rows {
            let item = NSMenuItem(title: todayTitle(for: entry), action: #selector(resumeEntry(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = EntryBox(entry)
            item.isEnabled = !isBusy && !entry.locked
            menu.addItem(item)
        }
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.isEnabled = !isBusy
        return item
    }

    private var roundingEnabled: Bool {
        ((try? FavoritesStore.load())?.roundUpMinutes ?? 0) > 0
    }

    private var roundingTitle: String {
        let increment = (try? FavoritesStore.load())?.roundUpMinutes ?? 0
        let minutes = increment > 0 ? increment : 15
        return "Round up to \(minutes) minutes"
    }

    private func finishTitle(for tracker: TrackerSnapshot, increment: Int) -> String {
        let minutes = MinuteRounding.ceil(already: tracker.minutesAlready, since: tracker.since, increment: increment)
        guard minutes > 0 else { return "Finish" }
        return "Finish · \(minutes) min"
    }

    private func todayTitle(for entry: TodayEntry) -> String {
        let name = entry.headline.isEmpty ? "Untitled" : entry.headline
        let note = clipped(entry.note, limit: 42)
        let time = "\(entry.minutes) min"
        let title = note.isEmpty ? "\(name) · \(time)" : "\(name) · \(note) · \(time)"
        return entry.locked ? "\(title) (locked)" : title
    }

    private func clipped(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 1)) + "…"
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

        let hours = NSMenuItem(title: "Daily hours…", action: #selector(showSettings), keyEquivalent: "")
        hours.target = self
        menu.addItem(hours)

        let rounding = NSMenuItem(title: roundingTitle, action: #selector(toggleRoundUp), keyEquivalent: "")
        rounding.target = self
        rounding.state = roundingEnabled ? .on : .off
        menu.addItem(rounding)

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
        DispatchQueue.main.async { [weak self] in
            self?.presentSettings()
        }
    }

    private func presentSettings() {
        if !keyIsStored || !catalogLoaded {
            warmCredentials(refreshTrackerIfNeeded: false)
        }
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

    @objc private func toggleRoundUp() {
        do {
            var config = try FavoritesStore.load()
            if let current = config.roundUpMinutes, current > 0 {
                config.roundUpMinutes = nil
            } else {
                config.roundUpMinutes = 15
            }
            try FavoritesStore.save(config)
        } catch {
            presentError(error)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func startPair(_ sender: NSMenuItem) {
        guard !isBusy, let box = sender.representedObject as? PairBox else { return }
        let pair = box.pair
        DispatchQueue.main.async { [weak self] in
            self?.startSavedPair(pair)
        }
    }

    private func startSavedPair(_ pair: FavoritePair) {
        guard !isBusy else { return }
        activateApp()
        guard let client = makeClient() else { return }
        guard let note = NotePrompt.ask(title: menuTitle(for: pair)) else { return }
        beginTrackingChange()
        Task {
            do {
                let snapshot = try await client.start(
                    projectId: pair.projectId,
                    serviceId: pair.serviceId,
                    note: note,
                    headline: self.menuTitle(for: pair)
                )
                let today = try? await client.today()
                DispatchQueue.main.async {
                    if let today { self.applyToday(today) }
                    self.tracker = snapshot
                    self.isBusy = false
                    self.updateStatusItem()
                }
            } catch {
                self.failTracking(error)
            }
        }
    }

    @objc private func resumeEntry(_ sender: NSMenuItem) {
        guard !isBusy, let box = sender.representedObject as? EntryBox else { return }
        let entry = box.entry
        guard let client = makeClient() else { return }
        beginTrackingChange()
        Task {
            do {
                let snapshot = try await client.resume(entry)
                let today = try? await client.today()
                DispatchQueue.main.async {
                    if let today { self.applyToday(today) }
                    self.tracker = snapshot
                    self.isBusy = false
                    self.updateStatusItem()
                }
            } catch {
                self.failTracking(error)
            }
        }
    }

    @objc private func pauseTimer() {
        guard !isBusy, let running = tracker else { return }
        guard let client = makeClient() else { return }
        beginTrackingChange()
        Task {
            do {
                try await client.pause(entryId: running.entryId)
                let today = try? await client.today()
                DispatchQueue.main.async {
                    if let today { self.applyToday(today) }
                    self.tracker = nil
                    self.isBusy = false
                    self.updateStatusItem()
                }
            } catch {
                self.failTracking(error)
            }
        }
    }

    @objc private func finishTimer() {
        guard !isBusy, let running = tracker else { return }
        guard let client = makeClient() else { return }
        let increment = (try? FavoritesStore.load())?.roundUpMinutes ?? 0
        beginTrackingChange()
        Task {
            do {
                if increment > 0 {
                    try await client.finish(
                        entryId: running.entryId,
                        minutesAlready: running.minutesAlready,
                        since: running.since,
                        roundUpTo: increment
                    )
                } else {
                    try await client.pause(entryId: running.entryId)
                }
                let today = try? await client.today()
                DispatchQueue.main.async {
                    if let today { self.applyToday(today) }
                    self.tracker = nil
                    self.isBusy = false
                    self.updateStatusItem()
                }
            } catch {
                self.failTracking(error)
            }
        }
    }

    @objc private func startWorkday() {
        guard !isBusy else { return }
        let now = Date()
        let next: Workday
        if let workday, workday.phase == .running || !WorkdayMath.isPast(workday, now: now) {
            next = workday.resuming(at: now)
        } else {
            next = Workday.started(now: now)
        }
        store(next)
    }

    @objc private func pauseWorkday() {
        guard !isBusy, let workday, workday.phase == .running else { return }
        store(workday.pausing(at: Date()))
    }

    @objc private func stopWorkday() {
        guard !isBusy, let workday else { return }
        let now = Date()
        guard workday.phase == .running || !WorkdayMath.isPast(workday, now: now) else { return }
        store(workday.stopping(at: now))
    }

    /// Sleep does not pause the clock. Waking applies the 10:45 limit if it passed while the Mac was closed.
    @objc private func systemDidWake(_ notification: Notification) {
        normalizeWorkdayClock()
        updateStatusItem()
    }

    @objc private func bookDifference() {
        guard !isBusy, let workday else { return }
        let now = Date()
        guard differenceIsLoaded(now: now) else { return }
        guard let client = makeClient() else { return }
        guard let config = try? FavoritesStore.load(), let pair = config.differencePair else {
            presentSettings()
            return
        }
        guard isPairAvailable(pair) else { return }
        let today = WorkdayMath.dayString(from: now)
        let includeTracker = workday.day == today
        let entries = entriesForDifference(now: now)
        let gap = WorkdayMath.gapMinutes(
            elapsed: workday.elapsed(at: now),
            bookedMinutes: WorkdayMath.bookedMinutes(entries: entries, tracker: includeTracker ? tracker : nil, now: now)
        )
        guard gap > 0 else { return }
        let existing = WorkdayMath.differenceEntry(
            in: entries,
            projectId: pair.projectId,
            serviceId: pair.serviceId,
            runningId: includeTracker ? tracker?.entryId : nil
        )
        let day = workday.day
        beginTrackingChange()
        Task {
            do {
                if let existing {
                    try await client.saveMinutes(entryId: existing.id, minutes: existing.minutes + gap)
                } else {
                    try await client.addSettledTime(
                        projectId: pair.projectId,
                        serviceId: pair.serviceId,
                        minutes: gap,
                        note: WorkdayMath.differenceNote,
                        day: day
                    )
                }
                if day == WorkdayMath.dayString(from: Date()) {
                    let todayEntries = try? await client.today()
                    DispatchQueue.main.async {
                        if let todayEntries { self.applyToday(todayEntries) }
                        self.isBusy = false
                        self.updateStatusItem()
                    }
                } else {
                    let loaded = try? await client.entries(on: day)
                    DispatchQueue.main.async {
                        if let loaded, self.workday?.day == day {
                            self.pastEntries = loaded
                            self.pastDay = day
                            self.pastLoaded = true
                            self.pastError = nil
                        }
                        self.isBusy = false
                        self.updateStatusItem()
                    }
                }
            } catch {
                self.failTracking(error)
            }
        }
    }

    private func store(_ workday: Workday) {
        self.workday = workday
        do {
            try WorkdayStore.save(workday)
        } catch {
            presentError(error)
        }
        updateStatusItem()
    }

    private func normalizeWorkdayClock(now: Date = Date()) {
        guard let workday else { return }
        let next = WorkdayMath.normalizing(workday, now: now)
        guard next != workday else { return }
        self.workday = next
        try? WorkdayStore.save(next)
        pastLoaded = false
        pastEntries = []
        pastError = nil
        pastDay = nil
        refreshPastEntries()
    }

    private func currentGapMinutes(now: Date) -> Int {
        guard let workday else { return 0 }
        let includeTracker = workday.day == WorkdayMath.dayString(from: now)
        return WorkdayMath.gapMinutes(
            elapsed: workday.elapsed(at: now),
            bookedMinutes: WorkdayMath.bookedMinutes(
                entries: entriesForDifference(now: now),
                tracker: includeTracker ? tracker : nil,
                now: now
            )
        )
    }

    private func entriesForDifference(now: Date) -> [TodayEntry] {
        guard let workday else { return [] }
        if workday.day == WorkdayMath.dayString(from: now) { return todayEntries }
        return pastDay == workday.day ? pastEntries : []
    }

    private func differenceIsLoaded(now: Date) -> Bool {
        guard let workday else { return false }
        if workday.day == WorkdayMath.dayString(from: now) { return todayLoaded }
        return pastLoaded && pastDay == workday.day
    }

    private func differenceError(now: Date) -> String? {
        guard let workday else { return nil }
        if workday.day == WorkdayMath.dayString(from: now) { return todayError }
        return pastError
    }

    private func makeClient() -> MiteClient? {
        keyIsStored = Keychain.load() != nil
        do {
            return try MiteClient.make()
        } catch {
            presentError(error)
            return nil
        }
    }

    private func failTracking(_ error: Error) {
        DispatchQueue.main.async {
            self.isBusy = false
            self.updateStatusItem()
            self.presentError(error)
            self.refreshTracker()
            self.refreshToday()
        }
    }

    private func warmCredentials(refreshTrackerIfNeeded: Bool) {
        activateApp()
        keyIsStored = Keychain.load() != nil
        guard keyIsStored else { return }
        if !catalogLoaded {
            refreshCatalog()
        }
        if refreshTrackerIfNeeded {
            refreshTracker()
        }
        refreshToday()
        refreshPastEntries()
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

    private func refreshToday() {
        guard keyIsStored else { return }
        todayEpoch += 1
        let epoch = todayEpoch
        let client: MiteClient
        do {
            client = try MiteClient.make()
        } catch {
            return
        }
        Task {
            do {
                let entries = try await client.today()
                DispatchQueue.main.async {
                    guard epoch == self.todayEpoch else { return }
                    self.applyToday(entries)
                }
            } catch {
                DispatchQueue.main.async {
                    guard epoch == self.todayEpoch else { return }
                    if self.todayEntries.isEmpty {
                        self.todayLoaded = false
                        self.todayError = "Today's entries could not be loaded"
                    }
                }
            }
        }
    }

    private func applyToday(_ entries: [TodayEntry]) {
        todayEpoch += 1
        todayEntries = entries
        todayLoaded = true
        todayError = nil
    }

    private func refreshPastEntries() {
        guard keyIsStored, let workday else { return }
        let today = WorkdayMath.dayString(from: Date())
        guard workday.day != today else { return }
        pastEpoch += 1
        let epoch = pastEpoch
        let day = workday.day
        if pastDay != day {
            pastLoaded = false
            pastEntries = []
            pastError = nil
            pastDay = day
        }
        let client: MiteClient
        do {
            client = try MiteClient.make()
        } catch {
            return
        }
        Task {
            do {
                let entries = try await client.entries(on: day)
                DispatchQueue.main.async {
                    guard epoch == self.pastEpoch, self.workday?.day == day else { return }
                    self.pastEntries = entries
                    self.pastDay = day
                    self.pastLoaded = true
                    self.pastError = nil
                }
            } catch {
                DispatchQueue.main.async {
                    guard epoch == self.pastEpoch, self.workday?.day == day else { return }
                    if !self.pastLoaded {
                        self.pastError = "The difference could not be loaded"
                    }
                }
            }
        }
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
        normalizeWorkdayClock()
        guard let button = statusItem.button else { return }
        let font = button.font ?? NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        if isBusy {
            button.contentTintColor = nil
            button.attributedTitle = NSAttributedString(string: "")
            button.title = " …"
            syncTick()
            return
        }

        let now = Date()
        let config = (try? FavoritesStore.load()) ?? .empty
        let workdayText = workday.map { formatDuration($0.elapsed(at: now)) }
        let projectText = tracker.map { formatElapsed(since: $0.since, now: now) }
        let overtime = workday.map {
            WorkdayMath.isOvertime(elapsed: $0.elapsed(at: now), standardMinutes: config.standardMinutes)
        } ?? false

        if overtime, let workdayText {
            var text = " " + workdayText
            if let projectText {
                text += " · " + projectText
            }
            button.title = ""
            button.attributedTitle = NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: NSColor.systemRed,
            ])
            button.contentTintColor = .systemRed
        } else {
            var parts: [String] = []
            if let workdayText { parts.append(workdayText) }
            if let projectText { parts.append(projectText) }
            button.contentTintColor = nil
            button.attributedTitle = NSAttributedString(string: "")
            button.title = parts.isEmpty ? (button.image == nil ? "mite" : "") : " " + parts.joined(separator: " · ")
        }

        var lines: [String] = []
        if workday != nil {
            lines.append(workdayHeader(config: config, now: now))
        }
        if let tracker {
            lines.append(contentsOf: [tracker.headline, tracker.note].filter { !$0.isEmpty })
            if tracker.minutesAlready > 0 {
                lines.append("\(tracker.minutesAlready) min already saved")
            }
        }
        button.toolTip = lines.isEmpty ? "mite" : lines.joined(separator: "\n")
        syncTick()
    }

    private func syncTick() {
        let running = tracker != nil || workday?.phase == .running
        if running {
            guard tick == nil else { return }
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateStatusItem()
            }
            RunLoop.main.add(timer, forMode: .common)
            tick = timer
        } else {
            tick?.invalidate()
            tick = nil
        }
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

if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
    let app = NSApplication.shared
    let controller = AppController()
    app.delegate = controller
    app.setActivationPolicy(.accessory)
    app.run()
}
