// Compiled into the same file as the application by run_tests.py to exercise
// actual private application methods, with an isolated UserDefaults suite.
extension EyeBreakBuddyApp {
    func runBehaviorChecks() {
        animateTransitions = false
        applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        heartbeat?.invalidate()
        assert(ChopperView.hidingSprite != nil, "Hiding sprite must load beside executable")
        assert(ChopperView.walkingAtlas != nil, "Walking atlas must load beside executable")
        assert(ChopperView.atlas != nil, "Chopper atlas must load beside the executable")
        let bitmap = NSBitmapImageRep(data: ChopperView.atlas!.tiffRepresentation!)!
        assert(bitmap.hasAlpha && bitmap.colorAt(x: 0, y: 0)!.alphaComponent == 0,
               "The buddy background must be genuinely transparent")
        // Independently measure foot pixels in the actual atlas, then verify the
        // production draw rectangles put every pose on the same center/baseline.
        let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
        var registeredFeet: [NSPoint] = []
        for pose in 0..<4 {
            let x0 = (pose % 2) * width / 2, x1 = (pose % 2 + 1) * width / 2
            let y0 = (pose / 2) * height / 2, y1 = (pose / 2 + 1) * height / 2
            var minX = x1, maxX = x0, maxY = y0
            for y in (y0 + (y1 - y0) * 4 / 5)..<y1 {
                for x in x0..<x1 where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                    minX = min(minX, x); maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
            let cell = NSSize(width: Double(width) / 2, height: Double(height) / 2)
            let destination = ChopperView.alignedPoseRect(pose, cell: cell,
                bounds: NSRect(x: 0, y: 0, width: 195, height: 250))
            let localX = Double(minX + maxX) / 2 - Double(pose % 2) * cell.width
            let bottomY = Double(maxY) - Double(pose / 2) * cell.height
            registeredFeet.append(NSPoint(x: destination.minX + localX * destination.width / cell.width,
                y: destination.minY + (cell.height - bottomY) * destination.height / cell.height))
        }
        for foot in registeredFeet.dropFirst() {
            assert(abs(foot.x - registeredFeet[0].x) < 0.25 && abs(foot.y - registeredFeet[0].y) < 0.25,
                   "Expression changes must keep feet registered to the same position")
        }
        assert(waterGoalML == 2500 && waterStepML == 250)
        assert(shortBreakInterval == 1200 && waterReminderInterval == 3600)
        // Preserve the original daily storage format.
        assert(keyForToday("waterML").hasPrefix("waterML-"))
        defaults.set(700, forKey: keyForToday("waterML"))
        assert(waterML == 700)
        saveNumber("goalML", 3000)
        assert(waterGoalML == 3000 && waterML == 700)
        logWater(330)
        assert(waterML == 1030)
        removeWater()
        assert(waterML == 700)
        removeWater()
        assert(waterML == 700, "Undo must not subtract twice")
        dismissPanel()
        showBreakPopup()
        let originalPanel = panel
        logWater(150)
        assert(panel === originalPanel && isBreakVisible && countdownTimer != nil)
        assert(buddyView != nil)
        snoozeBreak()
        assert(buddyView == nil, "Dismissal must release the animation")
        assert(panel == nil && breakSnoozed && nextBreak.timeIntervalSinceNow > 295)
        let pauseItem = NSMenuItem()
        pauseItem.representedObject = 60
        pause(pauseItem)
        nextBreak = .distantPast
        nextWater = .distantPast
        tick()
        assert(isPaused && panel == nil, "Pause must suppress both reminder types")
        saveNumber("eyeMinutes", 30)
        assert(isPaused, "Changing settings must not resume paused reminders")
        pausedUntil = Date().addingTimeInterval(-1)
        tick()
        assert(!isPaused && panel == nil && nextBreak > Date() && nextWater > Date())
        saveNumber("eyeMinutes", 0)
        saveNumber("waterMinutes", 0)
        nextBreak = .distantPast
        nextWater = .distantPast
        tick()
        assert(panel == nil, "Off must disable timers")
        saveNumber("longEvery", 0)
        showBreakPopup()
        assert(countdownRemaining == 20, "Long reset Off must avoid modulo-zero")
        snoozeBreak()
        nextBreak = .distantPast
        tick()
        assert(isBreakVisible, "Explicit snooze must work even with periodic breaks off")
        dismissPanel()
        saveNumber("eyeMinutes", 20)
        saveNumber("waterMinutes", 60)
        nextBreak = .distantPast
        nextWater = .distantPast
        tick()
        assert(isBreakVisible)
        let eyePanel = panel
        tick()
        assert(panel === eyePanel, "Simultaneous water reminder must not replace break")
        dismissPanel()
        tick()
        assert(panel != nil && !isBreakVisible)
        dismissPanel()
        waterML = waterGoalML
        nextWater = .distantPast
        tick()
        assert(panel == nil, "Do not prompt more water once goal reached")
        dayKey = "previous-day"
        statusItem.button?.title = "stale"
        tick()
        assert(dayKey == keyForToday("waterML") && statusItem.button?.title != "stale")
        showBreakPopup()
        finishBreak()
        assert(!isBreakVisible && buddyView?.mood == .happy && countdownTimer == nil,
               "Finishing a break must celebrate and stop the countdown")
        dismissPanel()
        assert(defaults.integer(forKey: "goalML") == 3000)
        // Exercise actual timed entrances/exits separately from synchronous checks.
        animateTransitions = true
        if shouldAnimateTransitions {
            func waitFor(_ condition: () -> Bool) {
                let limit = Date().addingTimeInterval(12)
                while !condition() && Date() < limit {
                    RunLoop.main.run(until: Date().addingTimeInterval(0.03))
                }
                assert(condition(), "Timed buddy transition did not complete")
            }
            showBreakPopup()
            let walkingPanel = panel
            assert(buddyPhase == .runningIn && countdownTimer == nil && buddyView?.mood == .runLeft)
            waitFor { self.buddyPhase == .peeking }
            assert(countdownTimer == nil && buddyView?.mood == .hiding)
            waitFor { self.buddyPhase == .entering }
            assert(countdownTimer == nil && buddyView?.mood == .walkLeft)
            waitFor { self.buddyPhase == .presenting }
            assert(countdownTimer != nil, "Countdown starts only after arrival")
            finishBreak()
            assert(panel === walkingPanel && buddyView?.mood == .happy,
                   "Completion must celebrate in place, without a second entrance")
            waitFor { self.buddyPhase == .exiting }
            assert(buddyView?.mood == .walkRight)
            waitFor { self.buddyPhase == .hidden }
            assert(panel == nil && motionTimer == nil && buddyView == nil)
            showWaterPopup()
            waitFor { self.buddyPhase == .presenting }
            dismissPanel()
            assert(buddyPhase == .exiting)
            // A new reminder during departure must invalidate the old movement callback.
            showBreakPopup()
            let replacement = panel
            waitFor { self.buddyPhase == .presenting }
            assert(panel === replacement && isBreakVisible && countdownTimer != nil)
            closePanelImmediately()
            showWaterPopup()
            waitFor { self.buddyPhase == .peeking }
            assert(buddyPhase == .peeking)
            dismissPanel()
            assert(peekTimer == nil && buddyPhase == .exiting)
            waitFor { self.buddyPhase == .hidden }
            RunLoop.main.run(until: Date().addingTimeInterval(2))
            assert(panel == nil && peekTimer == nil, "Dismissed hiding pose must not reappear")
        }
        applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        NSStatusBar.system.removeStatusItem(statusItem)
        print("PASS: storage compatibility, settings, quick-add/undo, popup continuity, snooze, pause/resume, disabled timers, simultaneous reminders, goal suppression, daily title refresh, walk-in/out lifecycle and countdown timing")
    }
}
let app = NSApplication.shared
let delegate = EyeBreakBuddyApp()
delegate.runBehaviorChecks()
