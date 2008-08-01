#!/bin/sh

for f in clamd freshclam; do
  if [ ! -e /etc/$f.conf ]; then
    cmp -s /etc/$f.conf /etc/defaults/etc/$f.conf && rm /etc/$f.conf
  fi
done

initd=/etc/rc.d/init.d/clamd
# uninstall the service
if [ -e $initd ]; then $initd uninstall; fi
