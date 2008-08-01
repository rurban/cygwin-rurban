#!/bin/sh

for f in clamd freshclam; do
  if [ ! -e /etc/$f.conf ]; then
    cp etc/defaults/etc/$f.conf /etc/$f.conf
  fi
done

# update the database (/usr/share/clamav/)
# no: /etc/freshclam.conf needs now a database country specific mirror entry
# /usr/bin/freshclam
