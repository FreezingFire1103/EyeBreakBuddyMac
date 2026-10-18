# Eye Break Buddy for macOS

Updated from the original EyeBreakBuddyMac Swift project. A small native AppKit menu-bar app with an animated Chopper companion, eye-break countdowns, and local daily water tracking. No packages, network access, or browser required.

## Build and run

Requires macOS 11 or later and Apple's Swift command-line tools. This source release builds for your Mac.

1. Quit the old Eye Break Buddy using its menu-bar menu.
2. Double-click `Start.command` (or run `./Start.command` in Terminal). You can close Terminal afterward.

A locally compiled executable for this Apple Silicon Mac is included. To rebuild from source, run `./build.command`. On a different Mac, rebuild before starting.

The eye icon in the menu bar shows today's logged millilitres and goal. Use **Quit Eye Break Buddy** to stop it. Start only one copy at a time. No automatic login item is installed.

Alternatively, build and launch manually:

```sh
swiftc EyeBreakBuddy.swift -o EyeBreakBuddy -framework Cocoa
./EyeBreakBuddy
```

Keep the executable name `EyeBreakBuddy`: this retains the original unbundled app's UserDefaults identity. The daily keys remain `waterML-yyyy-MM-dd`, so the existing daily water totals are preserved when run as the same macOS user. Settings are saved locally and restored at launch.

## Menu controls

- **Water:** quick-add 150, 250, or 500 ml, plus your configured popup amount; add a custom amount; undo the most recent addition once. Undo is scoped to today.
- **Daily goal:** 1.5, 2, 2.5, 3, or 3.5 L presets, or a custom whole-number amount from 250 to 10,000 ml. These input bounds are software limits, not recommendations.
- **Popup quick-add amount:** 100, 150, 250, 330, or 500 ml, or custom 25–2,000 ml. It also becomes a menu quick-add option.
- **Eye interval:** Off, 15, 20, 30, 45, or 60 minutes; custom 1–240 minutes.
- **Long reset:** Off or every 2, 3, 4, or 6 eye breaks. Default: every fourth 20-minute break (80 minutes). The long break has a five-minute countdown, followed by a brief celebration.
- **Water interval:** Off, 30, 45, 60, 90, or 120 minutes; custom 1–240 minutes. Automatic water prompts stop when the day's goal is reached.
- **Pause all reminders:** 5, 15, 30, 60, or 120 minutes; resume early at any time. The pause deadline survives relaunch. On expiry, each reminder starts a fresh interval.
- **Snooze:** the eye-break card retries that same break in five minutes. Water reminders continue unless all reminders are paused.
- **Sound:** optional soft system sound, off by default.
- **Position:** four screen corners or center of the main screen. Applies to the next card.

The Settings menu labels the default recommended goal as **2.5 L/day**. **Water goal guidance…** explains that this is an adjustable starting goal, needs vary by heat/activity, and fluids from food and other beverages contribute. The tracker counts only amounts you explicitly log; it does not estimate food intake.

Water totals roll over by the Mac's local calendar date, with the menu-bar display refreshed within a second while awake. Old daily totals stay stored locally. Reminders restart their intervals after waking, avoiding a backlog of missed alerts. A water reminder waits while an eye-break card is visible. Logging water from a break card preserves its countdown.

## Validation

Run `python3 tests/run_tests.py` to compile and exercise the actual application methods using an isolated temporary preferences suite. It checks settings and storage compatibility, add/undo, pause/resume, snooze, disabled reminders, simultaneous reminders, goal suppression, and daily display refresh. Requires a logged-in macOS desktop session.

Verified on this Mac: Swift compilation and all included behavior checks passed. Visual placement on additional monitors and overnight real-time rollover were not manually observed.

## Chopper companion update

Keep the `Assets` folder beside the `EyeBreakBuddy` executable. The buddy uses a transparent four-pose sprite sheet based on your supplied character reference. He waves when a reminder appears, blinks while waiting, gently bobs, and celebrates after Done or a completed countdown. Water reminders and logged-water confirmations use the same companion.

The character appears only for reminders and confirmations, rather than remaining on the desktop all day. Animations stop when the popup closes. macOS Reduce Motion disables bobbing, entrance motion, and pose cycling. Existing position settings still apply. All water and reminder settings retain their original storage keys.

