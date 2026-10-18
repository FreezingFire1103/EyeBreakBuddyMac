#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
if [[ ! -x EyeBreakBuddy || EyeBreakBuddy.swift -nt EyeBreakBuddy ]]; then
  ./build.command
fi
mkdir -p .build
nohup ./EyeBreakBuddy > .build/launch.log 2>&1 < /dev/null &
print 'Eye Break Buddy started. Use its eye icon in the menu bar to change settings or quit.'
