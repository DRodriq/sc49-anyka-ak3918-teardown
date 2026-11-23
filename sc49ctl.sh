#!/bin/sh
# sc49ctl — LAN control for the de-clouded SC49 (Anyka AK3918AV100) through the
# stock app's own HTTP API. No cloud, no GPIO poking, no app-kills, no reboots.
# Auth is HTTP Basic admin / empty-password. Worked out on the bench 2026-11-23.
#   SC49_HOST  camera IP        (set to your camera's LAN address)
#   GO2RTC     go2rtc host:port (set to your go2rtc host — for `snap`)
set -eu
CAM="${SC49_HOST:-192.168.1.10}"
G2="${GO2RTC:-127.0.0.1:1984}"
U="admin:@$CAM"
ptz(){ curl -s -m6 "http://$U/cgi-bin/hi3510/ptzctrl.cgi?-step=0&-act=$1&-speed=${2:-40}"; echo; }

cmd="${1:-help}"; shift || true
case "$cmd" in
  left|right|up|down|hscan|vscan)
    # sc49ctl left [secs] [speed]  — move; if secs given, auto-stop after
    ptz "$cmd" "${2:-40}"; if [ "${1:-}" ]; then sleep "$1"; ptz stop; fi ;;
  home|stop) ptz "$cmd" ;;
  preset)      curl -s -m6 "http://$U/cgi-bin/hi3510/preset.cgi?-act=goto&-number=${1:?preset N}"; echo ;;
  preset-set)  curl -s -m6 "http://$U/cgi-bin/hi3510/preset.cgi?-act=set&-number=${1:?preset N}"; echo ;;
  image)   curl -s -m6 "http://$U/cgi-bin/hi3510/param.cgi?cmd=getimageattr"; echo ;;
  set)     curl -s -m6 "http://$U/cgi-bin/hi3510/param.cgi?cmd=setimageattr&-${1:?key}=${2:?val}"; echo ;;
  ircut)   curl -s -m6 "http://$U/NetSDK/Image/irCutFilter"; echo ;;
  snap)    out="${2:-/tmp/sc49.jpg}"; curl -s -m10 -o "$out" "http://$G2/api/frame.jpeg?src=${1:-sc49-sub}" && echo "saved $out" ;;
  *) cat <<EOF
sc49ctl — SC49 camera control over the stock app's HTTP API
  pan/tilt:   sc49ctl {left|right|up|down} [secs] [speed]   (secs -> auto-stop)
              sc49ctl {home|stop|hscan|vscan}
  presets:    sc49ctl preset N | preset-set N
  image:      sc49ctl image                 (read hue/brightness/flip/mirror/scene)
              sc49ctl set brightness 60      (setimageattr key val)
  day/night:  sc49ctl ircut                  (read IR-cut state)
  snapshot:   sc49ctl snap [sc49-sub|sc49-main] [outfile]   (via go2rtc)
env: SC49_HOST=$CAM  GO2RTC=$G2
EOF
    ;;
esac
