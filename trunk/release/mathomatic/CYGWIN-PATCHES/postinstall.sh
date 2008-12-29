#!/bin/sh
f=.mathomaticrc
if [ ! -e /etc/$f ]; then
    cp /etc/defaults/etc/skel/$f /etc/$f
fi
