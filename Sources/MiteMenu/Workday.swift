import Foundation

struct Workday: Equatable {
    enum Phase: String, Equatable {
        case running
        case paused
        case stopped
    }

    var day: String
    var accumulated: TimeInterval
    var runningSince: Date?
    var phase: Phase

    static func started(now: Date, calendar: Calendar = .current) -> Workday {
        Workday(
            day: WorkdayMath.dayString(from: now, calendar: calendar),
            accumulated: 0,
            runningSince: now,
            phase: .running
        )
    }

    func elapsed(at now: Date) -> TimeInterval {
        let running = runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return max(0, accumulated + running)
    }

    func pausing(at now: Date) -> Workday {
        guard phase == .running else { return self }
        var copy = self
        copy.accumulated = elapsed(at: now)
        copy.runningSince = nil
        copy.phase = .paused
        return copy
    }

    func stopping(at now: Date) -> Workday {
        var copy = pausing(at: now)
        copy.phase = .stopped
        return copy
    }

    func resuming(at now: Date) -> Workday {
        guard phase != .running else { return self }
        var copy = self
        copy.runningSince = now
        copy.phase = .running
        return copy
    }

    /// Freezes a running clock at `end`, which is the start of the next day.
    func capped(at end: Date) -> Workday {
        guard phase == .running, let runningSince else {
            var copy = self
            copy.runningSince = nil
            copy.phase = .stopped
            return copy
        }
        var copy = self
        let until = max(runningSince, end)
        copy.accumulated += until.timeIntervalSince(runningSince)
        copy.runningSince = nil
        copy.phase = .stopped
        return copy
    }
}

enum WorkdayMath {
    /// mite note used to find the one entry that holds the unbooked difference.
    static let differenceNote = "Working time"

    static func dayString(from date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func parseDay(_ day: String, calendar: Calendar = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: day)
    }

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// A clock from an earlier day is finished. A running clock stops at midnight so the night is not counted.
    static func normalizing(_ stored: Workday, now: Date, calendar: Calendar = .current) -> Workday {
        let today = dayString(from: now, calendar: calendar)
        guard stored.day != today else { return stored }
        if stored.phase == .running {
            return stored.capped(at: startOfDay(now, calendar: calendar))
        }
        var finished = stored
        finished.runningSince = nil
        finished.phase = .stopped
        return finished
    }

    static func isPast(_ workday: Workday, now: Date, calendar: Calendar = .current) -> Bool {
        workday.day != dayString(from: now, calendar: calendar)
    }

    /// Short label for a clock that is still on screen after its day ended. Nil for today.
    static func dayPhrase(for day: String, now: Date, calendar: Calendar = .current) -> String? {
        guard let date = parseDay(day, calendar: calendar) else { return nil }
        if calendar.isDate(date, inSameDayAs: now) { return nil }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay(now, calendar: calendar)),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "yesterday"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    static func isOvertime(elapsed: TimeInterval, standardMinutes: Int?) -> Bool {
        guard let standardMinutes, standardMinutes > 0 else { return false }
        return elapsed >= Double(standardMinutes * 60)
    }

    /// Whole minutes of working time that are not already booked. Partial minutes are left out.
    static func gapMinutes(elapsed: TimeInterval, bookedMinutes: Int) -> Int {
        let worked = max(0, Int(elapsed / 60))
        return max(0, worked - max(0, bookedMinutes))
    }

    /// Minutes already stored in mite, plus the current project run when it is not in those totals yet.
    static func bookedMinutes(entries: [TodayEntry], tracker: TrackerSnapshot?, now: Date) -> Int {
        let stored = entries.reduce(0) { $0 + max(0, $1.minutes) }
        guard let tracker else { return stored }
        let live = max(0, Int(now.timeIntervalSince(tracker.since) / 60))
        let runningTotal = max(0, tracker.minutesAlready) + live
        if let entry = entries.first(where: { $0.id == tracker.entryId }) {
            return stored + max(0, runningTotal - max(0, entry.minutes))
        }
        return stored + runningTotal
    }

    static func differenceEntry(
        in entries: [TodayEntry],
        projectId: Int,
        serviceId: Int,
        runningId: Int?
    ) -> TodayEntry? {
        entries.first {
            $0.projectId == projectId
                && $0.serviceId == serviceId
                && $0.note == differenceNote
                && !$0.locked
                && $0.id != runningId
        }
    }

    /// Daily target as `8:00`.
    static func formatTarget(_ minutes: Int) -> String {
        let hours = max(0, minutes) / 60
        let mins = max(0, minutes) % 60
        return String(format: "%d:%02d", hours, mins)
    }

    /// Value shown in the settings field. Whole hours stay a plain number.
    static func formatHoursField(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = abs(minutes % 60)
        if mins == 0 { return String(hours) }
        return String(format: "%d:%02d", hours, mins)
    }

    /// Reads `8`, `7.5`, `7,5`, `7:30`, or `8h`. Empty input is handled by the caller. Zero and values above 24 hours are rejected.
    static func parseHours(_ raw: String) -> Int? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasSuffix("hours") {
            text.removeLast(5)
        } else if text.hasSuffix("hour") {
            text.removeLast(4)
        } else if text.hasSuffix("h") {
            text.removeLast(1)
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let minutes: Int
        if text.contains(":") {
            let parts = text.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2,
                  let hours = Int(parts[0]),
                  let mins = Int(parts[1]),
                  hours >= 0,
                  (0 ..< 60).contains(mins)
            else { return nil }
            minutes = hours * 60 + mins
        } else {
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            guard let hours = Double(normalized), hours.isFinite, hours > 0 else { return nil }
            minutes = Int((hours * 60).rounded())
        }
        guard minutes > 0, minutes <= 24 * 60 else { return nil }
        return minutes
    }
}

enum WorkdayFile {
    static func data(for workday: Workday) throws -> Data {
        var object: [String: Any] = [
            "accumulated": workday.accumulated,
            "day": workday.day,
            "phase": workday.phase.rawValue,
        ]
        if let runningSince = workday.runningSince {
            object["runningSince"] = iso.string(from: runningSince)
        }
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        if data.last != 0x0A {
            data.append(0x0A)
        }
        return data
    }

    static func workday(from data: Data) throws -> Workday {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let day = object["day"] as? String,
              WorkdayMath.parseDay(day) != nil,
              let phaseName = object["phase"] as? String,
              let phase = Workday.Phase(rawValue: phaseName)
        else {
            throw ConfigError.unreadable("Could not read the working-time clock.")
        }
        let accumulated = seconds(object["accumulated"]) ?? 0
        let runningSince = (object["runningSince"] as? String).flatMap { iso.date(from: $0) }
        guard phase != .running || runningSince != nil else {
            throw ConfigError.unreadable("Could not read the working-time clock.")
        }
        return Workday(day: day, accumulated: max(0, accumulated), runningSince: phase == .running ? runningSince : nil, phase: phase)
    }

    private static func seconds(_ value: Any?) -> TimeInterval? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return TimeInterval(number) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

enum WorkdayStore {
    static var fileURL: URL {
        FavoritesStore.fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("workday.json")
    }

    static func load(now: Date = Date(), calendar: Calendar = .current) -> Workday? {
        guard let stored = read() else { return nil }
        let normalized = WorkdayMath.normalizing(stored, now: now, calendar: calendar)
        if normalized != stored {
            try? save(normalized)
        }
        return normalized
    }

    static func save(_ workday: Workday) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try WorkdayFile.data(for: workday).write(to: fileURL, options: .atomic)
    }

    private static func read() -> Workday? {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return nil }
        return try? WorkdayFile.workday(from: data)
    }
}
