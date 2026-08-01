# MoisturePilot Mac Research Backup

This owner-only agent checks Railway every five minutes. Railway retains runs
while the Mac is asleep or offline. When the Mac reconnects, the agent downloads
every missing completed run, safely extracts it, verifies every SHA-256 checksum
in `manifest.json`, and then moves it into the backup folder.

The owner export key is stored in macOS Keychain, not in the LaunchAgent file.
The Mac does not accept inbound connections or expose a public server.

## Install

First set the same 32-character-or-longer `MOISTUREPILOT_OWNER_EXPORT_KEY` in
Railway. Then run from this directory:

```bash
python3 install_mac_backup.py https://YOUR-RAILWAY-DOMAIN
```

You may provide a different backup destination as the second argument:

```bash
python3 install_mac_backup.py https://YOUR-RAILWAY-DOMAIN "/Volumes/Research/MoisturePilot"
```

The installer prompts for the owner key without displaying it. Backups default
to `~/Documents/MoisturePilot Research Backups`.

## Alerts

Native macOS notifications report:

- Railway service failure and recovery;
- storage crossing 70%, 85%, or 95%;
- workload cost-risk crossing 70%, 85%, or 95% of configured API limits;
- five or more server errors within an hour;
- devices repeatedly receiving quota denials;
- backup or checksum failures;
- successfully verified backups.

Actual dollar spending is controlled by Railway, not inferred by this agent.
In Railway Workspace Usage, set a Custom Email Alert and a Compute Hard Limit.
The API's workload warning is an additional early-warning signal.

Logs are stored in `~/Library/Logs/MoisturePilot/`.
