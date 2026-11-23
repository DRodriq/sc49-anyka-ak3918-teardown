# Getting in: the `debug.ini` SD-card convention

The SC49 firmware has a root code-execution path that needs only an SD card.
It was not documented anywhere we could find, and it is different from the
SD-card conventions used on other Anyka camera firmware (`hack.sh`,
`_ht_av_tuning.conf`, `_ak39_factory.ini`, `update.nor.sh`) — none of those
are honoured here.

## The mechanism

`/usr/sbin/anyka_ipc.sh` (extracted at
[`dump/carve/app/sbin/anyka_ipc.sh`](../dump/carve/app/sbin/anyka_ipc.sh))
starts the camera application. Before doing so it mounts `/dev/mmcblk0p1` at
`/mnt/tf`, and if `/mnt/tf/debug.ini` exists:

```sh
ulimit -c unlimited
echo "/mnt/tf/%e_%t.core" > /proc/sys/kernel/core_pattern
if [ -e $MOUNT_DIR/anyka_ipc_nostrip ];then
    mount --bind $MOUNT_DIR/anyka_ipc_nostrip /usr/bin/anyka_ipc
fi
```

It then runs `/usr/bin/anyka_ipc` as root. So:

1. **`debug.ini` + your own `anyka_ipc_nostrip` on the card = your code runs
   as root at boot.** It does not have to be an ELF; a shell script works.
   No authentication, nothing written to flash.
2. With `debug.ini` present the script also sets `LOG_REDIRECT=1` and writes
   **`kmsg.N.log`** (`/proc/kmsg`) and **`ipc_<time>.N.log`** (app stdout) to
   the card each boot, counting boots in `/mnt/tf/.reboot`. Creating
   `production_test.ini` or `log_no_redirect` on the card turns the log
   redirect off. Example captures: [`dump/boot_capture/`](../dump/boot_capture).

The intended use is evidently a vendor debug hook for running an unstripped
build with core dumps. `debug.ini` can be empty.

## Using it

Ready-made payloads:

- [`sd/minimal/`](../sd/minimal) — root telnet on port 23, camera otherwise
  unchanged.
- [`sd/standalone/`](../sd/standalone) — the same, plus re-pointing the camera
  at your own Wi-Fi.

Practical rules:

- **Always end by `exec`-ing the real application.** The app brings up Wi-Fi
  (it loads the AIC8800 driver itself), so a payload that does not start it
  leaves the camera with no network and nothing to telnet into.
- The card must have a first partition the kernel can mount (`mmcblk0p1`).
  FAT32 on an MBR table is what was used here; exFAT is also built
  (`exfat.ko`) but was not tested.
- Keep a copy of the vendor binary on the card as `anyka_ipc.real`, because
  `/usr/bin/anyka_ipc` is hidden by the bind mount once your wrapper is live.

## Serial console (not a way in)

Three through-hole pads on the lens board: GND, RX (presumed), TX. 3.3 V,
115200 8N1. On power-up it prints

```
U-Boot 2019.10.0-V4.0.24 (May 09 2024 - 14:35:39 +0800)
```

and then nothing. U-Boot does not accept input (boot delay ~0, key floods
ignored) and mutes the kernel console. The footprint next to the `RX`
silkscreen looks like an unpopulated series resistor, so input may not reach
the SoC at all. `inittab` does run `getty -L ttySAK0 115200`, so a login
prompt probably exists behind the mute, but it needs the root password and is
moot given `debug.ini`.

Do not drive the RX pad while the camera is unpowered.

## Root password

`dump/boot_capture/shadow` holds the firmware's root hash (MD5-crypt). It was
not cracked; telnet from the payloads above needs no password.

## SPI flash

XM25QH64D, SOIC-8, 3.3 V, next to the SoC on the main board. Read in circuit
with a clip and programmer; read twice and compare. Partition offsets are in
[`hardware.md`](hardware.md). One unit's chip was destroyed by repeated
heat and 5 V exposure, so use 3.3 V and keep attempts short.
