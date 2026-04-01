#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path

BASE_LAT = 35.6804
BASE_LON = 139.7690


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create an anonymized Google Timeline export fixture.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    return parser.parse_args()


def read_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def isoformat_millis(value: dt.datetime) -> str:
    text = value.isoformat(timespec="milliseconds")
    if text.endswith("+00:00"):
        return text.replace("+00:00", "Z")
    return text


def parse_timestamp(value: str) -> dt.datetime:
    normalized = value.replace("Z", "+00:00")
    return dt.datetime.fromisoformat(normalized)


def stable_token(prefix: str, raw: str) -> str:
    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]
    return f"{prefix}_{digest}"


def anonymize_geo(raw: str) -> str:
    prefix, _, payload = raw.partition(":")
    digest = hashlib.sha256(payload.encode("utf-8")).digest()
    lat_offset = int.from_bytes(digest[:4], "big") / 2**32
    lon_offset = int.from_bytes(digest[4:8], "big") / 2**32
    latitude = BASE_LAT + (lat_offset - 0.5) * 0.6
    longitude = BASE_LON + (lon_offset - 0.5) * 0.6
    return f"{prefix or 'geo'}:{latitude:.6f},{longitude:.6f}"


def main() -> None:
    args = parse_args()
    payload = read_json(args.input)
    if not isinstance(payload, list):
        raise SystemExit("Expected top-level array in Timeline export")

    earliest = min(parse_timestamp(item["startTime"]) for item in payload)
    base = dt.datetime(2024, 1, 5, 8, 0, 0, tzinfo=earliest.tzinfo)

    geo_cache: dict[str, str] = {}
    id_cache: dict[str, str] = {}

    def map_geo(raw: str) -> str:
        return geo_cache.setdefault(raw, anonymize_geo(raw))

    def map_id(raw: str, prefix: str) -> str:
        return id_cache.setdefault(f"{prefix}:{raw}", stable_token(prefix, raw))

    def shifted_timestamp(raw: str) -> str:
        original = parse_timestamp(raw)
        shifted = base + (original - earliest)
        return isoformat_millis(shifted)

    anonymized = []
    for entry in payload:
        clone = dict(entry)
        clone["startTime"] = shifted_timestamp(entry["startTime"])
        clone["endTime"] = shifted_timestamp(entry["endTime"])

        if isinstance(entry.get("visit"), dict):
            visit = dict(entry["visit"])
            top_candidate = dict(visit.get("topCandidate", {}))
            if isinstance(top_candidate.get("placeLocation"), str):
                top_candidate["placeLocation"] = map_geo(top_candidate["placeLocation"])
            if isinstance(top_candidate.get("placeID"), str):
                top_candidate["placeID"] = map_id(top_candidate["placeID"], "place")
            visit["topCandidate"] = top_candidate
            clone["visit"] = visit

        if isinstance(entry.get("activity"), dict):
            activity = dict(entry["activity"])
            for key in ("start", "end"):
                if isinstance(activity.get(key), str) and ":" in activity[key]:
                    activity[key] = map_geo(activity[key])
            clone["activity"] = activity

        if isinstance(entry.get("timelinePath"), list):
            path_entries = []
            for path_item in entry["timelinePath"]:
                path_clone = dict(path_item)
                if isinstance(path_clone.get("point"), str):
                    path_clone["point"] = map_geo(path_clone["point"])
                path_entries.append(path_clone)
            clone["timelinePath"] = path_entries

        if isinstance(entry.get("timelineMemory"), dict):
            memory = dict(entry["timelineMemory"])
            destinations = []
            for destination in memory.get("destinations", []):
                destination_clone = dict(destination)
                if isinstance(destination_clone.get("identifier"), str):
                    destination_clone["identifier"] = map_id(destination_clone["identifier"], "destination")
                destinations.append(destination_clone)
            memory["destinations"] = destinations
            clone["timelineMemory"] = memory

        anonymized.append(clone)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        json.dump(anonymized, handle, indent=2)
        handle.write("\n")


if __name__ == "__main__":
    main()
