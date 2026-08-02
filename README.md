# MoisturePilot for FarmBot

**FarmBot users:** follow the complete setup and operating guide in
[`USER_INSTRUCTIONS.md`](USER_INSTRUCTIONS.md).

**Project owner:** automatic verified Mac backups and monitoring are documented
in [`mac_backup/README.md`](mac_backup/README.md).

Experimental FarmBot Lua sequences that capture a full-garden image grid and
produce an RGB garden mosaic with an estimated soil-moisture map using the
private MoisturePilot processing service.

The FarmBot integration always uses the **10 cm model**.

> Research software. RGB moisture values are estimates, not physical sensor
> measurements. Do not use this project as the only control for irrigation,
> crop safety, or equipment safety.

## Included files

```text
lua/full_garden_scan.lua
lua/capture_current_position.lua
lua/open_dashboard.lua
mac_backup/moisturepilot_sync.py
mac_backup/install_mac_backup.py
```

- `full_garden_scan.lua` scans the complete FarmBot garden using FarmBot's
  calibrated photo grid and requests the completed moisture map.
- `capture_current_position.lua` captures and analyzes one camera position for
  setup testing.
- `open_dashboard.lua` sends a fresh secure link to the latest completed scan.

The processing service, trained models, database, deployment configuration,
and server implementation are private and are not included.

## Requirements

- FarmBot OS v15 with Lua sequence support
- A calibrated FarmBot camera
- Internet access from FarmBot

## Configure FarmBot

No separate URL configuration is required. The official MoisturePilot service
URL is included directly in every Lua sequence. The MoisturePilot owner sends a
narrow `MP_DEVICE_ID` and `MP_DEVICE_KEY` privately. Install them once with
`lua/install_credentials.lua`; the scanning sequences never send the FarmBot
account authorization token.

## Run a full-garden scan

1. Create a new FarmBot sequence.
2. Add a Lua command.
3. Copy all of `lua/full_garden_scan.lua` into the command.
4. Save and synchronize the sequence.
5. Confirm the camera is calibrated and the FarmBot work area is clear.
6. Run the sequence.

The sequence uses the manually installed MoisturePilot device credential,
follows FarmBot's official calibrated photo grid, captures each raw image with
its position, reports progress, and asks the service to finalize the result.
FarmBot's standard grid has a 5 mm safety overlap. The service uses FarmBot
coordinates as absolute placement anchors and produces a garden mosaic,
moisture heatmap, moisture overlay, and machine-readable map. FarmBot sends a
single-use secure dashboard link after processing finishes. Opening it creates
a private browser session; no password or access code is required.
That browser remains signed in until sign-out, browser-data removal, credential
rotation, or device revocation.

If the browser session or browser data is lost, run `open_dashboard.lua` from a
saved FarmBot sequence. It creates a new ten-minute, single-use access link; no
password or retained code is required.

If finalization fails, the active scan identifier remains on FarmBot so the
sequence can attempt recovery on a later run.

## Single-position test

Use `lua/capture_current_position.lua` during initial setup. It captures the
current camera view, submits it to the service, and displays the estimated
moisture value returned by the service.

## Credentials and access

Each FarmBot has a different credential. It is bound to the device ID and may
be revoked or rotated by the project owner. A credential appearing in a
screenshot, forum post, issue, or message must be replaced.

During automatic enrollment only, FarmBot sends its built-in authorization
token to the MoisturePilot service over HTTPS. The service forwards it to the
configured official FarmBot API solely to read and verify `/api/device`, then
discards it. Use automatic enrollment only with a trusted MoisturePilot service.

## Current limitations

- The system requires the private MoisturePilot service to be online.
- Output quality depends on camera calibration, a fixed downward-facing camera,
  lighting, image overlap, and unobstructed FarmBot motion.
- Failed individual captures can result in an incomplete garden result.
- This experimental system has not been validated for autonomous irrigation.

## License

The Lua client is available under the MIT License. The private processing
service and trained models are not distributed or licensed by this repository.
