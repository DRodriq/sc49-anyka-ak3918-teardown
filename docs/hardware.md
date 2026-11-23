# Hardware report: Camcamp / Toguard SC49 (Anyka AK3918AV100, Juan "NK" firmware)

Laid out to match
[jonathan-gtd's AK3918EV300L report](https://github.com/jonathan-gtd/anyka-ak3918ev300l-decloud/blob/main/docs/hardware.md)
section for section, so the two boards can be compared directly. Everything
here comes from the flash dump and boot logs in [`dump/`](../dump); anything
inferred rather than read off the device is marked as such.

## TL;DR

- Dual-lens pan/tilt Wi-Fi camera from a 10-channel wireless-NVR kit. SoC
  **Anyka AK3918AV100-C** (package marking `CASW102D4N`, DT
  `compatible = "anyka,ak3918av100"`, CPU ID `0x535335`), ARM926EJ-S, 64 MB RAM
  (32 MB visible to Linux), 8 MB SPI NOR **XMC XM25QH64D** (JEDEC `20 40 17`,
  detected by the kernel as `xm25qh64c`).
- Sensors: **two SmartSens SC2336P** on I2C bus 0, 1920×1080 each. Wi-Fi
  **AICSemi AIC8800D40L** (Wi-Fi 6 + BT), attached over **USB**. Two-axis
  stepper PTZ through a **ULN2803A**.
- Stock firmware: kernel **4.4.282** (`#1 Thu Jul 25 2024`, Buildroot
  2018.02.7, gcc 5.5.0, uClibc 1.0.28), application firmware **V4.9.82**
  (2024-10-18), build config `akKM01N_8m_C3_NOLINK_WIFI6`, OEM name `JUAN`.
- The vendor app is a single **statically linked** `anyka_ipc` (4.7 MB). There
  are **no Anyka media `.so` libraries on the flash** to reuse — the main
  obstacle to the "keep the kernel, replace the userspace" approach.
- **No standard video output as shipped.** RTSP/ONVIF/HLS are plugins the app
  tries to `dlopen` and that are not on the flash. See
  [`firmware-nk.md`](firmware-nk.md).

## Flash layout (kernel command line `mtdparts`, `spi0.0`)

| mtd | name | offset | size | content |
|---|---|---|---|---|
| 0 | UBOOT | 0x000000 | 184K | U-Boot 2019.10.0-V4.0.24 (May 09 2024) |
| 1 | ENV | 0x02E000 | 4K | U-Boot environment |
| 2 | BKENV | 0x02F000 | 4K | environment backup |
| 3 | DTB | 0x030000 | 64K | FDT — [`dump/carve/dtb.bin`](../dump/carve/dtb.bin) |
| 4 | KERNEL | 0x040000 | 1600K | Linux 4.4.282 |
| 5 | ROOTFS | 0x1D0000 | 768K | squashfs → `/` |
| 6 | APP | 0x290000 | 5112K | squashfs → `/usr` |
| 7 | CONFIG | 0x78E000 | 448K | jffs2 → `/etc/jffs2` |
| 8 | FACTORY | 0x7FE000 | 8K | |

U-Boot: `bootcmd=run boot_normal`, boot delay effectively 0, console input
closed. Kernel console `ttySAK0,115200n8`. The raw 8 MB images are not
committed (see `.gitignore`); two independent reads on one unit were each
confirmed by a byte-identical re-read.

## Vendor userspace versions (to match an SDK)

Read from version strings inside the static `anyka_ipc`. EV300L column is from
jonathan-gtd's report.

| Library | SC49 (AV100) | EV300L |
|---|---|---|
| `libplat_vi` | V3.4.17 | V3.4.21 |
| `libplat_vpss` | V2.1.05 | V2.1.09 |
| `libmpi_venc` | V2.0.40 | V2.0.44 |
| `libplat_isp_sdk` | V8.0.01 | V8.0.01 |
| `libplat_common` | V1.0.22 | V1.0.23 |
| `libapp_video` | V1.0.14 | V1.0.14 |
| `libplat_ai` | V1.14.01 | V1.14.02 |
| `libplat_ao` | V1.13.01 | V1.13.04 |
| `libmpi_aenc` | V1.2.05 | V1.2.06 |
| ISP driver | `isp_drv_lib-V0.2.30_bchV1.0.05-AV100&300L` | `isp_drv_lib-V0.2.31-AV100&300L` |

Also present: `libmpi_adec V1.3.10`, `libmpi_osd V1.1.04`, `libmpi_svp V1.2.19`,
`libplat_vqe V1.6.02`, `libplat_drv_ptz V1.0.01`, `libapp_md V1.0.08`,
`libapp_osd_ex V1.1.07`, `libapp_its V1.2.00`, `libakv_cnn_dt V1.19.02`,
`libakv_cnn_fas V1.4.06`, `libakv_cnn_re V1.3.06`, plus `libplat_{dbg,log,mem,
osal,thread,timer,uuid}`.

The two boards are one or two patch releases apart on every media library and
share the same ISP driver line, kernel version and Buildroot. That is the
basis for expecting the EV300L userspace work to port (untested — see
"Open work" in the top-level README).

Kernel modules (`/usr/modules`, vermagic 4.4.282): `ak_isp`,
`ak_venc_adapter`, `ak_venc_bridge`, `ak_i2c`, `ak_pcm`, `ak_ion`, `ak_mci`,
`ak_mmc`, `ak_hcd`, `ak_udc`, `ak_eth`, `ak_saradc`, `ak_pwm_char`,
`ak_motor`, `ak_crypto`, `ak_efuse`, `ak_tsensor`, `ak_uio`, `ak_ramdisk`,
`gpio_ext`, `exfat`, `cryptodev`; sensors `sensor_sc2336p`, `sensor_sc223ap`,
`sensor_sc200ai`, `sensor_mis2008`; Wi-Fi `aic_load_fw`, `aic8800_fdrv`,
`aic_btusb`, `cfg80211`, `mac80211`; USB networking/modem stack (`usbnet`,
`cdc_ether`, `rndis_host`, `option`, `usb_wwan`).

Shared libraries on the flash are only uClibc, `libiconv`, `libnl-3`,
`libnl-genl-3` and `libwolfssl`.

## Video

| | |
|---|---|
| Sensors | 2 × SC2336P, both probed on `i2c-0`, cropped 1920×1080 |
| ISP | two instances (`isp_id:0`, `isp_id:1`) |
| Main stream (`video.json`) | 1920×2160, 15 fps, 2048 kbit/s, GOP 60 |
| Sub stream | 640×720, 15 fps, 512 kbit/s |

1920×2160 is consistent with the two 1080p sensors stacked vertically into one
encoded frame (inferred from the numbers, not confirmed by decoding a frame).
Both streams use `enEncodeType: 5`; the codec that value maps to has not been
confirmed.

## PTZ

- Driver `ak_motor.ko`, devices `/dev/motor0` and `/dev/motor1`, userspace
  `libplat_drv_ptz` inside `anyka_ipc`.
- `ptz.json` / `oem.json`: horizontal 300° over 1705 steps, vertical 100° over
  565 steps, 8-beat (half-step) drive, self-check at boot.
- Board: `ULN2803A` Darlington array on the lens board; motors are 5-wire
  unipolar steppers (28BYJ-48 class).
- **Not yet done:** the SoC GPIO-to-coil map and a userspace control tool.

## Wi-Fi

AIC8800D40L enumerates as USB device "AIC Wlan" (`aicsemi`). Firmware blobs
are in `dump/carve/app/bin/aic8800d80/` and `aic8800dc/`. The app loads the
driver itself with `insmod … module_comb_d80_dc=1 nvr_ipc_config=<0|1>`; the
last parameter selects NVR-kit versus single-camera radio configuration.
Open-source drivers exist as OpenIPC `aic8800` and Thingino `wifi-aic8800`
(neither tried on this board).

## Board notes

- **Two PCBs**: a main board (SoC under a glued cover, flash, Wi-Fi module) and
  a lens/sensor board carrying the UART pads, `ULN2803A`, mic pads and a 4-pin
  LED header (`GND GRE RED IR`).
- **Serial**: three unlabelled through-hole pads by the mounting ring on the
  lens board — GND, (presumed) RX, TX. 3.3 V, 115200 8N1. Output is the U-Boot
  banner only; see [`access.md`](access.md).
- **Power**: 12 V / 1 A barrel on a pigtail, with a reset switch on the tail.
- **microSD slot** present.
- Label: model SC49, date code XF-4724, FCC/CE marks but no FCC ID printed.

## Findings that may save someone time

1. **`debug.ini` on the SD card is a root code-execution path** that needs no
   soldering and writes nothing to flash. [`access.md`](access.md).
2. **The serial console is not a way in.** U-Boot input is closed and the RX
   series resistor appears unpopulated.
3. **The NVR lock is one config value plus an SSID prefix**, not a radio
   protocol. [`standalone.md`](standalone.md).
4. **`mount --bind` over files on the jffs2 CONFIG partition does not take**;
   the app also falls back to `network_backup.json`. Write both, directly.
5. **Killing or replacing the app leaves the camera inert.** The app owns
   Wi-Fi bring-up (it `insmod`s the driver), so a bare board has no network.
6. **Don't over-stress the flash chip in circuit.** One unit's XM25QH64D was
   killed by cumulative 5 V / hot-air exposure before a clean read on a second.

## What does not work for OpenIPC as-is

- OpenIPC lists the AK3918AV100 as work in progress with no installable image
  (checked 2026-11-23).
- U-Boot console input is closed on this unit, so the usual
  interrupt-and-TFTP install is not available; a first install would need a
  SPI programmer.
- The vendor media stack exists only inside the static `anyka_ipc`, built for
  kernel 4.4.282 and uClibc.

## Testing offer

Two further SC49 units are on hand and the flash can be read and rewritten
with a programmer. Happy to flash and report on test builds; note that serial
*output* is available but serial *input* is not.
