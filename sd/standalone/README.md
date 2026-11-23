# sd/standalone — join your own Wi-Fi instead of the kit NVR

Builds on `sd/minimal`. Full explanation in
[`docs/standalone.md`](../../docs/standalone.md). Verified on the bench
2026-11-23 (LAN + root telnet + no cloud; **no standard video feed yet**).

Copy to the root of a FAT32 SD card:

| File | Source |
|---|---|
| `debug.ini` | `sd/minimal/debug.ini` |
| `anyka_ipc_nostrip` | this directory |
| `anyka_ipc.real` | `dump/carve/app/bin/anyka_ipc` or your own unit's `/usr/bin/anyka_ipc` |
| `network.standalone.json` | copy `network.standalone.template.json`, fill in `YOUR_WIFI_SSID` / `YOUR_WIFI_PASS`. The SSID must **not** start with `NVR`. |
| `sysmisc.standalone.json` | optional; your unit's `sysmisc.json` with `"enWifiMode": 1` (it already is on a kit-paired unit) |

This one **does write to flash** (the jffs2 CONFIG partition). The originals
are saved to the card as `orig_*.json` on first run; copy them back to
`/etc/jffs2/config/` to revert.
