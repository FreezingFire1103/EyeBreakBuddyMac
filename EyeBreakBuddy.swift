import Cocoa

// Four poses share one transparent atlas. Animation runs only while a buddy is visible.
final class ChopperView: NSView {
    enum Mood { case greeting, happy, dance, walkLeft, walkRight, runLeft, hiding }
    static let atlas: NSImage? = {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        return NSImage(contentsOf: executable.deletingLastPathComponent()
            .appendingPathComponent("Assets/chopper-sprites.png"))
    }()
    static let walkingAtlas: NSImage? = {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        return NSImage(contentsOf: executable.deletingLastPathComponent()
            .appendingPathComponent("Assets/chopper-walk.png"))
    }()
    static let hidingSprite: NSImage? = {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        return NSImage(contentsOf: executable.deletingLastPathComponent()
            .appendingPathComponent("Assets/chopper-edge-hold.png"))
    }()
    static let danceAtlas: NSImage? = {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        return NSImage(contentsOf: executable.deletingLastPathComponent()
            .appendingPathComponent("Assets/chopper-dance.png"))
    }()
    // Measure once so transparent padding cannot introduce a sideways jump.
    static let danceFrames: [NSRect] = {
        guard let data = danceAtlas?.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else { return [] }
        return (0..<2).map { frame in
            let start = frame * bitmap.pixelsWide / 2
            let end = (frame + 1) * bitmap.pixelsWide / 2
            var left = end, right = start, top = bitmap.pixelsHigh, bottom = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in start..<end where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                    left = min(left, x); right = max(right, x)
                    top = min(top, y); bottom = max(bottom, y)
                }
            }
            return NSRect(x: left, y: bitmap.pixelsHigh - bottom - 1,
                          width: right - left + 1, height: bottom - top + 1)
        }
    }()

    // Foot-center / ground-line anchors measured from this 1263 × 1245 atlas.
    // Equal-sized cells have different transparent padding; align the character,
    // not the cell, so changing expression cannot move him sideways.
    private static let footAnchors = [
        NSPoint(x: 353.0 / 631.5, y: 606.0 / 622.5),
        NSPoint(x: 276.0 / 631.5, y: 606.0 / 622.5),
        NSPoint(x: 340.0 / 631.5, y: 578.5 / 622.5),
        NSPoint(x: 280.0 / 631.5, y: 579.5 / 622.5)
    ]

    static func alignedPoseRect(_ pose: Int, cell: NSSize, bounds: NSRect, bob: CGFloat = 0) -> NSRect {
        let scale = min(bounds.width / cell.width, (bounds.height - 12) / cell.height)
        let size = NSSize(width: cell.width * scale, height: cell.height * scale)
        let reference = footAnchors[0], anchor = footAnchors[pose]
        return NSRect(x: (bounds.width - size.width) / 2 + (reference.x - anchor.x) * size.width,
                      y: (bounds.height - size.height) / 2 + (anchor.y - reference.y) * size.height + bob,
                      width: size.width, height: size.height)
    }

    private var animationTimer: Timer?
    private var started = Date()
    var mood: Mood = .greeting { didSet { started = Date(); needsDisplay = true } }
    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Chopper, your break buddy")
        animationTimer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.reduceMotion { self.needsDisplay = true }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func stopAnimating() { animationTimer?.invalidate(); animationTimer = nil }
    deinit { animationTimer?.invalidate() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        guard let atlas = Self.atlas else {
            ("🦌" as NSString).draw(in: bounds.insetBy(dx: 30, dy: 50),
                                   withAttributes: [.font: NSFont.systemFont(ofSize: 90)])
            return
        }
        let elapsed = Date().timeIntervalSince(started)
        if mood == .dance, let dance = Self.danceAtlas, Self.danceFrames.count == 2 {
            let frame = reduceMotion ? 0 : Int(elapsed / 0.36) % 2
            let source = Self.danceFrames[frame]
            let referenceCell = NSSize(width: atlas.size.width / 2, height: atlas.size.height / 2)
            let reference = Self.alignedPoseRect(0, cell: referenceCell, bounds: bounds)
            let floor = reference.minY + (1 - Self.footAnchors[0].y) * reference.height
            let height = bounds.width * 0.90
            let width = height * source.width / source.height
            dance.draw(in: NSRect(x: bounds.midX - width / 2, y: floor, width: width, height: height),
                       from: source, operation: .sourceOver, fraction: 1,
                       respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            return
        }
        if mood == .hiding, let hiding = Self.hidingSprite {
            let scale = 0.85 * min(bounds.width / hiding.size.width, (bounds.height - 12) / hiding.size.height)
            let size = NSSize(width: hiding.size.width * scale, height: hiding.size.height * scale)
            hiding.draw(in: NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                                  width: size.width, height: size.height),
                        from: .zero, operation: .sourceOver, fraction: 1,
                        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            return
        }
        if (mood == .walkLeft || mood == .walkRight || mood == .runLeft), let walking = Self.walkingAtlas {
            let cell = NSSize(width: walking.size.width / 2, height: walking.size.height)
            let source = NSRect(x: CGFloat(Int(elapsed / (mood == .runLeft ? 0.12 : 0.32)) % 2) * cell.width, y: 0,
                                width: cell.width, height: cell.height)
            let scale = min(bounds.width / cell.width, (bounds.height - 12) / cell.height)
            let size = NSSize(width: cell.width * scale, height: cell.height * scale)
            let lift = mood == .runLeft ? abs(sin(elapsed * 18)) * 5 : 0
            let target = NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2 + lift,
                                width: size.width, height: size.height)
            NSGraphicsContext.saveGraphicsState()
            if mood == .walkRight {
                let mirror = NSAffineTransform()
                mirror.translateX(by: bounds.width, yBy: 0)
                mirror.scaleX(by: -1, yBy: 1)
                mirror.concat()
            }
            walking.draw(in: target, from: source, operation: .sourceOver, fraction: 1,
                         respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            NSGraphicsContext.restoreGraphicsState()
            return
        }
        let pose: Int
        if mood == .happy { pose = 3 }
        else if reduceMotion { pose = 0 }
        else if elapsed < 2.4 { pose = Int(elapsed / 0.3) % 2 == 0 ? 2 : 0 }
        else { pose = elapsed.truncatingRemainder(dividingBy: 4.5) > 4.15 ? 1 : 0 }
        let cell = NSSize(width: atlas.size.width / 2, height: atlas.size.height / 2)
        // NSImage's source coordinates have their origin at the bottom left.
        let source = NSRect(x: CGFloat(pose % 2) * cell.width,
                            y: CGFloat(1 - pose / 2) * cell.height,
                            width: cell.width, height: cell.height)
        let bob: CGFloat = (!reduceMotion && mood == .happy) ? CGFloat(sin(elapsed * 9)) * 5 : 0
        let destination = Self.alignedPoseRect(pose, cell: cell, bounds: bounds, bob: bob)
        atlas.draw(in: destination, from: source, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }
}

final class SpeechBubbleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.98).setFill()
        let bubble = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 22, yRadius: 22)
        bubble.fill()
        NSColor.separatorColor.setStroke()
        bubble.lineWidth = 1
        bubble.stroke()
    }
}


