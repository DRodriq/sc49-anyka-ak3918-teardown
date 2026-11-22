#!/bin/sh
for D in /dev/ttySAK0 /dev/ttyS0 /dev/console; do
  [ -c "$D" ] && echo "=====FACTORY_AUTORUN_OK via $D=====" > "$D" 2>/dev/null
done
telnetd 2>/dev/null &
