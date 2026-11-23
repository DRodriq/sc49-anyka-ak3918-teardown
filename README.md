# SC49 dual-lens PTZ Wi-Fi camera — teardown notes

Camcamp / Toguard **SC49** camera from a 10-channel wireless-NVR kit. No public teardown,
chipset, FCC ID or protocol documentation existed when this started (2026-10-28), so this file
is being written to fill that gap and to be published once complete (venue TBD: OpenIPC /
Thingino wiki, IPCamTalk, GitHub). Everything here was measured on the bench; anything marked
*unconfirmed* is a reading from a webcam frame, not a verified part number.

## STATUS 2026-11-23 — running standalone on home Wi-Fi; feed is the only open item

The NVR lock is fully understood and defeated: the camera now runs as a plain **station on
an ordinary home AP**, reachable over the LAN, root telnet on `:23`, no cloud (it does not
even attempt WAN egress). The switch is `network.json` `enWiFiMode` (`1`=station,
`0`=SoftAP) plus the fact that **NVR mode triggers only on an SSID starting with `NVR`** —
point the station at a normal SSID and it associates plainly. Full recipe, gotchas
(`mount --bind` doesn't take → direct-write; must also overwrite `network_backup.json`),
and the sanitized config template: **see [`STANDALONE.md`](STANDALONE.md)**.

One thing standalone does NOT give you: a **standard video feed**. The stock firmware ships
**no `libXSDK_Rtsp.so`/`_Onvif.so`/`_Hls.so`** in `/usr/lib` — only the statically-built N1
server (port 80, proprietary). The H.265 encoder runs, but nothing exposes it over RTSP/ONVIF
until you add a server (drop-in `libXSDK_Rtsp.so` from a sibling firmware, or
`onvif_simple_server`). Details in `STANDALONE.md`.

The live jffs2 **CONFIG partition** (which this repo previously lacked) is now included under
`dump/carve/config/` — `network.json`, `xsdk.json`, `oem.json`, `sysmisc.json`, etc. — the
authoritative map of what gates the camera's behaviour. Board photos were dropped from the
repo; the textual part IDs below are the durable record.

## STATUS 2026-11-04 — SOLVED: firmware extracted, device fully owned

Both ways in succeeded on 2026-11-04: the full 8 MB SPI flash was read **and** the camera was
rooted over its SD card. Raw evidence is archived under `dump/` in this directory:

- `dump/sc49_cam3_xm25qh64_*.bin`, `dump/sc49_retest_*.bin` — two independent full 8 MB reads of
  the XM25QH64D, each confirmed stable by a byte-identical re-read (md5 `0a92b39e…` and `a9badabf…`).
  Done on a **fresh camera (#3)**; camera #1's chip was killed earlier (cumulative 5 V / hot-air
  stress), two SC49 units still untouched. **These full images are not committed** (they are
  `.gitignore`d): they are the vendor's proprietary firmware and are reproducible by dumping the
  flash on any unit. The carved and unpacked contents under `dump/carve/` are tracked.
- `dump/carve/` — the flash carved by the kernel-cmdline MTD map and both squashfs images unpacked
  (`carve/rootfs/` 111 files, `carve/app/` 209 files).
- `dump/sd_artifacts/` — what the running camera wrote to / what we staged on the SD card
  (boot logs, root `shadow`, the trigger files, the hijack payload, the unstripped binary).

### Most useful bits (for OpenIPC / Thingino / IPCamTalk)

If you're here to port firmware to or root one of these, start with:

- **Device identity** — Anyka **AK3918AV100-C**, Linux 4.4.282, firmware V4.9.82 (tables below).
- **The `debug.ini` SD-card root RCE** — unauthenticated code-exec via the `anyka_ipc_nostrip`
  bind-mount; the non-destructive way in. See "THE way in" below.
- **MTD partition map** — exact offsets/sizes for the 8 MB `spi0.0`, carved and unpacked under
  `dump/carve/` (`rootfs/` 111 files, `app/` 209 files).
- **Wi-Fi** — AIC8800D40L; the vendor firmware blobs are in the dump at
  `dump/carve/app/bin/aic8800d80/` and `…/aic8800dc/`. Linux drivers: OpenIPC `aic8800`,
  Thingino `wifi-aic8800`.
- **Serial console** — pinout, 3.3 V / 115200 8N1, and why U-Boot input is closed (see "Console").
- **Root password hash** — `dump/sd_artifacts/shadow` (MD5-crypt, firmware-wide, uncracked).

### Device identity (now certain)

| Field | Value |
|---|---|
| SoC | **Anyka AK3918AV100-C** (CPU ID `0x535335`, ARM926EJ-S / ARMv5TEJ, 64 MB). Board marking `CASW102D4N` → AV100. |
| Kernel | **Linux 4.4.282**, Buildroot 2018.02.7, built 2024-07-25, `root@debian`, console `ttySAK0,115200n8` |
| Firmware | **V4.9.82, 2024-10-18**; Tuya/Anyka IPC vendor fork, git branch `hotfix_v4980_CIPC`; build config `akKM01N_8m_C3_NOLINK_WIFI6` |
| Root fs | squashfs on `mtdblock5`, `init=/sbin/init` (busybox) |

**MTD partition map** (from the kernel command line, `spi0.0`, 8 MB total):

| Part | Offset | Size | Notes |
|---|---|---|---|
| UBOOT | 0x0 | 184 K | |
| ENV / BKENV | 0x2E000 / 0x2F000 | 4 K each | U-Boot env + backup |
| DTB | 0x30000 | 64 K | |
| KERNEL | 0x40000 | 1600 K | Linux 4.4.282 |
| ROOTFS | 0x1D0000 | 768 K | squashfs → `/` (`mtdblock5`) |
| APP | 0x290000 | 5112 K | squashfs → `/usr` (holds `anyka_ipc`) |
| CONFIG | 0x78E000 | 448 K | jffs2 → `/etc/jffs2` |
| FACTORY | 0x7FE000 | 8 K | |

### Boot chain

U-Boot (`bootcmd=run boot_normal`; its console input really is closed — bootdelay ~0) → kernel →
busybox `/sbin/init` → `/etc/init.d/rcS` → `rc.local` (mounts APP at `/usr`, CONFIG at `/etc/jffs2`)
→ `/usr/sbin/main.sh` (insmods wifi `cfg80211`/`mac80211`, `ak_motor` for the PTZ gimbal, `ak_i2c`,
`exfat`, …) → `/usr/sbin/anyka_ipc.sh start`.

### THE way in: the `debug.ini` SD-card convention (previously undocumented for this build)

The 2026-11-01 conclusion that "this build honors no publicly-documented Anyka SD convention" was
**wrong about which file**. The trigger this fork honors is **`debug.ini`**, handled inside
`/usr/sbin/anyka_ipc.sh` (extracted at `dump/carve/app/sbin/anyka_ipc.sh`). On start it mounts the
SD card (`/dev/mmcblk0p1`) at `/mnt/tf`, and **if `/mnt/tf/debug.ini` exists** it:

1. **`mount --bind /mnt/tf/anyka_ipc_nostrip /usr/bin/anyka_ipc`** — if an `anyka_ipc_nostrip`
   file is on the card, the firmware bind-mounts it over the real application binary and runs it.
   **That is an unauthenticated arbitrary-root-code-execution primitive**: drop `debug.ini` + your
   own `anyka_ipc_nostrip`, power on, your code is PID-whatever as root.
2. Sets `LOG_REDIRECT=1` (unless `production_test.ini` or `log_no_redirect` is also present),
   increments `/mnt/tf/.reboot`, and writes **`kmsg.$N.log`** (`cat /proc/kmsg`) and
   **`ipc_$TIME.$N.log`** (`anyka_ipc` stdout) to the card each boot — the origin of the boot logs
   in `dump/sd_artifacts/`.

`_ak39_factory.ini` is a **separate, narrower** thing: only `[wifi_station]` provisioning
(`ssid=`/`passphrase=`) + `[aging_test]`, read by the app, not an autorun. That is why the bare
`_ak39_factory.ini` attempts on 2026-11-01 drew no reaction — wrong file for code-exec.

Root password hash (from `dump/sd_artifacts/shadow`): `root:$1$M2qq8yA.$…` — MD5-crypt, left
uncracked; unnecessary once you have `debug.ini` code-exec (and the `custom/` payload starts telnet).

## Label

| Field | Value |
|---|---|
| Model | SC49 |
| Power | DC 12 V / 1 A, barrel jack on a pigtail |
| Date code | XF-4724 |
| Marks | FCC logo (**no FCC ID printed**), CE, WEEE, RoHS, "Made in China" |
| QC stickers | QC18 4066, QC11 passed |

## Mechanical / architecture

- White dome PTZ housing, two lenses: fixed wide lens + pan/tilt dome lens. Disassembly was easy
  (screws only, no glue reported).
- **Two PCBs** joined by a yellow kapton-wrapped FPC (markings partly visible: "...9502 ... 1070..."):
  1. **Lens/sensor board** (round-ish, ~45 mm, carries the fixed-lens module on a black holder).
  2. **Main board** (SoC + radio) sitting deeper in the housing — large square package in the middle
     under a glued-on cover/heat spreader. **SoC identified 2026-11-01: top marking `CASW102D4N`**
     (read by eye once the cover was off). This is an **Anyka AK39-family camera SoC** (AK3918-class):
     the `U-Boot 2019.10.0-V4.0.24` banner is Anyka's "AnyCloud" vendor U-Boot signature, the console
     device is `ttySAK0`, and the ULN2803A stepper drive, AIC8800D40L Wi-Fi and XM25QH64D 8 MB NOR all
     match that family. Documented sibling boards (LSC AK3918AV130) ship the near-identical
     `2019.10.0-V4.0.27`. Exact AK39 sub-variant (EV200 / EV300 / EV330 / AV130) still unconfirmed. And the
     Wi-Fi module **AIC8800D40L** (marking read by eye as `A1C8800D40L 2430-3`; AICSemi Wi-Fi 6
     1T1R dual-band + BT 5.4 combo, SDIO/USB module, date code 2024 wk 30). Ordinary 802.11 —
     the kit's "private wireless protocol" is the vendor app, not the radio. Linux drivers:
     OpenIPC `aic8800` package, Thingino `wifi-aic8800`. One other camera kit pairs this module
     with a **Fullhan FH8626V200** video SoC (a lead for ours, unconfirmed). SPI NOR flash next to
     the SoC: **XMC XM25QH64D** (`25QH64DH1Q`, 64 Mbit = 8 MB, SOIC-8, 3.3 V) — the dump target.
- Pigtail: 12 V barrel + a **reset toggle/switch** on the power tail (the second element on the pigtail; not yet pressed).
- **microSD / TF card slot PRESENT (confirmed by Dane 2026-11-01).** Missed in the first teardown pass;
  location on the board still to be photographed. Its presence opens the Anyka SD-card payload route
  (the firmware's boot-time SD autorun), the preferred non-destructive way into AK39 cameras — see
  "SD-card payload route" below.
- Motor wiring into the gimbal: one 5-wire bundle (yellow, blue, brown/orange, red, + one more)
  consistent with a 5-wire unipolar stepper (28BYJ-48 class) and a separate twisted
  white/black pair (limit/home switch or second motor; unverified). A red/black pair feeds the
  speaker/IR board.

## Lens/sensor board — silkscreen and parts (front, component side)

Reference numbers "4", "5" and a lone "P" are printed near connectors.

| Item | Silkscreen / marking | Notes |
|---|---|---|
| **UART pads** | `RX`, `GND` on a 3-pad row, third pad hidden under the lens barrel (presumably `TX`) | Right of the small dome (ambient-light / IR-cut sensor). Prime console candidate; 3.3 V assumed, probe with the Nucleo bridge. |
| LED header, 4-pin | `GND GRE RED IR` | Status LEDs (green/red) + IR illuminator drive. White-light LEDs not on this header — probably on the speaker/LED board. |
| Mic pads | `MIC+ MIC-` | Electret mic on wires. |
| 6-pin JST-style connector | – | Red+black wires populate two positions in the photo; others free. Likely power + speaker/LED. |
| 2-pin JST, top left | – | Red/black to the fixed-lens module? (unverified) |
| TSSOP, ~24 pin | **`ULN2803A`** / `5C432AXK`, hatched "Z" logo (read by eye) | 8-channel Darlington sink array = two 4-coil unipolar steppers driven directly from SoC GPIO. **Confirms the pan and tilt motors are 5-wire unipolar steppers (28BYJ-48 class)** and that the gimbal can be commandeered by driving the ULN inputs (3.3/5 V logic) or the coils directly. |
| 8-pin SOIC | unreadable | Near the mic pads; EEPROM or small SPI flash, *unconfirmed*. |
| Inductor | `4R7` | 4.7 µH, buck for the sensor rail. |
| 6-pin SOT IC | – | Near the lens holder, probably a sensor-rail LDO. |

## Console (serial)

Three unlabeled round through-hole pads beside the copper mounting ring on the lens board (the
`RX`/`GND` silkscreen sits by the nearby series resistors, not by the pads). Found by continuity
(ring → GND pad) and by listening: one end pad is **GND**, the opposite end pad is **TX** (3.3 V idle,
transmits at boot), the middle pad idles at 3.3 V with no traffic and is presumed **RX**.
Logic level **3.3 V**, **115200 8N1**. Probed with the Nucleo-32 UART bridge (`harness probe`) from
the m700 node.

First 72 bytes after a 12 V power-cycle, then silence for the rest of the boot:

```
\x00NbA
U-Boot 2019.10.0-V4.0.24 (May 09 2024 - 14:35:39 +0800)

860
```

The vendor U-Boot (2019.10 with a `-V4.0.24` suffix, built 2024-05-09 UTC+8) silences the console
after the banner; no kernel log follows. SoC still unidentified from this alone.

**Input is ignored (so far):** flooding space / CR / Ctrl-C / ESC into pad 2 from before power-on
produced no echo and no prompt; a blind `setenv silent` + `version` / `printenv` got nothing; Enter
and `root` after Linux would be up got nothing. Byte counter rose by exactly the 73 banner bytes.
The camera itself boots normally (motor/LED/speaker startup routine ~5-7 s after power). Prime
suspect: the SMD footprint beside the `RX` silkscreen looks like **two tinned pads with no part
between them** = factory-unpopulated series resistor on the RX line, so pad 2 never reaches the
SoC. Fix = solder-bridge the footprint (0 Ω), then retry the key flood.

## Network behaviour

No base station exists here (cameras bought as a bare lot), so the camera has nothing to join.

**Tested 2026-10-29 (controlled off/on, forced rescans).** Eight forced scans over two minutes with
the camera unplugged, then eight more with it powered (30 s after power-on, boot routine complete),
laptop radio ~0.5 m from the open camera. Every scan covered both bands (2412-2462 and 5220-5745
MHz were all populated). The hidden 5 GHz BSSID suspected the night before (D6:BE:DC:6D:A4:AB)
appeared in **neither** run, and the only BSSID unique to the camera-on run was a neighbour's phone
hotspot. The suspect AP's beacon timer (TSF) was within seconds of the home router's own 5 GHz
BSS and ~99 days old, i.e. it belongs to the home network, not to a camera first powered the day
before. **Conclusion: the SC49 does not stand up its own Wi-Fi AP when powered without an NVR.**
It is almost certainly a station pre-bound to the kit NVR's private SSID, probing for it.

Next network route, in order: (1) monitor-mode capture of the camera's probe requests (the lab
laptop's radio supports monitor mode; the OpenWrt router can also run tcpdump) to learn the SSID it
wants, then stand up an AP with that SSID/PSK as a fake NVR; (2) BLE scan while the camera boots
(AIC8800D40L has BT; some app-paired cameras advertise for provisioning); (3) if neither, the
console pads and the gimbal coils remain the ways in.

## Open questions (in order)

1. ~~SoC and SPI-flash part numbers on the main board~~ → **SoC = Anyka `CASW102D4N` = AK3918AV100-C; flash = XM25QH64D 8 MB** (sub-variant resolved 2026-11-04 from the extracted kernel log, CPU ID `0x535335`). Whether OpenIPC/Thingino's `anyka` target covers this unit is now answerable offline against the extracted rootfs/kernel rather than needing the live board.
2. ~~Read the TSSOP "Z" chip marking~~ → ULN2803A (done).
3. ~~UART: confirm TX pad, voltage, baud~~ → **found** (see Console). ~~Does U-Boot accept a key; is there a Linux shell after the silence~~ → **resolved 2026-11-04**: U-Boot console input is genuinely closed (bootdelay ~0), but `inittab` runs `getty -L ttySAK0 115200` — the *Linux* console has a login prompt all along; the "silent after banner" was U-Boot muting the kernel console, not the absence of a shell. A login needs the root password (hash recovered), but code-exec via `debug.ini` makes the serial login moot.
4. ~~Wi-Fi module part~~ → AIC8800D40L, plain Wi-Fi (done). **Settled: it is a STA, not an AP** (controlled off/on scan 2026-10-29, both bands). Still open: the SSID it probes for (monitor-mode capture). **No NVR on hand** — the cameras came as a bare lot of three, so the kit's base-station network does not exist here; any network route means standing in for the NVR.
5. Motor driver + wire map for pan and tilt; are there home/limit switches?
6. Power tree: can the main board run from 5 V after the 12 V buck?

## Log

- 2026-11-04: **axis closed — both routes in succeeded; firmware extracted; `debug.ini` root code-exec
  mechanism identified** (see "STATUS 2026-11-04" at top). Fresh-camera SPI read (2× stable 8 MB
  dumps), SD-hijack boot onto the lab AP, flash carved + both squashfs unpacked. Device = Anyka
  AK3918AV100-C, Linux 4.4.282, firmware V4.9.82 (2024-10-18). Correction to 2026-11-01: this build
  DOES honor an SD convention — `debug.ini` (bind-mounts `anyka_ipc_nostrip` over the app = root RCE,
  and dumps `kmsg`/`ipc` logs), not `_ak39_factory.ini` (wifi-station provisioning only). Artifacts
  archived under `dump/`.
- 2026-11-01: **main-board SoC marking read: `CASW102D4N` → Anyka AK39 family** (resolves open
  question 1). This reframes the silent-console problem: on documented AK39 cameras the serial
  console input *does* work (owners reach the U-Boot prompt and Linux telnet), so our banner-then-
  silence is most likely (a) the factory-unpopulated RX series-resistor footprint by the `RX`
  silkscreen leaving our keys off the SoC RX pin, and/or (b) the vendor U-Boot setting `silent=1`
  right after the banner (which also mutes the kernel console). Anyka AK39 U-Boot keeps its
  environment at **SPI-NOR offset 0x40000**, so the SPI-flash dump (XM25QH64D) reads `bootdelay`,
  `silent` and `bootargs` directly — independent of whether the RX line works. Receive path verified
  healthy this session (Nucleo RX counter high, banner captured clean, idle line reads 0 bytes when
  camera off). Nucleo TX (PA9) post-short health NOT yet cleared — needs a D1↔D0 loopback run.
- 2026-10-31: second console session, header soldered this time. Probe on the m700 again, continuous
  space flood into pad 2 across two 12 V power cycles (18:41, 18:43). Both boots: the 73-byte U-Boot
  banner, byte-identical to 10-28, then silence; no echo, no prompt. **While the camera is unpowered,
  the flood on pad 2 comes back on pad 3** (~9 KB per window of 0x20 and bit-shifted 0x02/0x04); it
  stops the instant the board powers up and the banner appears. So pad 2 reaches a powered-down IO pin
  (coupling/back-powering through its protection diodes), not an open pad, and the TX pad is actively
  driven once powered. **Do not drive pad 2 while the camera is off** (back-powers the SoC rail); start
  the flood on power-up. RX still has no effect on U-Boot: either the series footprint by the `RX`
  silkscreen is open, or this vendor U-Boot has console input disabled. Raw captures in
  `runs/sc49_console/` on the m700.
  Later the same evening Dane found **pad 2 shorted to ground** (solder bridge from the new header to
  the GND ring, his reading), cleared it, and a third power cycle (18:54) gave the identical banner-only
  result. The unpowered echo persisted after the fix, so it is crosstalk on the jumper pair, not proof
  that pad 2 reaches an IO pin. Still unresolved: (a) is the series footprint by `RX` open, (b) is
  U-Boot input disabled, (c) did the ~6 min short damage Nucleo PA9 (check: D0-D1 loopback).

- 2026-10-29 (late): controlled off/on Wi-Fi test, 8+8 forced scans, both bands: no AP from the camera; the hidden 5 GHz BSSID was the home network's and absent in both runs. Camera is an NVR-bound station. Next: sniff its probe requests.

- 2026-10-29: hidden 5 GHz AP correlates with camera power (unconfirmed); reset toggle found on the power tail; web search confirms no public docs for the camera on its own. Bench paused (no more power cycles tonight).
- 2026-10-29: flash read by eye = XM25QH64D (8 MB). Camera runs its startup routine 5-7 s after power → Linux+app alive, console muted. RX footprint by the label looks unpopulated.
- 2026-10-29: Wi-Fi module read by eye = AIC8800D40L. Blind U-Boot key flood (space/CR/^C/ESC) attempted; jumpers too unstable, pausing to solder the header.
- 2026-10-28: console found on the 3-pad header, 115200, U-Boot 2019.10.0-V4.0.24 banner then silence. Probe ran on the m700 (Nucleo on its USB).
- 2026-10-28: TSSOP read by eye = ULN2803A → steppers confirmed. Main-board SoC is under a non-removable cover.
- 2026-10-28: housing opened; label and lens-board front photographed via the desk cam; UART pads
  found on the lens board.
