# SC49 — control plane, feed, and resume notes

Worked out on the bench 2026-11-23 against the live device. This is the "pick it back
up later" handoff: the camera is **de-clouded, LAN-only, and fully drivable through its
own stock app over plain HTTP** — no GPIO hacking, no app-kills, no reboots.

> **State at shelving:** standalone on Wi-Fi + root telnet + **feed + PTZ + image +
> day/night all working**. The only unsolved control is the white flood (see Open items).
> Nothing here requires the SD-card exploit at runtime — it's the normal app, just asked
> nicely over HTTP.

Set `SC49_HOST` to the camera's LAN IP and `GO2RTC` to the go2rtc host:port for the
examples below. Auth is HTTP Basic **`admin`** with an **empty password**.

---

## 1. The feed (local, no cloud)

Stock firmware ships **no standard RTSP/ONVIF** — only a static **N1 server on port 80**
(proprietary EseeCloud/dvr163 protocol) that streams H.265. Bridge it to standard
RTSP/WebRTC with **[go2rtc](https://github.com/AlexxIT/go2rtc)**'s `eseecloud` module:

```yaml
# go2rtc.yaml
streams:
  sc49-main: eseecloud://admin:@$SC49_HOST:80/livestream/11   # stitched dual-lens, H.265
  sc49-sub:  eseecloud://admin:@$SC49_HOST:80/livestream/12   # 640x720 H.265 + G711 audio
api:  { listen: ":1984" }
rtsp: { listen: ":8554" }
webrtc: { listen: ":8555" }
```

Run `go2rtc -config go2rtc.yaml`, then view `rtsp://$GO2RTC/sc49-main` (VLC/Frigate/
Mainsail) or the web UI at `http://$GO2RTC`. Channels: **11=main, 12=sub** (others 404).

Keep the vendor app running and the WAN-egress block in place — that's what makes it
LAN-only. See `standalone.md` for the de-NVR / de-cloud config.

---

## 2. Control plane — HTTP API on port 80 (`admin`, empty password)

| Function | Request | Notes |
|---|---|---|
| **Pan/tilt** | `/cgi-bin/hi3510/ptzctrl.cgi?-step=0&-act={left,right,up,down,home,stop,hscan,vscan}&-speed=N` | returns `[Success] ptz ok`; continuous until `stop` |
| **Presets** | `/cgi-bin/hi3510/preset.cgi?-act={set,goto}&-number=N` | set saves current position |
| **Image read** | `/cgi-bin/hi3510/param.cgi?cmd=getimageattr` | hue/brightness/saturation/contrast/scene/flip/mirror |
| **Image set** | `/cgi-bin/hi3510/param.cgi?cmd=setimageattr&-KEY=VAL` | e.g. `-brightness=60` |
| **Day/night (read)** | `/NetSDK/Image/irCutFilter` | `{"irCutMode":"light"}` = auto by light sensor |
| **Image tree** | `/NetSDK/Image` (also `/denoise3d`, `/wdr`, `/videoMode`, `/manualSharpness`) | REST leaves |

Other registered CGIs: `echo.cgi`, `gw2.cgi`, `upload.cgi`, `vcode.cgi`,
`upgrade_rate.cgi`. NetSDK tree is sparse — only `Image/*` and `System/ledpwm` leaves
respond; there is **no** Alarm/Event tree over HTTP.

### `sc49ctl.sh`

Wraps all of the above:

```
sc49ctl {left|right|up|down} [secs] [speed]   # secs -> auto-stop
sc49ctl {home|stop|hscan|vscan}
sc49ctl preset N | preset-set N
sc49ctl image                                  # read image attrs
sc49ctl set brightness 60                      # setimageattr
sc49ctl ircut                                  # read IR-cut state
sc49ctl snap [sc49-sub|sc49-main] [outfile]    # grab a JPEG via go2rtc
env: SC49_HOST (default lab IP), GO2RTC (default lab host:port)
```

---

## 3. Hardware GPIO map (reference — prefer the HTTP API above)

`/sys/class/gpio/` while the app runs. Confirmed by driving the stream and reading a
**local** brightness/colour reducer (`probe_cam.py`), not by eye:

- **gpio69 = IR-cut filter** — the mechanical "tick" at boot. `=0` opens the filter →
  infrared floods the sensor (R+B rise, G falls = magenta cast); `=1` = day (IR blocked).
  Reverts clean, no reboot. The app re-asserts it from the light sensor, so this is for
  momentary testing, not persistent override (use day/night config for that).
- **gpio49 = ambient light sensor** (input; the app reads it for auto day/night).
- **gpio1 / gpio55 / gpio56 / gpio98** — no daytime-observable effect. gpio56 is the
  likely IR illuminator but ambient sunlight IR masks it; **retest in the dark**
  (`gpio69=0` + `gpio56=1` → brightness should jump). No sysfs PWM on this board.

The app owns the LEDs/IR at the *level* layer (`nInfraRedLevel`, `nWhiteLightLevel`,
`nIrcutMode`), compiled into the binary — which is why raw-pin pokes don't light the flood.

---

## 4. Verification method (reuse this)

Drive via HTTP, verify with a **local** reducer so no camera frames leave the LAN (this
is a de-clouding project — don't pipe raw frames to a cloud model):

- `probe_cam.py` — pulls a go2rtc snapshot, computes brightness (per lens-half + per RGB
  channel), abs-diff, and ORB rotation via the drift-harness `vision.py`; prints **metrics
  only**. A 35%+ `pct_changed` between before/after = the PTZ physically moved.
- `camsh.py` — raw-telnet (`:23`) shell helper to the camera for sysfs/GPIO pokes.

(Both live with the lab tooling, not this repo; reproduce from the notes here.)

---

## 5. Open items (what's NOT solved)

- **White flood (Spotlight-V100 / `AlarmWhiteLight`)** — not reachable over HTTP; gated
  behind the **binary N1 protocol** (`N1Device_EvtProductSetWhiteLightLevel`, serves the
  phone app only). `ledpwm` reports `channelCount:0`. Reads as a motion-alarm *flash*,
  not a steady lamp. To control it you'd reverse the N1 command frames (go2rtc's
  `eseecloud` source is the protocol reference) — **low value for most uses; parked.**
- **Day/night write** — `PUT /NetSDK/Image/irCutFilter {"irCutMode":"day"}` reaches the
  handler but returns `statusCode:2 Device Error`; needs the correct/full JSON schema
  (probably set `irCutControlMode` first). Hardware fallback = gpio69.
- **IR illuminator pin** — unconfirmed; needs a dark-scene retest (see §3).

---

## 6. Resume checklist (shelved → running)

1. Power the camera; it rejoins Wi-Fi standalone (per `standalone.md`) and gets its DHCP
   lease. Confirm egress is still blocked at the gateway.
2. `telnet $SC49_HOST` (port 23, root, no auth) if you need a shell.
3. Start go2rtc with the config in §1 → feed on `rtsp://$GO2RTC/sc49-main`.
4. `sc49ctl image` / `sc49ctl home` to confirm the control plane answers.

---

## 7. If building a dedicated enclosure cam instead

The SC49 covers monitoring for ~0 cost, but a ground-up cam has a higher ceiling (color
lighting, on-sensor CV, native lab integration). What that path needs:

- **Compute + sensor** — a Pi-class board + CSI or USB camera (wide-angle for full-bed, or
  a macro for first-layer). Mount the compute **outside** the enclosure; only the sensor
  inside (heat).
- **Lighting** — a controllable **white** LED strip (the SC49's real gap; IR is grayscale
  and glares on glossy prints). Drive from a spare GPIO/relay.
- **Heat** — a passive PLA/PETG enclosure sits ~30–40 °C (fine); an ABS/ASA chamber runs
  ~45–55 °C and will stress consumer camera electronics/lube. Design for the hotter case
  or keep electronics out of the chamber. *This is also the main risk of leaving the SC49
  in a hot enclosure long-term.*
- **Software** — stream via go2rtc/Mainsail/Frigate; register as a **witness in
  `vision_lab.py`'s** metric frame so first-layer / spaghetti CV writes into the fab-loop
  event log (could auto-abort a failed print via `fab.py`).
- **Note** — the lab Pi 3B is earmarked for the rover's egocentric vision; a printer cam
  competes for it. Trigger this build only when that's free or a concrete SC49 wall
  appears (heat death, need for on-sensor/global-shutter CV, vendor-app flakiness).

You can get most of the CV value **without** new hardware by feeding the SC49's RTSP into
`vision_lab.py` as a witness today — pure software.
