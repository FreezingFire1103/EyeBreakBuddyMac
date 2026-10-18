# Eye Break Buddy for macOS

A lightweight native Swift/AppKit menu-bar app for eye breaks and daily water tracking, with an animated Chopper companion. No browser, server, or third-party packages are required.

## Start the app

1. Quit any older copy of Eye Break Buddy.
2. Keep the entire repository together, including `Assets/`.
3. Double-click `Start.command`, or run `./Start.command` in Terminal.

A locally built Apple Silicon executable is included. To rebuild on another Mac, install Apple's command-line developer tools and run:

```sh
./build.command
./Start.command
```

The app requires macOS 11 or later. Close Terminal after launch if desired; the app stays in the menu bar. Start only one copy. Quit using its menu-bar menu. No login item is installed automatically.

## What it does

- Short eye breaks every 20 minutes by default; a five-minute reset every fourth break.
- Water reminders every 60 minutes by default, with a configurable 2.5 L/day starting goal.
- Water presets, custom amounts, quick-add controls, and undo for the latest addition.
- Configurable intervals, long-reset frequency, goal, popup quick-add amount, sound, position, pause, and snooze.
- Local daily water totals and saved settings through macOS UserDefaults.

The water guidance in Settings explains that needs vary by heat/activity and that fluids from food and other beverages contribute. The app counts only what you log.

## Chopper animation

Chopper runs up to the right edge, grips it for 2.2 seconds in his backwards-hiding pose, then walks slowly to the reminder. His extended leg is grounded. The countdown starts after arrival. Done, Snooze, Later, and completed breaks lead to departure; completion and water confirmations include a happy reaction. Logging water during an eye break keeps its countdown running.

The character is at 90% of the original size. Idle and blink frames are registered to the same foot position, so blinking does not shift him sideways. macOS Reduce Motion disables travel and pose cycling.

## Repository contents

- `EyeBreakBuddy.swift`: complete native application source.
- `EyeBreakBuddy`: locally built Apple Silicon executable.
- `Assets/`: transparent sprites, generation prompts, and supplied outfit/pose references.
- `build.command` / `Start.command`: build and launch scripts.
- `tests/`: behavior and sprite-registration regression checks.
- `docs/DEVELOPMENT_HISTORY.md`: original documentation and development notes.

## Checks

```sh
python3 tests/run_tests.py
```

Tests compile the actual application code and run with a temporary, isolated preferences suite. A logged-in macOS desktop session is required. They check data compatibility, water controls, reminder scheduling, pause/snooze, animation lifecycle, countdown timing, and measured sprite alignment.

## Restoring on another Mac

Clone this repository, rebuild, and launch it. Keep the executable name `EyeBreakBuddy` to preserve compatibility with its original preference domain.

This repository backs up the app and artwork. Personal water totals and settings remain in macOS UserDefaults on the device; they are not part of the Git repository.

## Voluntary water celebration

Menu-bar quick-add and custom water logs bring Chopper directly in, skipping the hiding pose, for a 4.32-second
folded-arm, bashful side-to-side dance, then he walks away. During an active eye
break he dances in place without resetting or stopping the countdown. Repeated
logs refresh the celebration. Popup water buttons retain the short happy reaction.
Reduce Motion shows a still dance pose and skips travel.

Dance movement reference: https://tenor.com/en-GB/view/happy-dance-moves-anime-one-piece-chopper-gif-22319328
The two transparent poses keep the existing outfit and are registered at a common floor line.
