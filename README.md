# SC49 — Anyka AK3918AV100 NVR-kit camera: teardown and reference

Reference material for the **Camcamp / Toguard SC49**, a dual-lens pan/tilt
Wi-Fi camera sold as part of a 10-channel wireless-NVR kit, and by extension
for other cameras built on the **Anyka AK3918AV100** with the **Juan "NK" /
XSDK** vendor firmware.

It is a teardown and a set of documented findings, not a replacement
firmware. The aim is to give the Anyka camera projects below what they lack
for this chip and firmware family: a hardware report, an unpacked firmware
dump, a no-solder root method, and an explanation of the NVR lock.

## Status

| | |
|---|---|
| SoC, flash, sensors, Wi-Fi identified | ✅ |
| Full 8 MB flash read, partitions carved and unpacked | ✅ |
| Root without soldering (`debug.ini` on the SD card) | ✅ |
| NVR lock understood; camera runs on an ordinary Wi-Fi AP, no cloud | ✅ |
| CONFIG partition dumped and mapped | ✅ |
| Local video feed (RTSP / WebRTC via go2rtc `eseecloud` bridge) | ✅ — no native server on the firmware; the N1 port-80 stream is bridged |
| PTZ / image / day-night control via the stock app's HTTP API | ✅ [`docs/control.md`](docs/control.md) |
| Native on-device RTSP server; standalone (app-independent) motor control | ❌ open — app-native HTTP control used instead |
| OpenIPC on this board | ❌ no AV100 image available yet |

## Device

| | |
|---|---|
| SoC | Anyka **AK3918AV100-C** (`CASW102D4N`), ARM926EJ-S, 64 MB |
| Flash | XMC XM25QH64D, 8 MB SPI NOR |
| Sensors | 2 × SmartSens SC2336P, 1920×1080 each |
| Wi-Fi | AICSemi AIC8800D40L (USB) |
| PTZ | two unipolar steppers via ULN2803A, `ak_motor.ko` |
| Kernel | Linux 4.4.282, Buildroot 2018.02.7, uClibc |
| Firmware | V4.9.82 (2024-10-18), OEM `JUAN`, config `akKM01N_8m_C3_NOLINK_WIFI6` |

## Documentation

| Document | What it covers |
|---|---|
| [`docs/hardware.md`](docs/hardware.md) | Hardware report: flash layout, library and module versions, video, PTZ, findings, OpenIPC notes |
| [`docs/access.md`](docs/access.md) | The `debug.ini` SD-card root method; why the serial console is not a way in |
| [`docs/firmware-nk.md`](docs/firmware-nk.md) | The NK/XSDK firmware family: plugin servers, CONFIG partition, NVR pairing |
| [`docs/standalone.md`](docs/standalone.md) | Running the camera on your own Wi-Fi without the NVR |
| [`docs/control.md`](docs/control.md) | Driving the de-clouded camera over its own HTTP API: live feed (go2rtc), PTZ, image, day/night; the `sc49ctl` CLI; resume notes |
| [`docs/benchlog.md`](docs/benchlog.md) | Dated bench notes, including superseded conclusions |

## Repository layout

```
docs/               the documents above
dump/carve/         unpacked firmware: rootfs/, app/ (→ /usr), config/ (jffs2), dtb.bin
dump/boot_capture/  kernel and app logs written by the camera, root shadow hash
sd/minimal/         verified SD payload: root telnet, nothing else changed
sd/standalone/      verified SD payload: join your own Wi-Fi
sd/experimental/    unverified material written for other firmware; see its README
sc49ctl.sh          CLI for the HTTP control plane (PTZ / image / day-night / snapshot)
```

The raw 8 MB flash images are not committed. Device-specific identifiers in
the config dump and logs (MAC addresses, device ID, the paired NVR's SSID and
key) are redacted.

## Related work

Where this sits among existing Anyka camera projects:

| Project | SoC | Vendor app | Way in | Local video |
|---|---|---|---|---|
| **this repo** | AK3918AV100 | Juan NK / XSDK | `debug.ini` + `anyka_ipc_nostrip` on SD | RTSP via go2rtc (N1/eseecloud bridge); PTZ + day/night over the app's HTTP API |
| [jonathan-gtd/anyka-ak3918ev300l-decloud](https://github.com/jonathan-gtd/anyka-ak3918ev300l-decloud) | AK3918EV300L | InstaView `gv_ipc` | SPI programmer + serial | RTSP H.265, ONVIF, PTZ (replaces the userspace) |
| [HeartyGFX/LSC-Anyka-RTSP-Hack](https://github.com/HeartyGFX/LSC-Anyka-RTSP-Hack) | AK3918EV330 | Tuya HT | guino's `hack.sh` on SD | RTSP via `/tmp/_ak39_factory.ini` |
| [guino/LSCOutdoor1080P](https://github.com/guino/LSCOutdoor1080P) | AK3918 (LSC) | Tuya HT | `hack.sh` on SD | RTSP via binary patch |
| [OpenIPC firmware #1970](https://github.com/OpenIPC/firmware/issues/1970) | AK3918EV330 | Tuya HT | SD telnet | dumps and hardware info; closed, EV330 unsupported |
| [OpenIPC Anyka status](https://openipc.org/cameras/vendors/anyka) | several | — | — | AK3918AV100 listed as in progress, not installable (2026-11-23) |

What carries over and what does not:

- **The Tuya-HT tricks do not apply.** This firmware has no dormant RTSP
  server and none of the HT trigger files; see
  [`docs/firmware-nk.md`](docs/firmware-nk.md).
- **The EV300L userspace approach is the closest fit.** Same kernel version
  and Buildroot, the same `AV100&300L` ISP driver line, and media libraries
  one or two patch releases apart
  ([comparison table](docs/hardware.md#vendor-userspace-versions-to-match-an-sdk)).
  The difference is that this firmware links those libraries statically.

## Open work

Feed, PTZ, image, and day/night control are solved through the stock app over
HTTP — see [`docs/control.md`](docs/control.md). What remains:

1. **White flood (`AlarmWhiteLight`)**: reachable only over the binary N1
   protocol, not HTTP (`ledpwm` reports no channels; it reads as a motion
   flash). Reverse the N1 command frames — go2rtc's `eseecloud` source is the
   reference — if steady-lamp control is wanted.
2. **Day/night write**: the exact `PUT /NetSDK/Image/irCutFilter` JSON schema
   the handler accepts (GET works; `gpio69` is the hardware fallback).
3. **IR illuminator pin**: confirm in a dark scene
   ([`docs/control.md`](docs/control.md) §3).
4. **Native on-device RTSP / OpenIPC**: a server on the camera itself (the SDK
   `rtsp` build hit a venc blob-version wall, [`docs/hardware.md`](docs/hardware.md))
   and an installable OpenIPC AV100 image.

Reports from other AV100 or NK-firmware cameras are welcome as issues,
especially whether `debug.ini` works on them.

## License and scope

Documentation and the scripts under `sd/minimal/` and `sd/standalone/` are
MIT licensed ([`LICENSE`](LICENSE)). The firmware contents under `dump/` are
the vendor's, included for interoperability research on hardware you own, and
are not covered by that license. Nothing here is affiliated with Anyka, Juan,
Camcamp or Toguard.
