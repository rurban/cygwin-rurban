#!/bin/sh

[ -e /etc/libtextcat.conf ] && cmp -s /etc/libtextcat.conf /etc/defaults/etc/libtextcat.conf && rm /etc/libtextcat.conf
