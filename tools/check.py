#!/usr/bin/env python3
"""Verify actual tool behavior, including failure propagation; no Roblox login."""
import argparse
import json
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / ".tools/bin"


def run(*args):
    print("+", " ".join(map(str, args)), flush=True)
    subprocess.run([str(a) for a in args], cwd=ROOT, check=True, timeout=180)


def negative(binary, source, expected):
    with tempfile.TemporaryDirectory(prefix="luau-negative-") as temporary:
        path = Path(temporary) / "invalid.luau"
        path.write_text(source)
        result = subprocess.run(
            [str(BIN / binary), *({"lune": ["run"]}.get(binary, [])), str(path)],
            cwd=ROOT, capture_output=True, text=True, timeout=30,
        )
        output = result.stdout + result.stderr
        if result.returncode == 0 or expected not in output:
            raise RuntimeError(f"{binary} failed negative control: {output}")
        print(f"PASS: {binary} rejects intentionally invalid input", flush=True)


def code():
    destination = ROOT / "artifacts/code"
    destination.mkdir(parents=True, exist_ok=True)
    run(BIN / "stylua", "--check", "tests/tooling", "tests/roblox")
    run(BIN / "selene", "tests/tooling")
    # Standalone analyzer has no Roblox/Lune service definitions. Check portable code only.
    run(BIN / "luau-analyze", "--mode=strict", "tests/tooling/Config.luau")
    run(BIN / "luau-lsp", "analyze", "--platform", "roblox", "--definitions",
        ".tools/robloxTypes.d.luau", "tests/roblox/Api.server.luau")
    with tempfile.TemporaryDirectory(prefix="roblox-api-negative-") as temporary:
        path = Path(temporary) / "invalid.server.luau"
        path.write_text('--!strict\nlocal part = Instance.new("Part")\npart.Anchored = "wrong"\n')
        result = subprocess.run([str(BIN / "luau-lsp"), "analyze", "--platform", "roblox",
                                 "--definitions", ".tools/robloxTypes.d.luau", str(path)],
                                cwd=ROOT, capture_output=True, text=True, timeout=30)
        if result.returncode == 0 or "TypeError" not in result.stdout + result.stderr:
            raise RuntimeError("Roblox API type error was not detected")
        print("PASS: Roblox-aware static analysis rejects wrong property type", flush=True)
    for place in ("lobby", "match"):
        tree = {
            "$className": "DataModel",
            "ReplicatedStorage": {"Shared": {"$className": "Folder", "Config": {
                "$path": "../../tests/tooling/Config.luau"}}},
            "ServerScriptService": {"Main": {"$path": "../../tests/tooling/Main.server.luau"}},
            "StarterPlayer": {"StarterPlayerScripts": {
                "Main": {"$path": "../../tests/tooling/Main.client.luau"}}},
            "Workspace": {"$properties": {"StreamingEnabled": True}, "Floor": {
                "$className": "Part", "$properties": {"Anchored": True, "Size": [128, 1, 128]}}},
        }
        project = destination / f"{place}.project.json"
        project.write_text(json.dumps({"name": place + "-toolchain-fixture", "tree": tree}, indent=2))
        run(BIN / "rojo", "build", project, "--output", destination / f"{place}.rbxl")
        run(BIN / "rojo", "sourcemap", project, "--output", destination / f"{place}.sourcemap.json")
    run(BIN / "lune", "run", "tests/tooling/verify.luau")
    negative("lune", 'assert(false, "expected-test-failure")\n', "expected-test-failure")
    negative("luau-analyze", '--!strict\nlocal value: number = "wrong"\nprint(value)\n', "TypeError")
    negative("selene", 'print(unknownToolchainVariable)\n', "undefined_variable")
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    # Loopback only: this is an internal CLI check, not a Studio connection.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with (destination / "rojo-serve.log").open("w+") as log:
        process = subprocess.Popen(
            [str(BIN / "rojo"), "serve", str(destination / "lobby.project.json"),
             "--address", "127.0.0.1", "--port", str(port)], cwd=ROOT, stdout=log, stderr=log)
        try:
            for _ in range(50):
                if process.poll() is not None:
                    log.seek(0)
                    raise RuntimeError(log.read())
                try:
                    with opener.open(f"http://127.0.0.1:{port}/api/rojo", timeout=2) as response:
                        if response.status != 200 or not response.read():
                            raise RuntimeError("Empty Rojo protocol response")
                    print("PASS: Rojo loopback protocol responds", flush=True)
                    break
                except OSError:
                    time.sleep(0.1)
            else:
                raise RuntimeError("Rojo server did not become ready")
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def assets():
    for executable in ("blender", "ffmpeg", "ffprobe"):
        if not shutil.which(executable):
            raise RuntimeError(f"Missing system tool: {executable}")
    run("blender", "--background", "--factory-startup", "--threads", "2", "--python-exit-code", "1",
        "--python", ROOT / "tools/model_probe.py")
    destination = ROOT / "artifacts/assets"
    run("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i",
        "sine=frequency=440:duration=0.25", "-ar", "48000", destination / "audio-probe.wav")
    run("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-loop", "1", "-i",
        destination / "preview.png", "-t", "1", "-c:v", "libx264", "-pix_fmt", "yuv420p",
        destination / "preview.mp4")
    for path in (destination / "audio-probe.wav", destination / "preview.mp4"):
        result = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                 "-of", "json", str(path)], check=True, capture_output=True, text=True)
        assert float(json.loads(result.stdout)["format"]["duration"]) > 0
    print("PASS: mesh, UV, texture, rig, animation, FBX round trip, render, audio and video pipeline")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", action="store_true", help="Also exercise Blender and FFmpeg")
    args = parser.parse_args()
    code()
    if args.assets:
        assets()
    print("PASS: toolchain checks completed; no Roblox engine or service tests were run")


if __name__ == "__main__":
    main()
