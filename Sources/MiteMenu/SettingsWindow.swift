import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate, @unchecked Sendable {
    var onCatalogUpdated: (([MiteProject], [MiteService]) -> Void)?

    private let accountField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let connectButton = NSButton()
    private let projectPopup = NSPopUpButton()
    private let servicePopup = NSPopUpButton()
    private let addButton = NSButton()
    private let hoursField = NSTextField()
    private let gapPopup = NSPopUpButton()
    private let saveWorkdayButton = NSButton()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private var gapPairs: [FavoritePair] = []

    private var loadedProjects: [MiteProject] = []
    private var loadedServices: [MiteService] = []
    private var isLoading = false
    private var didPlace = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "mite menu"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show(projects: [MiteProject], services: [MiteService]) {
        guard let window else { return }
        if !projects.isEmpty || !services.isEmpty {
            updateCatalog(projects: projects, services: services)
        } else {
            fillPopups()
        }
        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            activateApp()
            return
        }
        reloadFields()
        reloadWorkingTime()
        if !didPlace {
            window.center()
            didPlace = true
        }
        window.makeKeyAndOrderFront(nil)
        activateApp()
        window.makeFirstResponder(accountField)
    }

    func updateCatalog(projects: [MiteProject], services: [MiteService]) {
        let projectID = selectedID(in: projectPopup, from: loadedProjects)
        let serviceID = selectedID(in: servicePopup, from: loadedServices)
        loadedProjects = projects.sorted(by: projectSort)
        loadedServices = services.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        fillPopups()
        select(id: projectID, in: projectPopup)
        select(id: serviceID, in: servicePopup)
    }

    private func build() {
        guard let content = window?.contentView else { return }

        accountField.placeholderString = "company"
        apiKeyField.placeholderString = "API key"
        configure(popup: projectPopup)
        configure(popup: servicePopup)

        connectButton.title = "Save connection"
        connectButton.bezelStyle = .rounded
        connectButton.target = self
        connectButton.action = #selector(saveConnection)

        addButton.title = "Add pair"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addPair)

        hoursField.placeholderString = "8 or 7:30"
        configure(popup: gapPopup)
        saveWorkdayButton.title = "Save working time"
        saveWorkdayButton.bezelStyle = .rounded
        saveWorkdayButton.target = self
        saveWorkdayButton.action = #selector(saveWorkingTime)

        statusLabel.maximumNumberOfLines = 3
        statusLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.preferredMaxLayoutWidth = 460

        let workdayHint = NSTextField(wrappingLabelWithString: "Daily hours turn the menu-bar clock red after that time. The difference between working time and minutes booked on projects is saved on the chosen pair, in exact minutes. The mite note is Working time.")
        workdayHint.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        workdayHint.textColor = .secondaryLabelColor
        workdayHint.preferredMaxLayoutWidth = 460
        workdayHint.maximumNumberOfLines = 4

        let hint = NSTextField(wrappingLabelWithString: "Pairs are saved in \(FavoritesStore.displayPath). Rename, reorder, or remove them in that file. The menu reads it each time it opens.")
        hint.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = 460

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let rows = [
            heading("Connection"),
            labeledRow("Account", accountField),
            labeledRow("API key", apiKeyField),
            connectButton,
            heading("Add a pair"),
            projectPopup,
            servicePopup,
            addButton,
            heading("Working time"),
            NSTextField(labelWithString: "Daily hours"),
            hoursField,
            NSTextField(labelWithString: "Add the difference to"),
            gapPopup,
            workdayHint,
            saveWorkdayButton,
            statusLabel,
            hint,
        ]
        for view in rows {
            stack.addArrangedSubview(view)
        }
        stack.setCustomSpacing(16, after: connectButton)
        stack.setCustomSpacing(16, after: addButton)
        stack.setCustomSpacing(16, after: saveWorkdayButton)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            accountField.widthAnchor.constraint(equalToConstant: 360),
            apiKeyField.widthAnchor.constraint(equalToConstant: 360),
            projectPopup.widthAnchor.constraint(equalToConstant: 460),
            servicePopup.widthAnchor.constraint(equalToConstant: 460),
            hoursField.widthAnchor.constraint(equalToConstant: 120),
            gapPopup.widthAnchor.constraint(equalToConstant: 460),
            workdayHint.widthAnchor.constraint(equalToConstant: 460),
            statusLabel.widthAnchor.constraint(equalToConstant: 460),
            hint.widthAnchor.constraint(equalToConstant: 460),
        ])
        fillPopups()
    }

    private func heading(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        return field
    }

    private func labeledRow(_ title: String, _ field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: 72).isActive = true
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func configure(popup: NSPopUpButton) {
        popup.autoenablesItems = false
        popup.controlSize = .regular
    }

    private func reloadFields() {
        let account = (try? FavoritesStore.load().account) ?? ""
        accountField.stringValue = account
        apiKeyField.stringValue = ""
        if Keychain.load() != nil {
            apiKeyField.placeholderString = "Saved in Keychain — leave blank to keep it"
        } else {
            apiKeyField.placeholderString = "API key"
        }
    }

    @objc private func saveConnection() {
        guard !isLoading else { return }
        window?.makeFirstResponder(nil)
        guard let account = FavoritesStore.normalizeAccount(accountField.stringValue) else {
            setStatus("Enter the account subdomain, such as your-account from your-account.mite.de.", isError: true)
            return
        }
        let typedKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if typedKey.isEmpty && Keychain.load() == nil {
            setStatus("Enter the API key from your mite user settings.", isError: true)
            return
        }
        do {
            if !typedKey.isEmpty {
                try Keychain.save(typedKey)
                apiKeyField.stringValue = ""
                apiKeyField.placeholderString = "Saved in Keychain — leave blank to keep it"
            }
            try FavoritesStore.setAccount(account)
            accountField.stringValue = account
        } catch {
            setStatus(error.localizedDescription, isError: true)
            return
        }

        let client: MiteClient
        do {
            client = try MiteClient.make()
        } catch {
            setStatus(error.localizedDescription, isError: true)
            return
        }

        isLoading = true
        connectButton.isEnabled = false
        addButton.isEnabled = false
        saveWorkdayButton.isEnabled = false
        connectButton.title = "Loading…"
        setStatus("Loading projects and services…", isError: false)
        Task {
            do {
                async let projects = client.projects()
                async let services = client.services()
                let loaded = try await (projects, services)
                DispatchQueue.main.async {
                    self.finishLoad(projects: loaded.0, services: loaded.1, error: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.finishLoad(projects: nil, services: nil, error: error)
                }
            }
        }
    }

    private func finishLoad(projects: [MiteProject]?, services: [MiteService]?, error: Error?) {
        isLoading = false
        connectButton.isEnabled = true
        saveWorkdayButton.isEnabled = true
        connectButton.title = "Save connection"
        guard let projects, let services else {
            setStatus(error?.localizedDescription ?? "Could not load projects and services.", isError: true)
            return
        }
        updateCatalog(projects: projects, services: services)
        onCatalogUpdated?(projects, services)
        setStatus("Saved. Loaded \(projects.count) projects and \(services.count) services.", isError: false)
    }

    @objc private func addPair() {
        guard let project = selectedValue(in: projectPopup, from: loadedProjects),
              let service = selectedValue(in: servicePopup, from: loadedServices)
        else {
            setStatus("Save the connection, then choose a project and a service.", isError: true)
            return
        }
        let label = FavoritesStore.suggestedLabel(project: project, service: service)
        do {
            let pairs = try FavoritesStore.load().pairs
            if let existing = pairs.first(where: { $0.projectId == project.id && $0.serviceId == service.id }) {
                setStatus("\(existing.label) is already in the menu.", isError: false)
                return
            }
            let labelTaken = pairs.contains { $0.label == label }
            try FavoritesStore.addPair(FavoritePair(label: label, projectId: project.id, serviceId: service.id))
            if labelTaken {
                setStatus("Added \(label). Another pair uses that name, so rename one in the config file.", isError: false)
            } else {
                setStatus("Added \(label).", isError: false)
            }
            let selected = selectedGapPair()
            fillGapPopup(projectId: selected?.projectId, serviceId: selected?.serviceId)
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func reloadWorkingTime() {
        let config = try? FavoritesStore.load()
        if let minutes = config?.standardMinutes, minutes > 0 {
            hoursField.stringValue = WorkdayMath.formatHoursField(minutes)
        } else {
            hoursField.stringValue = ""
        }
        fillGapPopup(projectId: config?.differenceProjectId, serviceId: config?.differenceServiceId)
    }

    @objc private func saveWorkingTime() {
        guard !isLoading else { return }
        window?.makeFirstResponder(nil)
        let raw = hoursField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let minutes: Int?
        if raw.isEmpty {
            minutes = nil
        } else if let parsed = WorkdayMath.parseHours(raw) {
            minutes = parsed
        } else {
            setStatus("Enter daily hours as 8 or 7:30.", isError: true)
            return
        }
        let pair = selectedGapPair()
        do {
            var config = try FavoritesStore.load()
            config.standardMinutes = minutes
            config.differenceProjectId = pair?.projectId
            config.differenceServiceId = pair?.serviceId
            try FavoritesStore.save(config)
            if let minutes {
                hoursField.stringValue = WorkdayMath.formatHoursField(minutes)
            }
            setStatus("Saved working time.", isError: false)
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func fillGapPopup(projectId: Int?, serviceId: Int?) {
        gapPairs = (try? FavoritesStore.load())?.pairs ?? []
        gapPopup.removeAllItems()
        if gapPairs.isEmpty {
            gapPopup.addItem(withTitle: "Add a pair first")
            gapPopup.lastItem?.tag = -1
            gapPopup.lastItem?.isEnabled = false
            return
        }
        gapPopup.addItem(withTitle: "None")
        gapPopup.lastItem?.tag = -1
        for (index, pair) in gapPairs.enumerated() {
            let title = pair.label.trimmingCharacters(in: .whitespacesAndNewlines)
            gapPopup.addItem(withTitle: title.isEmpty ? "(untitled)" : title)
            gapPopup.lastItem?.tag = index
        }
        guard let projectId, let serviceId,
              let index = gapPairs.firstIndex(where: { $0.projectId == projectId && $0.serviceId == serviceId })
        else { return }
        if let item = gapPopup.itemArray.first(where: { $0.tag == index }) {
            gapPopup.select(item)
        }
    }

    private func selectedGapPair() -> FavoritePair? {
        guard let item = gapPopup.selectedItem, item.isEnabled, gapPairs.indices.contains(item.tag) else {
            return nil
        }
        return gapPairs[item.tag]
    }

    private func fillPopups() {
        fill(
            projectPopup,
            titles: loadedProjects.map(projectMenuTitle),
            empty: "Save the connection to load projects"
        )
        fill(
            servicePopup,
            titles: loadedServices.map(\.name),
            empty: "Save the connection to load services"
        )
        addButton.isEnabled = !loadedProjects.isEmpty && !loadedServices.isEmpty && !isLoading
    }

    private func fill(_ popup: NSPopUpButton, titles: [String], empty: String) {
        popup.removeAllItems()
        if titles.isEmpty {
            popup.addItem(withTitle: empty)
            popup.lastItem?.tag = -1
            popup.lastItem?.isEnabled = false
            return
        }
        for (index, title) in titles.enumerated() {
            popup.addItem(withTitle: title)
            popup.lastItem?.tag = index
            popup.lastItem?.isEnabled = true
        }
    }

    private func selectedID<T>(in popup: NSPopUpButton, from values: [T]) -> Int? where T: IdentifiableID {
        selectedValue(in: popup, from: values)?.id
    }

    private func selectedValue<T>(in popup: NSPopUpButton, from values: [T]) -> T? {
        guard let item = popup.selectedItem, item.isEnabled, values.indices.contains(item.tag) else {
            return nil
        }
        return values[item.tag]
    }

    private func select(id: Int?, in popup: NSPopUpButton) {
        guard let id else { return }
        for item in popup.itemArray where item.tag >= 0 {
            let valuesAreProjects = popup === projectPopup
            let matches = valuesAreProjects
                ? loadedProjects.indices.contains(item.tag) && loadedProjects[item.tag].id == id
                : loadedServices.indices.contains(item.tag) && loadedServices[item.tag].id == id
            if matches {
                popup.select(item)
                return
            }
        }
    }

    private func projectMenuTitle(_ project: MiteProject) -> String {
        let customer = project.customerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if customer.isEmpty { return project.name }
        return "\(customer) — \(project.name)"
    }

    private func projectSort(_ lhs: MiteProject, _ rhs: MiteProject) -> Bool {
        projectMenuTitle(lhs).localizedCaseInsensitiveCompare(projectMenuTitle(rhs)) == .orderedAscending
    }

    private func setStatus(_ text: String, isError: Bool) {
        statusLabel.stringValue = text
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }
}

private protocol IdentifiableID {
    var id: Int { get }
}

extension MiteProject: IdentifiableID {}
extension MiteService: IdentifiableID {}
