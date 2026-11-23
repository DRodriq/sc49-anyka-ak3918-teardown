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
| **Standard video feed (RTSP / ONVIF)** | ❌ open — the firmware ships no RTSP server |
| PTZ GPIO map and standalone motor control | ❌ open |
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
| [`docs/benchlog.md`](docs/benchlog.md) | Dated bench notes, including superseded conclusions |

## Repository layout

```
docs/               the documents above
dump/carve/         unpacked firmware: rootfs/, app/ (→ /usr), config/ (jffs2), dtb.bin
dump/boot_capture/  kernel and app logs written by the camera, root shadow hash
sd/minimal/         verified SD payload: root telnet, nothing else changed
sd/standalone/      verified SD payload: join your own Wi-Fi
sd/experimental/    unverified material written for other firmware; see its README
```

The raw 8 MB flash images are not committed. Device-specific identifiers in
the config dump and logs (MAC addresses, device ID, the paired NVR's SSID and
key) are redacted.

## Related work

Where this sits among existing Anyka camera projects:

| Project | SoC | Vendor app | Way in | Local video |
|---|---|---|---|---|
| **this repo** | AK3918AV100 | Juan NK / XSDK | `debug.ini` + `anyka_ipc_nostrip` on SD | not yet |
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

In priority order:

1. **A standard video feed.** Three candidate routes are laid out in
   [`docs/standalone.md`](docs/standalone.md); porting jonathan-gtd's SDK
   `rtsp` server build to this board is the first to try.
2. **PTZ**: map the stepper coils to SoC GPIOs and drive `/dev/motor0` /
   `/dev/motor1` without the vendor app.
3. **N1**: document the port-80 protocol the kit NVR speaks.
4. **OpenIPC**: a hardware issue for the AK3918AV100-C referencing
   [`docs/hardware.md`](docs/hardware.md).

Reports from other AV100 or NK-firmware cameras are welcome as issues,
especially whether `debug.ini` works on them.

## License and scope

Documentation and the scripts under `sd/minimal/` and `sd/standalone/` are
MIT licensed ([`LICENSE`](LICENSE)). The firmware contents under `dump/` are
the vendor's, included for interoperability research on hardware you own, and
are not covered by that license. Nothing here is affiliated with Anyka, Juan,
Camcamp or Toguard.
