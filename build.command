#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
mkdir -p .build/module-cache
swiftc EyeBreakBuddy.swift -o EyeBreakBuddy -framework Cocoa -module-cache-path .build/module-cache
print 'Built EyeBreakBuddy. Quit any older copy, then double-click Start.command.'