final class EyeBreakBuddyApp: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel?
    private var buddyView: ChopperView?
    private let buddyScale: CGFloat = 0.9
    private let buddyBaselineY: CGFloat = 3.5
    private enum BuddyPhase { case hidden, runningIn, peeking, entering, presenting, exiting }
    private var buddyPhase: BuddyPhase = .hidden
    private var motionTimer: Timer?
    private var peekTimer: Timer?
    private var confirmationTimer: Timer?
    private var danceTimer: Timer?
    private var pendingWaterDance = false
    // Test harness can disable transitions while exercising synchronous legacy behavior.
    private var animateTransitions = true
    private var shouldAnimateTransitions: Bool {
        animateTransitions && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    private var countdownTimer: Timer?
    private var countdownRemaining = 20
    private var breakCount = 0

    private let defaults = UserDefaults.standard
    private var heartbeat: Timer?
    private var nextBreak = Date.distantFuture
    private var nextWater = Date.distantFuture
    private var dayKey = ""
    private var isBreakVisible = false
    private var breakSnoozed = false
    private var waterGoalML: Int { defaults.integer(forKey: "goalML") }
    private var waterStepML: Int { defaults.integer(forKey: "stepML") }
    private var shortBreakInterval: TimeInterval { Double(defaults.integer(forKey: "eyeMinutes") * 60) }
    private var longBreakEvery: Int { defaults.integer(forKey: "longEvery") }
    private var waterReminderInterval: TimeInterval { Double(defaults.integer(forKey: "waterMinutes") * 60) }
    private var pausedUntil: Date? {
        get { defaults.object(forKey: "pausedUntil") as? Date }
        set { defaults.set(newValue, forKey: "pausedUntil") }
    }
    private var isPaused: Bool { (pausedUntil ?? .distantPast) > Date() }

    private var waterML: Int {
        get { defaults.integer(forKey: keyForToday("waterML")) }
        set { defaults.set(max(0, newValue), forKey: keyForToday("waterML")); updateMenuTitle() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        defaults.register(defaults: ["goalML": 2500, "stepML": 250, "eyeMinutes": 20,
                                     "waterMinutes": 60, "longEvery": 4, "sound": false,
                                     "position": "Top right"])
        dayKey = keyForToday("waterML")
        setupStatusItem()
        scheduleTimers()
        updateMenuTitle()
        heartbeat = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(heartbeat!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        heartbeat?.invalidate()
        countdownTimer?.invalidate()
        buddyView?.stopAnimating()
        motionTimer?.invalidate()
        peekTimer?.invalidate()
        confirmationTimer?.invalidate()
    }

    private func keyForToday(_ base: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "\(base)-\(f.string(from: Date()))"
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Eye Break Buddy")
        statusItem.button?.imagePosition = .imageLeading

        rebuildMenu()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(removeWater) {
            return defaults.integer(forKey: keyForToday("lastWater")) > 0
        }
        if menuItem.action == #selector(resumeReminders) { return isPaused }
        return true
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuTitle()
        rebuildMenu()
    }

    @discardableResult
    private func item(_ menu: NSMenu, _ title: String, _ action: Selector? = nil,
                      value: Any? = nil, checked: Bool = false) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        i.representedObject = value
        i.state = checked ? .on : .off
        menu.addItem(i)
        return i
    }

    private func choices(_ parent: NSMenu, _ title: String, key: String,
                         values: [Int], unit: String) {
        let sub = NSMenu()
        item(parent, title).submenu = sub
        for value in values {
            item(sub, value == 0 ? "Off" : "\(value) \(unit)", #selector(setNumber(_:)),
                 value: ["key": key, "value": value] as [String: Any],
                 checked: defaults.integer(forKey: key) == value)
        }
        if key != "longEvery" {
            item(sub, "Custom…", #selector(customNumber(_:)), value: key)
        }
    }

    private func rebuildMenu() {
        let menu = statusItem.menu ?? NSMenu()
        menu.removeAllItems()
        menu.delegate = self
        item(menu, "Today: \(waterML) / \(waterGoalML) ml")
        item(menu, "Take eye break now", #selector(showEyeBreakNow))
        for amount in Array(Set([150, 250, 500, waterStepML])).sorted() {
            item(menu, "Add \(amount) ml water", #selector(quickAdd(_:)), value: amount)
        }
        item(menu, "Add custom amount…", #selector(customAdd))
        let last = defaults.integer(forKey: keyForToday("lastWater"))
        let undo = item(menu, last > 0 ? "Undo last add (\(last) ml)" : "Undo last add",
                        #selector(removeWater))
        undo.isEnabled = last > 0
        menu.addItem(.separator())
        item(menu, "Show water progress", #selector(showWaterProgress))
        if isPaused, let until = pausedUntil {
            item(menu, "Paused until \(DateFormatter.localizedString(from: until, dateStyle: .none, timeStyle: .short))")
        }
        let pause = NSMenu()
        item(menu, "Pause all reminders").submenu = pause
        for minutes in [5, 15, 30, 60, 120] {
            item(pause, "\(minutes) minutes", #selector(pause(_:)), value: minutes)
        }
        item(menu, "Resume reminders", #selector(resumeReminders)).isEnabled = isPaused
        menu.addItem(.separator())
        let settings = NSMenu()
        item(menu, "Settings").submenu = settings
        choices(settings, "Eye break interval: \(Int(shortBreakInterval / 60)) min", key: "eyeMinutes",
                values: [0, 15, 20, 30, 45, 60], unit: "minutes")
        choices(settings, "Long reset: \(longBreakEvery == 0 ? "Off" : "every \(longBreakEvery) eye breaks")",
                key: "longEvery", values: [0, 2, 3, 4, 6], unit: "eye breaks")
        choices(settings, "Water reminder: \(Int(waterReminderInterval / 60)) min", key: "waterMinutes",
                values: [0, 30, 45, 60, 90, 120], unit: "minutes")
        choices(settings, "Daily water goal: \(waterGoalML) ml", key: "goalML",
                values: [1500, 2000, 2500, 3000, 3500], unit: "ml/day")
        item(settings, "Default recommended goal: 2.5 L/day")
        item(settings, "Water goal guidance…", #selector(waterGuidance))
        choices(settings, "Popup quick-add: \(waterStepML) ml", key: "stepML",
                values: [100, 150, 250, 330, 500], unit: "ml")
        item(settings, "Reminder sound", #selector(toggleSound), checked: defaults.bool(forKey: "sound"))
        let positions = NSMenu()
        item(settings, "Popup position").submenu = positions
        for position in ["Top right", "Top left", "Bottom right", "Bottom left", "Center"] {
            item(positions, position, #selector(setPosition(_:)), value: position,
                 checked: defaults.string(forKey: "position") == position)
        }
        menu.addItem(.separator())
        item(menu, "Quit Eye Break Buddy", #selector(quitApp))
        statusItem.menu = menu
    }

    private func scheduleTimers() {
        breakSnoozed = false
        nextBreak = Date().addingTimeInterval(shortBreakInterval)
        nextWater = Date().addingTimeInterval(waterReminderInterval)
    }

    @objc private func didWake() { scheduleTimers(); updateMenuTitle() }

    private func tick() {
        let today = keyForToday("waterML")
        if dayKey != today { dayKey = today; updateMenuTitle() }
        if isPaused { return }
        if pausedUntil != nil {
            pausedUntil = nil
            scheduleTimers()
            updateMenuTitle()
        }
        // Leave the current card intact; simultaneous reminders are shown in sequence.
        guard panel == nil else { return }
        let now = Date()
        if (shortBreakInterval > 0 || breakSnoozed) && now >= nextBreak {
            breakSnoozed = false
            nextBreak = now.addingTimeInterval(shortBreakInterval)
            showBreakPopup()
        } else if waterReminderInterval > 0 && now >= nextWater {
            nextWater = now.addingTimeInterval(waterReminderInterval)
            if waterML < waterGoalML { showWaterPopup(); playSound() }
        }
    }

    private func updateMenuTitle() {
        statusItem.button?.title = " \(waterML)/\(waterGoalML) ml 💧" + (isPaused ? " ⏸" : "")
        statusItem.button?.toolTip = "Eye Break Buddy • Daily water goal \(waterGoalML) ml"
    }

    @objc private func setNumber(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Any],
              let key = data["key"] as? String, let value = data["value"] as? Int else { return }
        saveNumber(key, value)
    }

    private func saveNumber(_ key: String, _ value: Int) {
        defaults.set(value, forKey: key)
        if key == "eyeMinutes" { nextBreak = Date().addingTimeInterval(shortBreakInterval); breakCount = 0 }
        if key == "waterMinutes" { nextWater = Date().addingTimeInterval(waterReminderInterval) }
        if key == "longEvery" { breakCount = 0 }
        updateMenuTitle()
    }

    private func askNumber(title: String, message: String, initial: Int,
                           range: ClosedRange<Int>) -> Int? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message + "\nEnter a whole number (\(range.lowerBound)–\(range.upperBound))."
        let field = NSTextField(string: String(initial))
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        while alert.runModal() == .alertFirstButtonReturn {
            if let number = Int(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
               range.contains(number) { return number }
            alert.informativeText = "Please enter a whole number from \(range.lowerBound) to \(range.upperBound)."
        }
        return nil
    }

    @objc private func customNumber(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        let isGoal = key == "goalML"
        let isAmount = isGoal || key == "stepML"
        if let value = askNumber(title: isGoal ? "Daily water goal" : (isAmount ? "Popup quick-add amount" : "Reminder interval"),
                                 message: isAmount ? "Amount in millilitres." : "Interval in minutes. Use Off in the menu to disable.",
                                 initial: defaults.integer(forKey: key),
                                 range: isGoal ? 250...10000 : (isAmount ? 25...2000 : 1...240)) {
            saveNumber(key, value)
        }
    }

    @objc private func toggleSound() { defaults.set(!defaults.bool(forKey: "sound"), forKey: "sound") }
    @objc private func setPosition(_ sender: NSMenuItem) {
        defaults.set(sender.representedObject as? String, forKey: "position")
    }
    private func playSound() { if defaults.bool(forKey: "sound") { NSSound(named: "Glass")?.play() } }
    @objc private func waterGuidance() {
        let alert = NSAlert()
        alert.messageText = "Default recommended goal: 2.5 L/day"
        alert.informativeText = "This is an adjustable starting goal. Needs vary with heat and activity. Fluids from food and other beverages also contribute to daily hydration; you do not need to drink this amount as plain water in addition to those fluids."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func makePanel(width: CGFloat = 360, height: CGFloat = 190) -> NSPanel {
        closePanelImmediately()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let position = defaults.string(forKey: "position") ?? "Top right"
            let x = position == "Center" ? visible.midX - width / 2 :
                (position.contains("left") ? visible.minX + 24 : visible.maxX - width - 24)
            let y = position == "Center" ? visible.midY - height / 2 :
                (position.contains("Bottom") ? visible.minY + 24 : visible.maxY - height - 24)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = panel
        return panel
    }

    private func cardView(width: CGFloat, height: CGFloat) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        v.wantsLayer = true
        v.layer?.cornerRadius = 24
        v.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        v.layer?.borderWidth = 1
        v.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        return v
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, alignment: NSTextAlignment = .left) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: size, weight: weight)
        l.alignment = alignment
        l.textColor = .labelColor
        l.lineBreakMode = .byWordWrapping
        l.maximumNumberOfLines = 0
        return l
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.font = .systemFont(ofSize: 13, weight: .semibold)
        return b
    }

    private func buddyPanel(title: String, body: String, happy: Bool = false) -> (NSPanel, NSView) {
        let p = makePanel(width: 470, height: 270)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 470, height: 270))
        p.contentView = root
        root.wantsLayer = true
        root.layer?.masksToBounds = true
        let buddy = ChopperView(frame: NSRect(x: 0, y: buddyBaselineY,
                                            width: 195 * buddyScale, height: 250 * buddyScale))
        // Preserve drawing coordinates while uniformly shrinking every pose to 90%.
        buddy.setBoundsSize(NSSize(width: 195, height: 250))
        buddy.mood = happy ? .happy : .greeting
        root.addSubview(buddy)
        buddyView = buddy
        let bubble = SpeechBubbleView(frame: NSRect(x: 185, y: 35, width: 280, height: 220))
        root.addSubview(bubble)
        let heading = label(title, size: 18, weight: .bold)
        heading.identifier = NSUserInterfaceItemIdentifier("buddyTitle")
        heading.frame = NSRect(x: 202, y: 208, width: 246, height: 28)
        root.addSubview(heading)
        let message = label(body, size: 14)
        message.identifier = NSUserInterfaceItemIdentifier("buddyMessage")
        message.frame = NSRect(x: 202, y: 125, width: 246, height: 76)
        root.addSubview(message)
        return (p, root)
    }

    private func setBubbleVisible(_ visible: Bool) {
        panel?.contentView?.subviews.filter { !($0 is ChopperView) }.forEach { $0.isHidden = !visible }
    }

    // Expand a transparent, clipped stage as far as this screen's right edge.
    // The window never crosses onto a neighboring monitor; only the character moves.
    private func expandWalkingStage(_ p: NSPanel) -> CGFloat {
        let screen = p.screen ?? NSScreen.main
        let rightEdge = screen?.frame.maxX ?? p.frame.maxX
        let width = max(470, rightEdge - p.frame.minX)
        p.setFrame(NSRect(x: p.frame.minX, y: p.frame.minY, width: width, height: 270), display: true)
        return width
    }

    private func walk(_ p: NSPanel, from startX: CGFloat, to endX: CGFloat, speed: Double = 140,
                      completion: @escaping () -> Void) {
        motionTimer?.invalidate()
        let started = Date()
        let duration = max(0.6, Double(abs(endX - startX)) / speed)
        buddyView?.setFrameOrigin(NSPoint(x: startX, y: buddyBaselineY))
        motionTimer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self, weak p] timer in
            guard let self = self, let p = p, self.panel === p else { timer.invalidate(); return }
            let fraction = min(1, Date().timeIntervalSince(started) / duration)
            self.buddyView?.setFrameOrigin(NSPoint(x: startX + (endX - startX) * fraction, y: self.buddyBaselineY))
            if fraction >= 1 {
                timer.invalidate()
                self.motionTimer = nil
                completion()
            }
        }
        RunLoop.main.add(motionTimer!, forMode: .common)
    }

    private func presentBuddy(_ p: NSPanel, onArrival: @escaping () -> Void = {}) {
        guard shouldAnimateTransitions else {
            buddyPhase = .presenting
            p.orderFrontRegardless()
            onArrival()
            return
        }
        let restingMood = buddyView?.mood ?? .greeting
        buddyPhase = .runningIn
        p.ignoresMouseEvents = true
        setBubbleVisible(false)
        let edge = expandWalkingStage(p)
        let peekX = edge - 166 * buddyScale
        buddyView?.mood = .runLeft
        buddyView?.setFrameOrigin(NSPoint(x: edge, y: buddyBaselineY))
        p.orderFrontRegardless()
        // Three distinct beats: run up, grip the screen and hide, then walk in.
        walk(p, from: edge, to: peekX, speed: 300) { [weak self, weak p] in
            guard let self = self, let p = p, self.panel === p, self.buddyPhase == .runningIn else { return }
            self.buddyPhase = .peeking
            self.buddyView?.mood = .hiding
            self.peekTimer = Timer(timeInterval: 2.2, repeats: false) { [weak self, weak p] _ in
                guard let self = self, let p = p, self.panel === p, self.buddyPhase == .peeking else { return }
                self.peekTimer = nil
                self.buddyPhase = .entering
                self.buddyView?.mood = .walkLeft
                self.walk(p, from: peekX, to: 0) { [weak self, weak p] in
                    guard let self = self, let p = p, self.panel === p, self.buddyPhase == .entering else { return }
                    p.setFrame(NSRect(x: p.frame.minX, y: p.frame.minY, width: 470, height: 270), display: true)
                    self.buddyView?.mood = restingMood
                    self.buddyPhase = .presenting
                    self.setBubbleVisible(true)
                    p.ignoresMouseEvents = false
                    onArrival()
                }
            }
            RunLoop.main.add(self.peekTimer!, forMode: .common)
        }
    }

    private func showBreakPopup() {
        breakCount += 1
        let isLong = longBreakEvery > 0 && breakCount % longBreakEvery == 0
        countdownRemaining = isLong ? 300 : 20
        let (p, root) = buddyPanel(title: isLong ? "Time for a longer reset!" : "Let's rest your eyes!",
            body: isLong ? "Step away for five minutes. Stretch, blink, and relax. I'll keep time!" :
            "Look about 20 feet away and blink gently for 20 seconds. You've got this!")
        isBreakVisible = true
        playSound()
        let countdown = label(isLong ? "5:00" : "20s", size: 22, weight: .bold)
        countdown.identifier = NSUserInterfaceItemIdentifier("countdown")
        countdown.frame = NSRect(x: 204, y: 92, width: 240, height: 28)
        root.addSubview(countdown)
        let done = button("Done", action: #selector(finishBreak))
        done.frame = NSRect(x: 378, y: 49, width: 73, height: 32)
        root.addSubview(done)
        let water = button("+\(waterStepML) ml", action: #selector(addWater))
        water.frame = NSRect(x: 286, y: 49, width: 90, height: 32)
        root.addSubview(water)
        let snooze = button("Snooze 5m", action: #selector(snoozeBreak))
        snooze.frame = NSRect(x: 197, y: 49, width: 89, height: 32)
        root.addSubview(snooze)
        presentBuddy(p) { [weak self, weak p, weak countdown] in
        guard let self = self, let p = p, self.panel === p, let countdown = countdown else { return }
        self.startCountdown(countdown, isLong: isLong)
        if self.pendingWaterDance { self.danceDuringBreak() }
        }
    }

    private func startCountdown(_ countdown: NSTextField, isLong: Bool) {
        let countdownEnd = Date().addingTimeInterval(Double(countdownRemaining))
        countdownTimer = Timer(timeInterval: 1, repeats: true) { [weak self, weak countdown] timer in
            guard let self = self, let countdown = countdown else { timer.invalidate(); return }
            self.countdownRemaining = max(0, Int(ceil(countdownEnd.timeIntervalSinceNow)))
            countdown.stringValue = isLong ? String(format: "%d:%02d", self.countdownRemaining / 60,
                self.countdownRemaining % 60) : "\(self.countdownRemaining)s"
            if self.countdownRemaining == 0 { timer.invalidate(); self.finishBreak() }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    @objc private func finishBreak() {
        guard isBreakVisible else { return }
        showMiniMessage(avatar: "✨", title: "Nice work!", body: "Your eyes say thanks. See you at the next break!")
    }

    private func showWaterPopup() {
        let (p, root) = buddyPanel(title: "Water check!",
                                  body: "You've logged \(waterML) of \(waterGoalML) ml today. Time for a sip?")
        let add = button("+\(waterStepML) ml", action: #selector(addWater))
        add.frame = NSRect(x: 202, y: 58, width: 115, height: 32)
        root.addSubview(add)
        let later = button("Later", action: #selector(dismissPanel))
        later.frame = NSRect(x: 327, y: 58, width: 115, height: 32)
        root.addSubview(later)
        presentBuddy(p)
    }

    @objc private func showEyeBreakNow() {
        nextBreak = Date().addingTimeInterval(shortBreakInterval)
        showBreakPopup()
    }

    @objc private func addWater() { logWater(waterStepML) }
    @objc private func quickAdd(_ sender: NSMenuItem) {
        if let amount = sender.representedObject as? Int { logWater(amount, voluntary: true) }
    }
    @objc private func customAdd() {
        if let amount = askNumber(title: "Log water", message: "Amount in millilitres.",
                                  initial: waterStepML, range: 25...2000) { logWater(amount, voluntary: true) }
    }
    private func logWater(_ amount: Int, voluntary: Bool = false) {
        waterML += amount
        defaults.set(amount, forKey: keyForToday("lastWater"))
        // A voluntary log can celebrate without replacing an active break.
        if isBreakVisible && voluntary {
            pendingWaterDance = true
            if buddyPhase == .presenting { danceDuringBreak() }
        } else if !isBreakVisible {
            showMiniMessage(avatar: waterML >= waterGoalML ? "✨" : "💧",
                            title: "+\(amount) ml logged", body: "\(waterML) / \(waterGoalML) ml today", dance: voluntary)
        }
    }
    private func danceDuringBreak() {
        pendingWaterDance = false
        danceTimer?.invalidate()
        buddyView?.mood = .dance
        danceTimer = Timer(timeInterval: 4.32, repeats: false) { [weak self, weak panel] _ in
            guard let self = self, let panel = panel, self.panel === panel,
                  self.isBreakVisible, self.buddyPhase == .presenting else { return }
            self.buddyView?.mood = .greeting
            self.danceTimer = nil
        }
        RunLoop.main.add(danceTimer!, forMode: .common)
    }

    @objc private func removeWater() {
        let last = defaults.integer(forKey: keyForToday("lastWater"))
        guard last > 0 else { return }
        waterML -= last
        defaults.removeObject(forKey: keyForToday("lastWater"))
    }
    @objc private func showWaterProgress() { showWaterPopup() }

    private func closePanelImmediately() {
        danceTimer?.invalidate()
        danceTimer = nil
        pendingWaterDance = false
        countdownTimer?.invalidate()
        countdownTimer = nil
        motionTimer?.invalidate()
        motionTimer = nil
        peekTimer?.invalidate()
        peekTimer = nil
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        buddyView?.stopAnimating()
        buddyView = nil
        panel?.close()
        panel = nil
        buddyPhase = .hidden
        isBreakVisible = false
    }

    @objc private func dismissPanel() {
        danceTimer?.invalidate()
        danceTimer = nil
        pendingWaterDance = false
        peekTimer?.invalidate()
        peekTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        isBreakVisible = false
        guard let p = panel, buddyPhase != .exiting else { return }
        guard shouldAnimateTransitions else { closePanelImmediately(); return }
        buddyPhase = .exiting
        p.ignoresMouseEvents = true
        setBubbleVisible(false)
        let start = buddyView?.frame.minX ?? 0
        let edge = expandWalkingStage(p)
        buddyView?.mood = .walkRight
        walk(p, from: start, to: edge) { [weak self, weak p] in
            guard let self = self, let p = p, self.panel === p else { return }
            self.closePanelImmediately()
        }
    }
    @objc private func snoozeBreak() {
        // Retry the same short/long break rather than advancing the cadence.
        breakCount = max(0, breakCount - 1)
        dismissPanel()
        breakSnoozed = true
        nextBreak = Date().addingTimeInterval(5 * 60)
    }
    @objc private func pause(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        pausedUntil = Date().addingTimeInterval(Double(minutes * 60))
        dismissPanel()
        updateMenuTitle()
    }
    @objc private func resumeReminders() {
        pausedUntil = nil
        scheduleTimers()
        updateMenuTitle()
    }

    private func scheduleDeparture(_ p: NSPanel, after delay: TimeInterval = 1.4) {
        confirmationTimer?.invalidate()
        confirmationTimer = Timer(timeInterval: delay, repeats: false) { [weak self, weak p] _ in
            guard let self = self, let p = p, self.panel === p else { return }
            self.dismissPanel()
        }
        RunLoop.main.add(confirmationTimer!, forMode: .common)
    }

    private func showMiniMessage(avatar: String, title: String, body: String, dance: Bool = false) {
        danceTimer?.invalidate()
        danceTimer = nil
        pendingWaterDance = false
        // Celebrate in place, then leave. Do not create a second entrance on an action.
        if let p = panel, buddyPhase == .presenting, let root = p.contentView {
            countdownTimer?.invalidate()
            countdownTimer = nil
            isBreakVisible = false
            buddyView?.mood = dance ? .dance : .happy
            for view in root.subviews {
                if let label = view as? NSTextField {
                    switch label.identifier?.rawValue {
                    case "buddyTitle": label.stringValue = title
                    case "buddyMessage": label.stringValue = body
                    default: label.isHidden = true
                    }
                } else if view is NSButton { view.isHidden = true }
            }
            scheduleDeparture(p, after: dance ? 4.32 : 1.4)
        } else {
            let (p, _) = buddyPanel(title: title, body: body, happy: true)
            buddyView?.mood = dance ? .dance : .happy
            presentBuddy(p) { [weak self, weak p] in
                guard let self = self, let p = p, self.panel === p else { return }
                self.scheduleDeparture(p, after: dance ? 4.32 : 1.4)
            }
        }
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = EyeBreakBuddyApp()
app.delegate = delegate
app.run()