Try **Take eye break now** in the menu to see Chopper immediately. **Done**, **Snooze 5m**, and the configured water quick-add remain available. Long and short breaks now both celebrate and dismiss automatically when their countdown finishes.

Verification for this update: Swift compilation and behavior checks passed, including transparent artwork loading, animation cleanup, and celebration state. The native reminder and celebration were visually checked, and water logging was checked while the countdown continued. The temporary preview used separate preferences from your real app.

## Walk-in / walk-out update

For eye breaks and water reminders, Chopper now walks in from the right edge of the screen using a dedicated two-frame walking cycle. He stops at your configured popup position, then the speech bubble appears. Break countdowns begin after arrival.

Done and completed countdowns show a brief happy reaction before he walks back out to the right. Snooze, Later, and Pause make him leave immediately. Logging water from a water reminder confirms the amount in place, then sends him out; adding water during an eye break continues to preserve that break's countdown.

The walking stage stays clipped to its screen so Chopper does not cross into another monitor. The stage ignores mouse clicks while he is entering or leaving. macOS Reduce Motion presents/dismisses him without walking. Movement and confirmation timers are cancelled when a reminder is replaced, preventing an old animation from closing a new one.

Keep both sprite files in Assets beside the executable. The original settings and water totals are unchanged.

Walking update validation: compilation and the full behavior suite passed, including real timed entrance/exit, countdown-after-arrival, in-place celebration, and replacement during departure. The native arrival/reminder and right-facing departure were visually checked.

## Slower walk and hiding pose

Chopper's travel speed is now 140 points/second instead of 330 (about 58% slower), with a gentler 0.32-second step frame. Before entering, he spends 1.8 seconds at the right edge in a custom backward-hiding pose: part of his head is concealed while his body remains exposed. He then walks to the reminder position and starts the countdown. Both entrance and exit use the slower speed.

The hiding delay respects Reduce Motion and is cancelled on dismissal/replacement. Keep `chopper-hide.png` with the two other sprite assets. The updated preview uses separate test preferences.

Validation: Swift compilation and all behavior checks passed, including the hiding delay, countdown start after arrival, and cancellation during hiding. Hiding and arrival were visually checked in the native preview.

## Run → grip the edge → walk in

The latest entrance has three distinct stages: a short, fast approach from the right (0.6 seconds, with a faster stride and bounce), a 2.2-second screen-edge grip using the corrected pose, and the slower 140-points/second walk to the reminder. The supplied anime collage informed only the pose; the teal hat, striped shirt, orange shorts, and backpack are retained. The break countdown starts after all three stages.

The new pose lives in `Assets/chopper-edge-hold.png`. Keep the Assets folder alongside the executable. Each sprite is rendered on its own transparent layer to prevent trails during movement. The sequence and timer cancellation passed the behavior checks; compilation and native visual checks also passed.

## Grip anatomy and leg-pose correction

The edge-holding sprite now has separate near and far arms connected to opposite shoulders, with the far hoof beside the cheek. One leg is planted and the other extends outward to the left, matching the supplied pose reference. The outfit is unchanged. Screen-edge alignment was adjusted to keep both gripping hooves visible. Compilation and a native pose inspection passed; the entrance sequence and existing reminder logic are unchanged.

The extended hoof now rests on the same baseline as the planted hoof, forming a wide grounded stance. This is an artwork-only correction, visually checked in the native pose preview. Animation behavior is unchanged.

## 90% character size

Chopper is uniformly scaled to 90% of his previous size in every pose. The speech bubble, text, and buttons keep their previous size. The edge-grip position scales with him, and a small vertical adjustment keeps his hooves at the same floor line. The updated app compiles successfully.

## Blink alignment fix

The atlas's blink pose was offset 77 source pixels horizontally relative to the idle pose. Drawing now aligns the foot center and ground line of idle, blink, wave, and celebration poses instead of aligning their padded cells. Idle bobbing is removed, so the character stays still during blinking; celebration motion is retained. The artwork and 90% character scale are unchanged. A regression check independently measures foot pixels in the atlas and verifies that the production drawing rectangles keep all poses within 0.25 points of the same foot position.
