// swiftc -framework Security -o /tmp/workday-check Sources/MiteMenu/FavoritesStore.swift Sources/MiteMenu/MiteClient.swift Sources/MiteMenu/Keychain.swift Sources/MiteMenu/Workday.swift Checks/workday-check.swift && /tmp/workday-check
import Foundation

private var failures: [String] = []

private func check(_ condition: Bool, _ message: String) {
    if !condition { failures.append(message) }
}

private func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual != expected {
        failures.append("\(message): \(actual) != \(expected)")
    }
}

private func checkClose(_ actual: TimeInterval, _ expected: TimeInterval, _ message: String) {
    if abs(actual - expected) > 0.001 {
        failures.append("\(message): \(actual) != \(expected)")
    }
}

private var calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func pauseKeepsElapsedAndResumeContinues() {
    let start = date(2026, 11, 10, 8, 0)
    var clock = Workday.started(now: start, calendar: calendar)
    let pausedAt = start.addingTimeInterval(90)
    clock = clock.pausing(at: pausedAt)
    checkEqual(clock.phase, .paused, "pause phase")
    check(clock.runningSince == nil, "pause clears the start")
    checkClose(clock.elapsed(at: pausedAt.addingTimeInterval(500)), 90, "pause freezes elapsed")
    let resumed = pausedAt.addingTimeInterval(500)
    clock = clock.resuming(at: resumed)
    checkEqual(clock.phase, .running, "resume phase")
    checkClose(clock.elapsed(at: resumed.addingTimeInterval(30)), 120, "resume continues")
}

private func stopFreezesTheDayAndCanResume() {
    let start = date(2026, 11, 10, 8, 0)
    let clock = Workday.started(now: start, calendar: calendar)
    let stopped = clock.stopping(at: start.addingTimeInterval(3600))
    checkEqual(stopped.phase, .stopped, "stop phase")
    checkClose(stopped.elapsed(at: start.addingTimeInterval(9000)), 3600, "stop freezes elapsed")
    let resumed = stopped.resuming(at: start.addingTimeInterval(9000))
    checkClose(resumed.elapsed(at: start.addingTimeInterval(9060)), 3660, "resume after stop")
}

private func idleAndAClosedNightKeepCounting() {
    let start = date(2026, 11, 10, 12, 0)
    let clock = Workday.started(now: start, calendar: calendar)
    let afterLunch = start.addingTimeInterval(90 * 60)
    let still = WorkdayMath.normalizing(clock, now: afterLunch, calendar: calendar)
    checkEqual(still, clock, "lunch leaves the clock running")
    checkClose(still.elapsed(at: afterLunch), 90 * 60, "lunch is counted")

    let evening = date(2026, 11, 10, 20, 0)
    let late = Workday.started(now: evening, calendar: calendar)
    let duringNight = date(2026, 11, 11, 4, 0)
    let acrossMidnight = WorkdayMath.normalizing(late, now: duringNight, calendar: calendar)
    checkEqual(acrossMidnight.phase, .running, "still running after midnight")
    checkEqual(acrossMidnight.day, "2026-11-10", "day stays the start day")
    checkClose(acrossMidnight.elapsed(at: duringNight), 8 * 3600, "closed hours count")
    checkEqual(WorkdayMath.dayPhrase(for: acrossMidnight.day, now: duringNight, calendar: calendar), "yesterday", "yesterday label")
    let nextMorning = date(2026, 11, 11, 9, 0)
    let capped = WorkdayMath.normalizing(late, now: nextMorning, calendar: calendar)
    checkEqual(capped.phase, .stopped, "a closed night stops at the limit")
    checkClose(capped.elapsed(at: nextMorning), WorkdayMath.maximumDuration, "asleep time after the limit is left out")
}

private func automaticStopLandsOnTenHoursFortyFiveMinutes() {
    let start = date(2026, 11, 10, 8, 0)
    let clock = Workday.started(now: start, calendar: calendar)
    let justBefore = start.addingTimeInterval(WorkdayMath.maximumDuration - 1)
    checkEqual(WorkdayMath.normalizing(clock, now: justBefore, calendar: calendar).phase, .running, "one second before the limit")
    let morningAfter = start.addingTimeInterval(WorkdayMath.maximumDuration + 3 * 3600)
    let stopped = WorkdayMath.normalizing(clock, now: morningAfter, calendar: calendar)
    checkEqual(stopped.phase, .stopped, "automatic stop")
    checkEqual(stopped.day, "2026-11-10", "automatic stop keeps the day")
    checkClose(stopped.elapsed(at: morningAfter), WorkdayMath.maximumDuration, "time after the limit is left out")
    check(WorkdayMath.stoppedAtLimit(stopped), "recognized as the automatic stop")
    let manual = clock.stopping(at: start.addingTimeInterval(3600))
    check(!WorkdayMath.stoppedAtLimit(manual), "a manual stop is not the limit")
}

