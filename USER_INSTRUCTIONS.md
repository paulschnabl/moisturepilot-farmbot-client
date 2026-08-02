# MoisturePilot FarmBot User Instructions

MoisturePilot photographs your FarmBot garden and creates an estimated
soil-moisture heatmap, RGB garden mosaic, moisture overlay, and downloadable
numeric map.

> **Important:** MoisturePilot estimates moisture from camera images. It is not
> a physical moisture sensor. Do not use it as the only control for irrigation,
> crop protection, or equipment safety.

## 1. Add the camera test sequence

Before scanning the complete garden, test one camera position:

1. Create a sequence named **MoisturePilot Camera Test**.
2. Add one **Lua** step.
3. Copy the complete contents of
   [`lua/capture_current_position.lua`](lua/capture_current_position.lua) into
   the Lua step.
4. Save and synchronize the sequence.
5. Move FarmBot to a safe position above visible soil.
6. Run the sequence.

Before the first run, install the private `MP_DEVICE_ID` and `MP_DEVICE_KEY`
provided by the MoisturePilot owner using `lua/install_credentials.lua`. This
credential grants access only to MoisturePilot; the sequences do not transmit
your FarmBot account authorization token.

A successful camera test displays an estimated moisture value.

## 2. Add the full-garden scan

1. Create a sequence named **MoisturePilot Full Garden Scan**.
2. Add one **Lua** step.
3. Copy the complete contents of
   [`lua/full_garden_scan.lua`](lua/full_garden_scan.lua) into the Lua step.
4. Save and synchronize the sequence.

The sequence uses FarmBot's official `photo_grid()` positions and standard 5 mm
safety overlap. Each photograph is captured in raw form and sent directly to
MoisturePilot instead of being uploaded to the FarmBot web app.

## 3. Run the full scan

Run **MoisturePilot Full Garden Scan**.

FarmBot will automatically:

1. Create or resume a scan.
2. Ask FarmBot's calibrated `photo_grid()` for the standard garden route.
3. Move to each FarmBot-calculated camera position.
4. Capture and upload a raw image.
5. Retry an upload once if necessary.
6. Place photographs using FarmBot's calibrated coordinates.
7. Generate the moisture map, RGB mosaic, heatmap, and overlay.
8. Send a secure dashboard link to FarmBot messages.

If the sequence stops before finalization, run the same sequence again. It will
attempt to resume the saved scan.

## 4. Open the dashboard

After a successful scan, find this message in the FarmBot logs:

```text
Secure results: https://...
```

1. Open the link within ten minutes.
2. Select **Open dashboard**.
3. Review the heatmap, RGB mosaic, moisture overlay, scan history, and numeric
   map download.

The login link works once and expires after ten minutes. After opening it, the
browser remains signed in until you sign out, clear browser data, or the project
owner revokes access.

## 5. Get a new dashboard link

To open the dashboard on another browser or after clearing browser data:

1. Create a sequence named **Open MoisturePilot Dashboard**.
2. Add one **Lua** step.
3. Copy the complete contents of
   [`lua/open_dashboard.lua`](lua/open_dashboard.lua) into the Lua step.
4. Save, synchronize, and run it.

FarmBot sends a new secure link to the latest completed scan after exiting the tab. No password or access code is required.

## Troubleshooting

### `Lua function "http" is not implemented`

The sequence is running in a FarmBot demo account or another environment that
does not provide the FarmBot OS HTTP client. Run it on a synchronized, online,
physical FarmBot.

### `credentials missing`

- Run the one-time `lua/install_credentials.lua` sequence using the device ID
  and key supplied privately by the MoisturePilot owner.
- Do not post the device key or your FarmBot authorization token publicly.

### `Scan create failed`

The MoisturePilot service may be unavailable or the stored device credential
may have been revoked. Wait briefly and try again. Contact the project owner if
the problem continues.

### Individual camera or upload failures

Check the camera connection and FarmBot network status, then run the full scan
again. A scan containing missing images may produce incomplete results.

### The dashboard link expired

Run **Open MoisturePilot Dashboard** to receive a new link.
