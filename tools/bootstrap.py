#!/usr/bin/env python3
"""Install checksum-locked project CLIs without changing the user's global tools."""
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    lock = json.loads((ROOT / "tools/toolchain.lock.json").read_text())
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise SystemExit("This bootstrap targets the Linux x86_64 cloud workspace.")
    cache = ROOT / ".tools/downloads"
    binaries = ROOT / ".tools/bin"
    cache.mkdir(parents=True, exist_ok=True)
    binaries.mkdir(parents=True, exist_ok=True)
    for tool in lock["tools"]:
        archive = cache / f'{tool["name"]}-{tool["version"]}.zip'
        data = archive.read_bytes() if archive.exists() else b""
        if hashlib.sha256(data).hexdigest() != tool["sha256"]:
            print(f'Downloading {tool["name"]} {tool["version"]}', flush=True)
            # urllib honors the session's HTTPS proxy and CA configuration.
            with urllib.request.urlopen(tool["url"], timeout=120) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != tool["sha256"]:
                raise RuntimeError(f'Checksum mismatch for {tool["name"]}')
            archive.write_bytes(data)
        with zipfile.ZipFile(io.BytesIO(data)) as bundle:
            for name in tool["binaries"]:
                destination = binaries / name
                temporary = binaries / f"{name}.new"
                temporary.write_bytes(bundle.read(name))
                temporary.chmod(0o755)
                os.replace(temporary, destination)
        print(f'Ready: {tool["name"]} {tool["version"]}', flush=True)
    for definition in lock.get("definitions", []):
        path = ROOT / ".tools" / definition["filename"]
        data = path.read_bytes() if path.exists() else b""
        if hashlib.sha256(data).hexdigest() != definition["sha256"]:
            with urllib.request.urlopen(definition["url"], timeout=120) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != definition["sha256"]:
                raise RuntimeError("Roblox definition checksum mismatch")
            path.write_bytes(data)
        print(f'Ready: {definition["filename"]}', flush=True)
    resources = json.loads((ROOT / "tools/resources.lock.json").read_text())
    for resource in resources["resources"]:
        directory = ROOT / ".tools/resources"
        directory.mkdir(exist_ok=True)
        archive = directory / f'{resource["name"]}-{resource["commit"]}.zip'
        data = archive.read_bytes() if archive.exists() else b""
        if hashlib.sha256(data).hexdigest() != resource["sha256"]:
            with urllib.request.urlopen(resource["url"], timeout=120) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != resource["sha256"]:
                raise RuntimeError(f'Checksum mismatch for {resource["name"]}')
            archive.write_bytes(data)
        # Cache only: candidates are never executed or injected into game builds.
        print(f'Cached for review: {resource["name"]} {resource["commit"]}', flush=True)


if __name__ == "__main__":
    main()