private func resumeAfterTheLimitKeepsCounting() {
    let start = date(2026, 11, 10, 8, 0)
    let clock = Workday.started(now: start, calendar: calendar)
    let later = start.addingTimeInterval(WorkdayMath.maximumDuration + 600)
    let capped = WorkdayMath.normalizing(clock, now: later, calendar: calendar)
    let resumedAt = later.addingTimeInterval(60)
    let resumed = capped.resuming(at: resumedAt)
    checkEqual(resumed.phase, .running, "resume after the limit")
    check(resumed.limitLifted, "limit lifted")
    let after = resumedAt.addingTimeInterval(120)
    let kept = WorkdayMath.normalizing(resumed, now: after, calendar: calendar)
    checkEqual(kept.phase, .running, "does not stop again")
    checkClose(kept.elapsed(at: after), WorkdayMath.maximumDuration + 120, "counts past the limit")
    let loaded = try? WorkdayFile.workday(from: WorkdayFile.data(for: kept))
    check(loaded?.limitLifted == true, "file keeps the lifted limit")
}

private func pausedPreviousDayStaysFinished() {
    let start = date(2026, 11, 10, 8, 0)
    let clock = Workday.started(now: start, calendar: calendar).pausing(at: start.addingTimeInterval(8 * 3600))
    let morning = date(2026, 11, 11, 9, 0)
    let finished = WorkdayMath.normalizing(clock, now: morning, calendar: calendar)
    checkEqual(finished.phase, .stopped, "previous pause becomes stopped")
    checkClose(finished.elapsed(at: morning), 8 * 3600, "previous total")
}

private func sameDayIsLeftRunning() {
    let start = date(2026, 11, 10, 8, 0)
    let clock = Workday.started(now: start, calendar: calendar)
    let later = start.addingTimeInterval(600)
    checkEqual(WorkdayMath.normalizing(clock, now: later, calendar: calendar), clock, "same day")
    check(WorkdayMath.dayPhrase(for: clock.day, now: later, calendar: calendar) == nil, "no day label today")
}

private func gapUsesWholeMinutes() {
    checkEqual(WorkdayMath.gapMinutes(elapsed: 14 * 60 + 59, bookedMinutes: 0), 14, "no round up")
    checkEqual(WorkdayMath.gapMinutes(elapsed: 61, bookedMinutes: 0), 1, "one minute")
    checkEqual(WorkdayMath.gapMinutes(elapsed: 59, bookedMinutes: 0), 0, "partial minute")
    checkEqual(WorkdayMath.gapMinutes(elapsed: 50 * 60, bookedMinutes: 45), 5, "difference")
    checkEqual(WorkdayMath.gapMinutes(elapsed: 30 * 60, bookedMinutes: 45), 0, "booked ahead")
}

private func overtimeStartsAtTheDailyTarget() {
    check(!WorkdayMath.isOvertime(elapsed: 8 * 3600 - 1, standardMinutes: 480), "before target")
    check(WorkdayMath.isOvertime(elapsed: 8 * 3600, standardMinutes: 480), "at target")
    check(!WorkdayMath.isOvertime(elapsed: 9 * 3600, standardMinutes: nil), "no target")
    check(!WorkdayMath.isOvertime(elapsed: 9 * 3600, standardMinutes: 0), "zero target")
}

private func bookedMinutesIncludeTheLiveRunOnce() {
    let now = date(2026, 11, 10, 10, 0)
    let entries = [
        TodayEntry(id: 1, minutes: 30, note: "ABC-1", headline: "Customer — Consulting", locked: false, projectId: 7, serviceId: 8),
        TodayEntry(id: 2, minutes: 15, note: "", headline: "Internal — Meetings", locked: false, projectId: 9, serviceId: 4),
    ]
    let tracker = TrackerSnapshot(entryId: 2, since: now.addingTimeInterval(-10 * 60), minutesAlready: 15, headline: "Internal — Meetings", note: "")
    checkEqual(WorkdayMath.bookedMinutes(entries: entries, tracker: tracker, now: now), 55, "live run once")
    checkEqual(WorkdayMath.bookedMinutes(entries: entries, tracker: nil, now: now), 45, "stored only")
}

