#!/usr/bin/env python3
"""Install the pinned Blender used for the stand morph meshes into .tools/blender (Linux x86_64).

The SHA-256 below matches blender.org's published blender-4.3.2.sha256 file.
"""
import hashlib
from pathlib import Path
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
URL = "https://download.blender.org/release/Blender4.3/blender-4.3.2-linux-x64.tar.xz"
SHA256 = "4da1c956673c0485e63054e563ee69198cc8f80d8157dd7592dffc8a6a5592e6"
BLENDER = ROOT / ".tools/blender/blender-4.3.2-linux-x64/blender"


def main():
    if BLENDER.exists():
        print(f"Ready: {BLENDER}")
        return
    target = ROOT / ".tools/blender"
    target.mkdir(parents=True, exist_ok=True)
    archive = target / "blender-4.3.2-linux-x64.tar.xz"
    print("Downloading Blender 4.3.2 (~370 MB)", flush=True)
    with urllib.request.urlopen(URL, timeout=600) as response, archive.open("wb") as out:
        digest = hashlib.sha256()
        while chunk := response.read(1 << 20):
            digest.update(chunk)
            out.write(chunk)
    if digest.hexdigest() != SHA256:
        archive.unlink()
        raise SystemExit("Blender checksum mismatch")
    with tarfile.open(archive) as bundle:
        bundle.extractall(target, filter="data")
    archive.unlink()
    print(f"Ready: {BLENDER}")


if __name__ == "__main__":
    main()
