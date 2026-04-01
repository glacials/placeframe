#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parent.parent
WATCH_PATHS = [
    ROOT / 'App',
    ROOT / 'Sources',
    ROOT / 'Configuration',
    ROOT / 'Package.swift',
]
WATCH_SUFFIXES = {'.swift', '.plist', '.entitlements'}
POLL_INTERVAL = 0.5
DEBOUNCE_SECONDS = 0.35
APP_BINARY = ROOT / '.build' / 'debug' / 'PhotoLocSyncMac'


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Rebuild and relaunch PhotoLocSyncMac whenever source files change.'
    )
    parser.add_argument(
        '--no-tests',
        action='store_true',
        help='Skip the initial test run before starting the hot-reload loop.',
    )
    parser.add_argument(
        'app_args',
        nargs=argparse.REMAINDER,
        help='Arguments forwarded to the PhotoLocSyncMac app binary after --.',
    )
    return parser.parse_args()


def iter_files(paths: Iterable[Path]) -> Iterable[Path]:
    for path in paths:
        if not path.exists():
            continue
        if path.is_file():
            yield path
            continue
        for file_path in path.rglob('*'):
            if file_path.is_file() and file_path.suffix in WATCH_SUFFIXES:
                yield file_path


def snapshot() -> dict[str, float]:
    return {str(path): path.stat().st_mtime for path in iter_files(WATCH_PATHS)}


def changed_files(before: dict[str, float], after: dict[str, float]) -> list[str]:
    changed: list[str] = []
    all_paths = set(before) | set(after)
    for path in sorted(all_paths):
        if before.get(path) != after.get(path):
            changed.append(path)
    return changed


def run_command(command: list[str]) -> bool:
    print(f"\n→ {' '.join(command)}")
    completed = subprocess.run(command, cwd=ROOT)
    return completed.returncode == 0


def launch_app(extra_args: list[str]) -> subprocess.Popen[str]:
    command = [str(APP_BINARY), *extra_args]
    print(f"\n→ launching {' '.join(command)}")
    return subprocess.Popen(command, cwd=ROOT, text=True)


def terminate_process(process: subprocess.Popen[str] | None) -> None:
    if process is None or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def normalize_app_args(args: list[str]) -> list[str]:
    if args and args[0] == '--':
        return args[1:]
    return args


def main() -> int:
    args = parse_args()
    app_args = normalize_app_args(args.app_args)

    if not args.no_tests and not run_command(['swift', 'test']):
        return 1
    if not run_command(['swift', 'build']):
        return 1

    current_process = launch_app(app_args)
    previous_snapshot = snapshot()
    pending_since: float | None = None
    pending_changes: list[str] = []

    def shutdown(_signum: int, _frame: object | None) -> None:
        terminate_process(current_process)
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    while True:
        time.sleep(POLL_INTERVAL)
        new_snapshot = snapshot()
        detected = changed_files(previous_snapshot, new_snapshot)
        previous_snapshot = new_snapshot

        if detected:
            pending_since = time.time()
            pending_changes = detected
            continue

        if pending_since is None:
            continue

        if time.time() - pending_since < DEBOUNCE_SECONDS:
            continue

        print('\nDetected source changes:')
        for path in pending_changes:
            print(f'  - {Path(path).relative_to(ROOT)}')

        if run_command(['swift', 'build']):
            terminate_process(current_process)
            current_process = launch_app(app_args)
        else:
            print('\nBuild failed; keeping the previous app instance running.')

        pending_since = None
        pending_changes = []


if __name__ == '__main__':
    raise SystemExit(main())
