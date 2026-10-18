#!/usr/bin/env python3
"""Compile actual application methods with isolated preferences and run checks."""
from pathlib import Path
import subprocess
import os
import shutil
import tempfile
import uuid
root = Path(__file__).resolve().parent.parent
suite = 'EyeBreakBuddy.tests.' + uuid.uuid4().hex
source = (root / 'EyeBreakBuddy.swift').read_text().split('\nlet app = NSApplication.shared')[0]
source = source.replace('UserDefaults.standard', f'UserDefaults(suiteName: "{suite}")!')
checks = (root / 'tests/BehaviorChecks.swift').read_text()
checks += f'\nUserDefaults.standard.removePersistentDomain(forName: "{suite}")\n'
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    shutil.copytree(root / 'Assets', tmp / 'Assets')
    (tmp / 'Checks.swift').write_text(source + '\n' + checks)
    subprocess.run(['swiftc', str(tmp / 'Checks.swift'), '-o', str(tmp / 'Checks'),
                    '-framework', 'Cocoa', '-module-cache-path', os.environ.get('EYEBREAKBUDDY_MODULE_CACHE', str(root / '.build/module-cache'))], check=True)
    result = subprocess.run([str(tmp / 'Checks')], check=True, text=True, capture_output=True)
    print(result.stdout, end='')
    if 'PASS:' not in result.stdout:
        raise RuntimeError('AppKit did not execute the checks. Run in a logged-in macOS desktop session. ' + result.stderr)
