#!/usr/bin/env python3
"""Install the MoisturePilot backup sync agent as a per-user macOS LaunchAgent."""
from __future__ import annotations

import getpass
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path


LABEL = "com.moisturepilot.research-backup"
SOURCE = Path(__file__).with_name("moisturepilot_sync.py")
APP_DIR = Path.home() / "Library" / "Application Support" / "MoisturePilot"
SCRIPT = APP_DIR / "moisturepilot_sync.py"
PLIST = Path.home() / "Library" / "LaunchAgents" / f"{LABEL}.plist"
LOG_DIR = Path.home() / "Library" / "Logs" / "MoisturePilot"


def main() -> int:
    if sys.platform != "darwin":
        raise SystemExit("This installer is for macOS only.")
    if len(sys.argv) < 2:
        raise SystemExit("Usage: python3 install_mac_backup.py https://YOUR-RAILWAY-DOMAIN [BACKUP_FOLDER]")
    api_url = sys.argv[1].rstrip("/")
    if not api_url.startswith("https://"):
        raise SystemExit("The API URL must use HTTPS.")
    backup_dir = Path(sys.argv[2]).expanduser() if len(sys.argv) > 2 else Path.home() / "Documents" / "MoisturePilot Research Backups"
    secret = getpass.getpass("MOISTUREPILOT_OWNER_EXPORT_KEY: ")
    if len(secret) < 32:
        raise SystemExit("The owner key must contain at least 32 characters.")
    subprocess.run(
        ["/usr/bin/security", "add-generic-password", "-U", "-a", getpass.getuser(), "-s", LABEL, "-w", secret],
        check=True,
    )
    APP_DIR.mkdir(parents=True, exist_ok=True)
    PLIST.parent.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    backup_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE, SCRIPT)
    SCRIPT.chmod(0o700)
    payload = {
        "Label": LABEL,
        "ProgramArguments": [sys.executable, str(SCRIPT)],
        "EnvironmentVariables": {"MP_BACKUP_API_URL": api_url, "MP_BACKUP_DIR": str(backup_dir)},
        "RunAtLoad": True,
        "StartInterval": 300,
        "StandardOutPath": str(LOG_DIR / "backup.log"),
        "StandardErrorPath": str(LOG_DIR / "backup-error.log"),
    }
    with PLIST.open("wb") as stream:
        plistlib.dump(payload, stream)
    domain = f"gui/{subprocess.check_output(['/usr/bin/id', '-u'], text=True).strip()}"
    subprocess.run(["/bin/launchctl", "bootout", domain, str(PLIST)], check=False, capture_output=True)
    subprocess.run(["/bin/launchctl", "bootstrap", domain, str(PLIST)], check=True)
    subprocess.run(["/bin/launchctl", "kickstart", "-k", f"{domain}/{LABEL}"], check=True)
    print(f"Installed. Verified research backups will appear in: {backup_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
