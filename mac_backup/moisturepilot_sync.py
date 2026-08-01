#!/usr/bin/env python3
"""Pull completed MoisturePilot research runs to this Mac and verify checksums."""
from __future__ import annotations

import hashlib
import json
import os
import plistlib
import shutil
import stat
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath


KEYCHAIN_SERVICE = "com.moisturepilot.research-backup"
API_URL = os.environ["MP_BACKUP_API_URL"].rstrip("/")
BACKUP_DIR = Path(os.environ.get("MP_BACKUP_DIR", "~/Documents/MoisturePilot Research Backups")).expanduser()
STATE_PATH = BACKUP_DIR / ".moisturepilot-sync-state.json"


def notify(title: str, message: str) -> None:
    script = 'on run argv\ndisplay notification (item 2 of argv) with title (item 1 of argv)\nend run'
    subprocess.run(["/usr/bin/osascript", "-e", script, title, message], check=False)


def owner_key() -> str:
    result = subprocess.run(
        ["/usr/bin/security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
        check=True, capture_output=True, text=True,
    )
    return result.stdout.strip()


def request(path: str, *, binary: bool = False):
    call = urllib.request.Request(
        f"{API_URL}{path}", headers={"X-Owner-Export-Key": owner_key(), "User-Agent": "MoisturePilot-Mac-Backup/1.0"}
    )
    with urllib.request.urlopen(call, timeout=180) as response:
        return response.read() if binary else json.load(response)


def load_state() -> dict:
    if not STATE_PATH.is_file():
        return {"runs": {}, "alerts": {}, "service_down": False}
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {"runs": {}, "alerts": {}, "service_down": False}


def save_state(state: dict) -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    temporary = STATE_PATH.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")
    temporary.replace(STATE_PATH)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_extract(archive_path: Path, destination: Path) -> None:
    with zipfile.ZipFile(archive_path) as archive:
        for info in archive.infolist():
            path = PurePosixPath(info.filename)
            mode = info.external_attr >> 16
            if path.is_absolute() or ".." in path.parts or stat.S_ISLNK(mode):
                raise ValueError(f"Unsafe ZIP member: {info.filename}")
        archive.extractall(destination)


def verify_run(run_dir: Path, expected_manifest_hash: str) -> None:
    manifest_path = run_dir / "manifest.json"
    if not manifest_path.is_file() or sha256_file(manifest_path) != expected_manifest_hash:
        raise ValueError("Manifest is missing or does not match the server")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for entry in manifest.get("files", []):
        relative = PurePosixPath(entry["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("Unsafe manifest path")
        path = run_dir.joinpath(*relative.parts)
        if not path.is_file():
            raise ValueError(f"Missing archived file: {relative}")
        if path.stat().st_size != entry["bytes"] or sha256_file(path) != entry["sha256"]:
            raise ValueError(f"Checksum failure: {relative}")
    if not (run_dir / "research_report.pdf").is_file():
        raise ValueError("Research PDF is missing")


def install_download(run: dict) -> None:
    run_id = run["run_id"]
    payload = request(f"/v1/farmbot/owner/runs/{urllib.parse.quote(run_id, safe='')}/download", binary=True)
    with tempfile.TemporaryDirectory(prefix="moisturepilot-sync-", dir=BACKUP_DIR) as temporary_name:
        temporary = Path(temporary_name)
        zip_path = temporary / "run.zip"
        zip_path.write_bytes(payload)
        extracted = temporary / "extracted"
        extracted.mkdir()
        safe_extract(zip_path, extracted)
        source = extracted / run_id
        verify_run(source, run["manifest_sha256"])
        destination = BACKUP_DIR / run_id
        if destination.exists():
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            destination.rename(BACKUP_DIR / f"{run_id}.previous-{stamp}")
        shutil.move(str(source), str(destination))


def threshold_alerts(state: dict, label: str, value: float) -> None:
    key = f"{label}_thresholds"
    sent = set(state["alerts"].get(key, []))
    active = {threshold for threshold in (70, 85, 95) if value >= threshold}
    for threshold in sorted(active - sent):
        notify("MoisturePilot warning", f"{label} reached {value:.1f}% (threshold {threshold}%).")
    state["alerts"][key] = sorted(active)


def process_status(state: dict, status_payload: dict) -> None:
    threshold_alerts(state, "Railway storage", float(status_payload["storage"]["used_percent"]))
    threshold_alerts(state, "Workload cost risk", float(status_payload["workload_cost_risk_percent"]))
    errors = int(status_payload.get("errors_last_hour", 0))
    if errors >= 5 and not state["alerts"].get("high_errors"):
        notify("MoisturePilot error rate", f"The API recorded {errors} server errors in the last hour.")
    state["alerts"]["high_errors"] = errors >= 5
    quota_devices = {str(item["device_id"]) for item in status_payload.get("devices_repeatedly_hitting_quotas", [])}
    previous = set(state["alerts"].get("quota_devices", []))
    for device_id in sorted(quota_devices - previous):
        notify("MoisturePilot quota warning", f"Device {device_id} repeatedly reached an API quota.")
    state["alerts"]["quota_devices"] = sorted(quota_devices)


def main() -> int:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    state = load_state()
    try:
        status_payload = request("/v1/farmbot/owner/status")
        listing = request("/v1/farmbot/owner/runs")
        if state.get("service_down"):
            notify("MoisturePilot restored", "The Railway service is reachable again.")
        state["service_down"] = False
        process_status(state, status_payload)
    except Exception as exc:
        if not state.get("service_down"):
            notify("MoisturePilot unavailable", f"The Railway service could not be reached: {type(exc).__name__}")
        state["service_down"] = True
        save_state(state)
        return 1

    for run in listing.get("runs", []):
        if not run.get("backup_ready") or not run.get("manifest_sha256"):
            continue
        if state["runs"].get(run["run_id"]) == run["manifest_sha256"]:
            continue
        try:
            install_download(run)
            state["runs"][run["run_id"]] = run["manifest_sha256"]
            state["alerts"].pop(f"backup_failed:{run['run_id']}", None)
            notify("MoisturePilot backup complete", f"Research run {run['run_id']} was saved and verified.")
        except Exception as exc:
            failure_key = f"backup_failed:{run['run_id']}"
            if not state["alerts"].get(failure_key):
                notify("MoisturePilot backup failed", f"Run {run['run_id']} failed verification: {type(exc).__name__}")
            state["alerts"][failure_key] = True
    save_state(state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
