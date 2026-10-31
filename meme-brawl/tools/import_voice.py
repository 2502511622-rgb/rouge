#!/usr/bin/env python3
"""Trim a user-selected original recording and record provenance, without scraping sites."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import tempfile

CHARACTERS = ("gugu", "dog", "cat", "naiwa", "niulai", "kangaroo")
EVENTS = ("intro", "taunt", "win", "v", "special", "ca", "trigger", "hit", "block", "swing")


def import_voice(source, output_dir, character, event, start, duration, source_url, credit, replace=False):
    source = Path(source).resolve(strict=True)
    output_dir = Path(output_dir)
    if character not in CHARACTERS or event not in EVENTS:
        raise ValueError("Unknown character or event")
    if not math.isfinite(start) or not math.isfinite(duration) or start < 0 or not 0 < duration <= 30:
        raise ValueError("Start must be >= 0 and duration must be within (0, 30] seconds")
    if not source_url.startswith(("https://", "http://")) or not credit.strip():
        raise ValueError("Provide the actual source publication URL and creator credit")
    output_dir.mkdir(parents=True, exist_ok=True)
    target = output_dir / f"{character}_{event}.ogg"
    manifest_path = output_dir / "sources.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"recordings": {}}
    if target.exists() and not replace:
        raise FileExistsError(f"Preserving {target}; use --replace explicitly")
    with tempfile.TemporaryDirectory(dir=output_dir) as work:
        clip = Path(work) / "clip.ogg"
        subprocess.run([
            "ffmpeg", "-nostdin", "-v", "error", "-ss", str(start), "-i", str(source),
            "-t", str(duration), "-vn", "-af", "loudnorm=I=-18:TP=-2:LRA=9,afade=t=in:d=0.015",
            "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", str(clip),
        ], check=True)
        info = json.loads(subprocess.check_output([
            "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(clip)
        ]))
        actual_duration = float(info["format"]["duration"])
        if actual_duration <= 0.02:
            raise ValueError("The selected segment contains no usable audio")
        digest = hashlib.sha256(clip.read_bytes()).hexdigest()
        manifest["recordings"][target.name] = {
            "source_url": source_url, "credit": credit,
            "start_seconds": start, "duration_seconds": actual_duration,
            "sha256": digest, "type": "user_selected_recording",
            "note": "Source is user supplied; not independently authenticated or a license declaration.",
        }
        pending = Path(work) / "sources.json"
        pending.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        clip.replace(target)
        pending.replace(manifest_path)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="A local original audio/video file")
    parser.add_argument("--character", choices=CHARACTERS, required=True)
    parser.add_argument("--event", choices=EVENTS, required=True)
    parser.add_argument("--start", type=float, default=0)
    parser.add_argument("--duration", type=float, required=True)
    parser.add_argument("--source-url", required=True)
    parser.add_argument("--credit", required=True)
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parents[1] / "assets/audio")
    args = parser.parse_args()
    print(import_voice(args.input, args.output_dir, args.character, args.event, args.start,
                       args.duration, args.source_url, args.credit, args.replace))


if __name__ == "__main__":
    main()
