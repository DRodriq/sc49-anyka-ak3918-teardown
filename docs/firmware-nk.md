# The firmware family: Juan "NK" app with XSDK plugins

Most public Anyka camera work targets one of two vendor applications: the
Tuya "HT" app (LSC and similar; symbols like `ht_rtsp_start`, config in
`_ht_sw_settings.ini`) or the InstaView "gv_ipc" app. The SC49 runs neither.
This page describes what it does run, because tricks written for the other
two do not transfer and other NVR-kit cameras probably share this firmware.

## Identification

| Marker | Value |
|---|---|
| `oem.json` `DevOemName` | `JUAN` |
| Function prefixes in `anyka_ipc` | `NK_…`, `NK_N1…`, `XSDK_…` |
| Firmware version | V4.9.82, 2024-10-18 (`/firmware_build`) |
| Build config | `akKM01N_8m_C3_NOLINK_WIFI6` |
| Config store | JSON files in `/etc/jffs2/config/` |
| SD mount point | `/mnt/tf` |

The attribution to Juan is an inference from the OEM string and the `esee` /
`juan` strings in the binary. If your camera has `/etc/jffs2/config/xsdk.json`
and an `anyka_ipc` full of `NK_N1` symbols, this page should apply.

Things that are **absent**, checked by string search over the whole carved
rootfs and APP partition: `ht_rtsp_start`, `main_ch`, `_ak39_factory`,
`_ht_sw_settings`, `_ht_hw_settings`, `lighttpd`.

## Boot chain

U-Boot → kernel → busybox `/sbin/init` → `/etc/init.d/rcS` → `rc.local`
(mounts APP at `/usr`, CONFIG at `/etc/jffs2`) → `/usr/sbin/main.sh` (loads
`cfg80211`/`mac80211`, USB, `ak_motor`, `ak_i2c`, `exfat`, …) →
`/usr/sbin/anyka_ipc.sh start` (SD mount, `debug.ini` check, then the app).

The app itself loads the sensor and Wi-Fi drivers; the init scripts do not.

## XSDK: network services as plugins

`anyka_ipc` exposes network protocols through "XSDK servers", listed in
`xsdk.json`. Each entry names a shared library the app `dlopen`s at start.

| Server | Port | Enabled in `xsdk.json` | Library | On the flash? |
|---|---|---|---|---|
| N1_Server | 80 (search 8002) | yes | `libXSDK_N1.so` | built into the app |
| RTSP_Server | 554 | yes | `libXSDK_Rtsp.so` | **no** |
| ONVIF_Server | 8888 (search 3702) | yes | `libXSDK_Onvif.so` | **no** |
| HLS_Server | – | yes | `libXSDK_Hls.so` | **no** |
| RTMP_Server | – | yes | `libXSDK_Rtmp.so` | **no** |
| GB28181_Server | – | yes | `libXSDK_Gb28181.so` | **no** |
| P2P_Server | 60002 (search 60001) | yes | `libXSDK_P2P.so` | **no** |
| CLOUD_Server | – | yes | `libXSDK_Cloud.so` | **no** |
| DMP_Server | – | yes | `libXSDK_Dmp.so` | **no** |
| CORSEE_Server | 12306 | yes | `libXSDK_Corsee.so` | **no** |
| HK_Server | 8000 | no | `libXSDK_Hik.so` | no |
| ZW_Server | 9101 | no | `libXSDK_Zw.so` | no |

`/usr/lib` holds only `libiconv`, `libnl` and `libwolfssl`. At boot the app
logs, for each missing plugin:

```
[SERVER_Init:61][dlopen]/usr/lib/libXSDK_Hls.so Dynamic lib error! File not found
[SERVER_Init:110]SERVER_Init -----------------ERROR!
```

Only N1 comes up (`[N1SERVER_Inist] --------ok!`). So on this build:

- **N1 on port 80 is the only video path.** It is the proprietary protocol the
  kit NVR speaks. Not reverse-engineered here.
- **RTSP and ONVIF are configured but not shipped.** Setting flags in
  `xsdk.json` or `oem.json` (`bRtspEnable`) cannot enable them.
- The plugin interface is a real extension point: a `libXSDK_Rtsp.so` built
  for the same XSDK ABI and dropped into `/usr/lib` (by bind mount from the SD
  card) should be loaded with no other change. No compatible library has been
  found yet.

## The CONFIG partition

Dumped from a live unit to [`dump/carve/config/`](../dump/carve/config), with
MAC addresses, device ID and the paired NVR's SSID and key redacted.

| File | Governs |
|---|---|
| `network.json`, `network_backup.json` | Wi-Fi mode, station/AP credentials, DHCP. The NVR lock lives here. |
| `sysmisc.json` | system-level Wi-Fi mode (`enWifiMode`) and misc flags |
| `xsdk.json` | the server table above |
| `oem.json` | OEM name, image flip, PTZ geometry, IR-cut and light behaviour |
| `video.json` | stream resolutions, bitrate, motion/human detection |
| `ptz.json` | PTZ step counts, current angle, presets |
| `audio.json`, `light.json`, `af.json`, `time.json`, `tfcard.json` | as named |
| `cloud.json`, `p2p.json` | cloud and P2P endpoints (plugins absent on this build) |
| `user.json`, `device.json`, `capabilityset.json` | accounts, identity, feature flags |
| `metadata/*.json` | schema-like defaults for the above |

Two behaviours to know about:

- The app keeps `*_backup.json` copies and restores from them, so an edit to
  only the primary file is reverted.
- `mount --bind` over a file in this jffs2 mount does not take effect; write
  the file.

## NVR pairing

The camera decides it belongs to an NVR kit purely from the station SSID:
relevant symbols are `NK_N1Utils_IsHotSpotOfNVR`, `CheckPairedWiFiNVR` and the
log line `Search Ssid Head is NVR,Scan Once.` A station SSID beginning `NVR`
selects NVR behaviour (and `nvr_ipc_config=1` when the Wi-Fi driver is
loaded); any other SSID gives an ordinary WPA2 association. The practical
recipe is in [`standalone.md`](standalone.md).
