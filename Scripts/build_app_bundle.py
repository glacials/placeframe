#!/usr/bin/env python3
from __future__ import annotations

import argparse
import plistlib
import shutil
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
APP_NAME = 'PhotoLocSyncMac'
INFO_PLIST_TEMPLATE = ROOT / 'Configuration' / 'Info.plist'
DEFAULT_BUNDLE_IDENTIFIER = 'dev.glacials.PhotoLocSyncMac'
DEFAULT_OUTPUT_DIR = ROOT / '.build' / 'bundle'


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Build the PhotoLocSyncMac SwiftPM target and wrap it in a macOS .app bundle.'
    )
    parser.add_argument(
        '--configuration',
        choices=('debug', 'release'),
        default='release',
        help='Swift build configuration to package. Defaults to release.',
    )
    parser.add_argument(
        '--output-dir',
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help='Directory that will receive PhotoLocSyncMac.app. Relative paths resolve from the repo root.',
    )
    parser.add_argument(
        '--bundle-identifier',
        default=DEFAULT_BUNDLE_IDENTIFIER,
        help=f'Bundle identifier written into Info.plist. Defaults to {DEFAULT_BUNDLE_IDENTIFIER}.',
    )
    parser.add_argument(
        '--open',
        action='store_true',
        help='Open the packaged .app in Finder after building it.',
    )
    return parser.parse_args()


def run_command(command: list[str], capture_output: bool = False) -> str:
    print(f"→ {' '.join(command)}", flush=True)
    completed = subprocess.run(
        command,
        cwd=ROOT,
        check=True,
        capture_output=capture_output,
        text=True,
    )
    if capture_output:
        return completed.stdout.strip()
    return ''


def substitute_placeholders(value: Any, substitutions: dict[str, str]) -> Any:
    if isinstance(value, dict):
        return {key: substitute_placeholders(item, substitutions) for key, item in value.items()}
    if isinstance(value, list):
        return [substitute_placeholders(item, substitutions) for item in value]
    if isinstance(value, str):
        return substitutions.get(value, value)
    return value


def build_info_plist(bundle_identifier: str) -> dict[str, Any]:
    with INFO_PLIST_TEMPLATE.open('rb') as file:
        info_plist = plistlib.load(file)

    substitutions = {
        '$(EXECUTABLE_NAME)': APP_NAME,
        '$(PRODUCT_BUNDLE_IDENTIFIER)': bundle_identifier,
        '$(PRODUCT_NAME)': APP_NAME,
    }
    return substitute_placeholders(info_plist, substitutions)


def resolve_output_dir(path: Path) -> Path:
    if path.is_absolute():
        return path
    return ROOT / path


def main() -> int:
    args = parse_args()
    output_dir = resolve_output_dir(args.output_dir)

    run_command(
        ['swift', 'build', '--configuration', args.configuration, '--product', APP_NAME]
    )
    bin_path = Path(
        run_command(
            ['swift', 'build', '--configuration', args.configuration, '--show-bin-path'],
            capture_output=True,
        )
    )
    executable_path = bin_path / APP_NAME
    if not executable_path.exists():
        raise FileNotFoundError(f'Built executable not found at {executable_path}')

    app_bundle_path = output_dir / f'{APP_NAME}.app'
    contents_path = app_bundle_path / 'Contents'
    macos_path = contents_path / 'MacOS'
    resources_path = contents_path / 'Resources'

    if app_bundle_path.exists():
        shutil.rmtree(app_bundle_path)

    macos_path.mkdir(parents=True)
    resources_path.mkdir()
    shutil.copy2(executable_path, macos_path / APP_NAME)

    with (contents_path / 'Info.plist').open('wb') as file:
        plistlib.dump(build_info_plist(args.bundle_identifier), file, sort_keys=False)

    print(f'\nBuilt app bundle: {app_bundle_path}', flush=True)

    if args.open:
        run_command(['open', str(app_bundle_path)])

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
