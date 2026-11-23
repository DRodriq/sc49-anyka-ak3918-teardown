# sd/experimental — unverified, kept for reference

Nothing in this directory is known to work on the SC49. It is kept so the
record of what was tried is complete, and as raw material for the open
video-feed work. Do not treat it as a working payload.

## `custom/` and `hack.sh`

A larger SD customisation stack (config overrides, offline hosts file, ONVIF
via lighttpd + `onvif_simple_server`, PTZ helper `ptzctl`). It was written for
the **Tuya "HT" Anyka firmware family** — the one targeted by
[guino/LSCOutdoor1080P](https://github.com/guino/LSCOutdoor1080P),
[HeartyGFX/LSC-Anyka-RTSP-Hack](https://github.com/HeartyGFX/LSC-Anyka-RTSP-Hack)
and similar projects — and does not match this camera's firmware:

- it bind-mounts `_ht_sw_settings.ini` / `_ht_hw_settings.ini` and expects
  `/usr/local/etc/lighttpd.conf`; none of those names appear anywhere in the
  SC49 rootfs or APP partition;
- its hardware config describes an **SC3332 at 2304×1296**, whereas this
  camera has two **SC2336P** sensors at 1920×1080 (see `docs/hardware.md`);
- it assumes the SD card at `/tmp/sd`; this firmware mounts it at `/mnt/tf`.

**Provenance: not recorded.** The exact upstream project these files were
adapted from was not noted when they were added, and `custom/bin/ptzctl` is a
prebuilt static ARM binary with no source here. If you recognise the origin,
please open an issue so it can be credited (and licensed) properly.

## `_ak39_factory.ini.template`, `Factory/config.sh`, `_ht_ap_mode.conf`, `TZ`

Trigger files from other Anyka SD-card conventions, tried on 2026-11-01 with
no reaction. The string `_ak39_factory` does not occur anywhere in this
firmware, so the factory-mode RTSP trick from HeartyGFX's repo cannot apply
here. The convention this build does honour is `debug.ini` — see
[`docs/access.md`](../../docs/access.md).
