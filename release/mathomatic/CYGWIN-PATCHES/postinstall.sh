#!/bin/sh
f=.mathomaticrc
if [ ! -e /etc/skel/$f ]; then
    cp /etc/defaults/etc/$f /etc/$f
fi
