#!/bin/sh
if [ ! -e /etc/catdocrc ]; then
    cmp -s /etc/catdocrc /etc/defaults/etc/catdocrc && rm /etc/catdocrc
fi
