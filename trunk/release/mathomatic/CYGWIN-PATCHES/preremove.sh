#!/bin/sh
f=.mathomaticrc
if [ ! -e /etc/skel/$f ]; then
    cmp -s /etc/skel/$f /etc/defaults/etc/skel/$f && rm /etc/skel/$f
fi
