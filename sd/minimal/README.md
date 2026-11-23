# sd/minimal — root shell, nothing else changed

The smallest payload that proves the `debug.ini` way in (see
[`docs/access.md`](../../docs/access.md)). Verified on the bench.

Copy to the root of a FAT32 SD card:

| File | Source |
|---|---|
| `debug.ini` | this directory (empty file; only its presence matters) |
| `anyka_ipc_nostrip` | this directory |
| `anyka_ipc.real` | a copy of the vendor app: `dump/carve/app/bin/anyka_ipc`, or `/usr/bin/anyka_ipc` from your own unit |

Boot with the card inserted. The wrapper writes `netinfo.txt` to the card,
starts an unauthenticated root `telnetd` on port 23, then execs the vendor app
so the camera behaves normally. The firmware also writes `kmsg.N.log` and
`ipc_*.N.log` to the card on every boot while `debug.ini` is present.

Remove the card (or `debug.ini`) to return to stock behaviour; nothing on the
flash is modified.
