# SC49 — running standalone on your own Wi-Fi (no NVR, no cloud)

The SC49 ships bound to its kit's Wi-Fi **NVR**: with no NVR present it associates to
nothing useful and loops (the "please configure the network" / silent-hunt behaviour).
This is how to make it a normal station on your home AP, reachable over the LAN, fully
offline — worked out on the bench 2026-11-23 against the live device.

## What actually gates NVR vs. standalone

The whole lock lives in **`network.json`** (jffs2 `/etc/jffs2/config/network.json`),
`stWifiList[0]`:

- **`enWiFiMode`** — `1` = **station** (join an AP), `0` = **SoftAP/provisioning**
  (the camera stands up its own `IPC…` AP and says "please configure the network").
  Keep it **`1`**.
- **NVR mode is triggered only by the station SSID starting with `NVR`** (binary:
  `Search Ssid Head is NVR`, `NK_N1Utils_IsHotSpotOfNVR`, `CheckPairedWiFiNVR`). Point
  the station at a **non-`NVR` SSID** and it does a plain WPA2 association — no pairing,
  no `172.20.14.1` NVR heartbeat.
- The driver is even loaded accordingly: `insmod aic8800_fdrv.ko … nvr_ipc_config=1`
  (NVR) vs `=0` (single-IPC). Config picks it; see `bin/aic8800d80/`.

So **standalone = `enWiFiMode:1` + a normal SSID + `bEnableDHCP:true`**. See
`dump/carve/config/network.standalone.template.json` (fill in `YOUR_WIFI_SSID` /
`YOUR_WIFI_PASS`).

## How to apply it (SD-card `debug.ini` route, reversible)

Two gotchas learned the hard way:

1. **`mount --bind` over the jffs2 file does NOT take.** Direct-**write** (`cp`) the
   file into `/etc/jffs2/config/`.
2. The app falls back to **`network_backup.json`** — you must overwrite **both**
   `network.json` and `network_backup.json` (and `sysmisc.json` `enWifiMode:1`).

An `anyka_ipc_nostrip` that does this (originals backed up to the card first):

```sh
#!/bin/sh
TF=/mnt/tf
telnetd -l /bin/sh -p 23 &
[ -f "$TF/orig_network.json" ] || cp /etc/jffs2/config/network.json "$TF/orig_network.json"
cp "$TF/network.standalone.json" /etc/jffs2/config/network.json
cp "$TF/network.standalone.json" /etc/jffs2/config/network_backup.json
cp "$TF/sysmisc.standalone.json" /etc/jffs2/config/sysmisc.json
sync
exec /mnt/tf/anyka_ipc.real "$@"
```

Drop that + `debug.ini` + `anyka_ipc.real` + your filled-in `network.standalone.json`
on the card, boot: it joins your AP over DHCP, telnet on `:23`. To revert, restore the
`orig_*` files (or just reflash CONFIG).

## The catch: there is NO standard video feed out of the box

Confirmed on the device: `/usr/lib` contains only `libiconv`/`libnl`/`libwolfssl` —
**the firmware ships no `libXSDK_Rtsp.so`, `libXSDK_Onvif.so`, or `libXSDK_Hls.so`.**
`xsdk.json` lists an RTSP server on 554 and ONVIF on 8888 with `bServerEnable:true`, and
`oem.json` has `bRtspEnable:true`, but the XSDK framework's `dlopen` of each lib fails
("File not found") — only the statically-built **N1 server (port 80, proprietary NVR
protocol)** comes up. The H.265 encoder runs (SC3332 sensor, 2304×1296 main + 640×360
sub), frames just aren't exposed over anything standard.

To get a usable feed you must **add a server**, two options:

1. **Drop in an ABI-compatible `libXSDK_Rtsp.so`** from a sibling Anyka AK3918 firmware
   into `/usr/lib` (SD overlay). If the XSDK version matches, the stock app serves RTSP
   on 554 with no other change. Cheapest if the ABI matches.
2. **`onvif_simple_server`** (roleoroleo) cross-compiled for AK3918 (armv5te/uClibc),
   reading the encoder — the OpenIPC/Thingino-style path.

Status: standalone-on-LAN + root telnet + offline = **done**; standard feed = **open**
(pending one of the two above).
