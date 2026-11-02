#!/usr/bin/env python3
"""Run real combat regressions; reject Godot script errors even on exit code zero."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CHECKS = [
    (['--script', 'res://tools/combat_rules_check.gd'], 'COMBAT RULES PASS'),
    (['--', '--smoke-test'], 'MEME BRAWL SMOKE PASS'),
    (['--script', 'res://tools/combo_check.gd'], 'COMBO PASS'),
    (['--script', 'res://tools/roles_check.gd'], 'ROLES PASS'),
    (['--script', 'res://tools/controls_check.gd'], 'CONTROLS PASS'),
    (['--script', 'res://tools/home_stages_check.gd'], 'HOME STAGES PASS'),
    (['--script', 'res://tools/character_audio_check.gd'], 'CHARACTER AUDIO PASS'),
    (['--script', 'res://tools/effects_check.gd'], 'EFFECTS PASS'),
]

def main():
    for arguments, marker in CHECKS:
        try:
            result = subprocess.run(['sh', 'run.sh', '--headless', '--audio-driver', 'Dummy', *arguments],
                                    cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, timeout=60)
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b''
            print(output.decode(errors='replace') if isinstance(output, bytes) else output)
            print(f'FAIL: {marker} timed out', file=sys.stderr)
            return 1
        if result.returncode or marker not in result.stdout or 'SCRIPT ERROR' in result.stdout or 'ERROR:' in result.stdout:
            print(result.stdout)
            print(f'FAIL: {marker} (exit {result.returncode})', file=sys.stderr)
            return 1
        print(next(line for line in result.stdout.splitlines() if marker in line), flush=True)
    print(f'COMBAT VALIDATION PASS: {len(CHECKS)} suites, no script errors', flush=True)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
