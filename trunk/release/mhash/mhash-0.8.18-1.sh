#!/bin/bash
# This file contains instructions on how to build the mhash and mhash-devel
# binary packages from the mhash source package.
#
# You can run this file as shellscript in bash to create the binary packages
# automatically.
#
# WARNING: Running this file will modify your cygwin installation (it will
# install mhash). Read this file before you execute it!
#
# This shell script...
# ...requires: source package in current directory
#
# ...provides: binary packages mhash and mhash-devel in /
#
VERSION=0.8.18
RELEASE=1
LABEL=$VERSION-$RELEASE

# copy this file into /usr/share/doc/Cygwin
cp ./mhash-$LABEL.README /usr/share/doc/Cygwin
cp ./mhash-devel-$LABEL.README /usr/share/doc/Cygwin

# untar the source package
tar xvfj mhash-$LABEL-src.tar.bz2

# cd into the source directory
cd mhash-$LABEL

# this runs aclocal, autoconf and automake (this is necessary)
# on my system there were a few perl errors - everything works if you ignore them
./buildconf

# run ./configure
./configure --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/sbin/ --localstatedir=/var --datadir=/usr/share --mandir=/usr/share/man --infodir=/usr/share/info

# run make and make check
make
make check

# if "make check" runs without errors, install everything
make install

# install documentation
rm -rf /usr/share/doc/mhash-$VERSION/
mkdir /usr/share/doc/mhash-$VERSION/
cp doc/example.c /usr/share/doc/mhash-$VERSION/
cp AUTHORS /usr/share/doc/mhash-$VERSION/
cp COPYING /usr/share/doc/mhash-$VERSION/
cp INSTALL /usr/share/doc/mhash-$VERSION/
cp NEWS /usr/share/doc/mhash-$VERSION/
cp README /usr/share/doc/mhash-$VERSION/
cp THANKS /usr/share/doc/mhash-$VERSION/
cp TODO /usr/share/doc/mhash-$VERSION/

# create the mhash binary package
cd /
tar cvfj mhash-$LABEL.tar.bz2 \
usr/bin/cygmhash-2.dll \
usr/share/doc/mhash-$VERSION/AUTHORS \
usr/share/doc/mhash-$VERSION/COPYING \
usr/share/doc/mhash-$VERSION/INSTALL \
usr/share/doc/mhash-$VERSION/NEWS \
usr/share/doc/mhash-$VERSION/README \
usr/share/doc/mhash-$VERSION/THANKS \
usr/share/doc/mhash-$VERSION/TODO \
usr/share/doc/Cygwin/mhash-$LABEL.README

# create the mhash-devel binary package
cd /
tar cvfj mhash-devel-$LABEL.tar.bz2 \
usr/lib/libmhash.dll.a \
usr/lib/libmhash.la \
usr/include/mhash.h \
usr/share/man/man3/mhash.3 \
usr/share/doc/mhash-$VERSION/example.c \
usr/share/doc/Cygwin/mhash-devel-$LABEL.README