private func bookedMinutesDoNotAddTimeAlreadyStored() {
    let now = date(2026, 11, 10, 10, 0)
    let entries = [TodayEntry(id: 2, minutes: 25, note: "", headline: "Internal — Meetings", locked: false)]
    let tracker = TrackerSnapshot(entryId: 2, since: now.addingTimeInterval(-10 * 60), minutesAlready: 15, headline: "Internal — Meetings", note: "")
    checkEqual(WorkdayMath.bookedMinutes(entries: entries, tracker: tracker, now: now), 25, "already stored")
}

private func differenceEntryMatchesTheWorkingTimeNote() {
    let entries = [
        TodayEntry(id: 1, minutes: 20, note: "ticket", headline: "Internal", locked: false, projectId: 9, serviceId: 4),
        TodayEntry(id: 2, minutes: 12, note: "Working time", headline: "Internal", locked: true, projectId: 9, serviceId: 4),
        TodayEntry(id: 3, minutes: 8, note: "Working time", headline: "Internal", locked: false, projectId: 9, serviceId: 4),
    ]
    checkEqual(WorkdayMath.differenceEntry(in: entries, projectId: 9, serviceId: 4, runningId: nil)?.id, 3, "unlocked note")
    check(WorkdayMath.differenceEntry(in: entries, projectId: 9, serviceId: 4, runningId: 3) == nil, "skip the running entry")
}

private func parseHours() {
    checkEqual(WorkdayMath.parseHours("8"), 480, "8")
    checkEqual(WorkdayMath.parseHours("8h"), 480, "8h")
    checkEqual(WorkdayMath.parseHours("7.5"), 450, "7.5")
    checkEqual(WorkdayMath.parseHours("7,5"), 450, "7,5")
    checkEqual(WorkdayMath.parseHours("7:30"), 450, "7:30")
    checkEqual(WorkdayMath.parseHours("08:05"), 485, "08:05")
    check(WorkdayMath.parseHours("") == nil, "empty")
    check(WorkdayMath.parseHours("0") == nil, "zero")
    check(WorkdayMath.parseHours("24:01") == nil, "over a day")
    check(WorkdayMath.parseHours("7:60") == nil, "bad minutes")
    checkEqual(WorkdayMath.formatHoursField(480), "8", "field hours")
    checkEqual(WorkdayMath.formatHoursField(450), "7:30", "field minutes")
    checkEqual(WorkdayMath.formatTarget(480), "8:00", "target")
}

private func clockFileRoundTrip() throws {
    let start = date(2026, 11, 10, 8, 15)
    let clock = Workday.started(now: start, calendar: calendar)
    let loaded = try WorkdayFile.workday(from: WorkdayFile.data(for: clock))
    checkEqual(loaded.day, "2026-11-10", "file day")
    checkEqual(loaded.phase, .running, "file phase")
    checkClose(loaded.accumulated, 0, "file accumulated")
    checkClose(loaded.runningSince?.timeIntervalSince(start) ?? 99, 0, "file start")
}

private func configKeepsWorkingTimeKeys() throws {
    let original = """
    {
      "account": "acme",
      "differenceProjectId": 1002,
      "differenceServiceId": 12,
      "pairs": [
        { "label": "Internal — Administration", "projectId": 1002, "serviceId": 12 }
      ],
      "standardMinutes": 480
    }
    """
    let config = try JSONDecoder().decode(AppConfig.self, from: Data(original.utf8))
    checkEqual(config.standardMinutes, 480, "standard minutes")
    checkEqual(config.differencePair?.label, "Internal — Administration", "difference pair")
    let cleared = try JSONDecoder().decode(AppConfig.self, from: Data(#"{"account":"acme","pairs":[]}"#.utf8))
    check(cleared.standardMinutes == nil, "cleared hours")
    check(cleared.differencePair == nil, "cleared pair")
}

@main
struct WorkdayCheck {
    static func main() {
        pauseKeepsElapsedAndResumeContinues()
        stopFreezesTheDayAndCanResume()
        idleAndAClosedNightKeepCounting()
        automaticStopLandsOnTenHoursFortyFiveMinutes()
        resumeAfterTheLimitKeepsCounting()
        pausedPreviousDayStaysFinished()
        sameDayIsLeftRunning()
        gapUsesWholeMinutes()
        overtimeStartsAtTheDailyTarget()
        bookedMinutesIncludeTheLiveRunOnce()
        bookedMinutesDoNotAddTimeAlreadyStored()
        differenceEntryMatchesTheWorkingTimeNote()
        parseHours()
        do {
            try clockFileRoundTrip()
            try configKeepsWorkingTimeKeys()
        } catch {
            failures.append(error.localizedDescription)
        }

        if failures.isEmpty {
            print("ok")
        } else {
            for failure in failures {
                print(failure)
            }
            exit(1)
        }
    }
}
