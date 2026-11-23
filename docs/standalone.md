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
[`sd/standalone/network.standalone.template.json`](../sd/standalone/network.standalone.template.json) (fill in `YOUR_WIFI_SSID` /
`YOUR_WIFI_PASS`).

## How to apply it (SD-card `debug.ini` route, reversible)

Two gotchas learned the hard way:

1. **`mount --bind` over the jffs2 file does NOT take.** Direct-**write** (`cp`) the
   file into `/etc/jffs2/config/`.
2. The app falls back to **`network_backup.json`** — you must overwrite **both**
   `network.json` and `network_backup.json` (and `sysmisc.json` `enWifiMode:1`).

The payload that does this is [`sd/standalone/`](../sd/standalone): its
`anyka_ipc_nostrip` backs the originals up to the card, writes the new files, starts
telnet and then execs the real app. Put it on the card with `debug.ini`,
`anyka_ipc.real` and your filled-in `network.standalone.json`, and boot: the camera
joins your AP over DHCP with telnet on `:23`. To revert, copy the `orig_*` files back
(or reflash CONFIG).

## The catch: there is NO standard video feed out of the box

Confirmed on the device: `/usr/lib` contains only `libiconv`/`libnl`/`libwolfssl` —
**the firmware ships no `libXSDK_Rtsp.so`, `libXSDK_Onvif.so`, or `libXSDK_Hls.so`.**
`xsdk.json` lists an RTSP server on 554 and ONVIF on 8888 with `bServerEnable:true`, and
`oem.json` has `bRtspEnable:true`, but the XSDK framework's `dlopen` of each lib fails
("File not found") — only the statically-built **N1 server (port 80, proprietary NVR
protocol)** comes up. The encoder runs (two SC2336P sensors; `video.json` sets a
1920×2160 main and a 640×720 sub stream), frames just aren't exposed over anything
standard. Why, and the full plugin table: [`firmware-nk.md`](firmware-nk.md).

To get a usable feed you must **add a server**. Three candidate routes, none done yet:

1. **Port the EV300L userspace approach.**
   [jonathan-gtd/anyka-ak3918ev300l-decloud](https://github.com/jonathan-gtd/anyka-ak3918ev300l-decloud)
   builds the public Anyka SDK `rtsp` sample against the vendor media stack on a board
   with the same kernel and near-identical library versions (table in
   [`hardware.md`](hardware.md)). The catch here: this firmware has no media `.so`
   files to link against — they are static inside `anyka_ipc` — so the libraries have
   to come from an SDK or a sibling firmware.
2. **Drop in an ABI-compatible `libXSDK_Rtsp.so`** from a sibling Juan/NK firmware
   into `/usr/lib` (SD bind mount). If the XSDK version matches, the stock app serves
   RTSP on 554 with no other change.
3. **Speak N1.** Reverse the port-80 protocol the NVR uses and bridge it to RTSP
   off-camera. No camera-side change needed.

ONVIF (for example roleoroleo's `onvif_simple_server`) only becomes useful once one of
these provides a stream to advertise.

Status: standalone-on-LAN + root telnet + offline = **done**; standard feed = **open**.
