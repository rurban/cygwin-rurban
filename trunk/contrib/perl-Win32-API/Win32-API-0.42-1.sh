#!/bin/sh
#
# Generic package build script
#
# $Id: generic-build-script,v 1.19 2004/02/24 23:50:16 igor Exp $
#
# Package maintainers: if the original source is not distributed as a
# (possibly compressed) tarball, set the value of ${src_orig_pkg_name},
# and redefine the unpack() helper function appropriately.
# Also, if the Makefile rule to run the test suite is not "test", change
# the definition of ${test_rule} below.

# find out where the build script is located
tdir=`echo "$0" | sed 's%[\\/][^\\/][^\\/]*$%%'`
test "x$tdir" = "x$0" && tdir=.
scriptdir=`cd $tdir; pwd`
# find src directory.
# If scriptdir ends in SPECS, then topdir is $scriptdir/..
# If scriptdir ends in CYGWIN-PATCHES, then topdir is $scriptdir/../..
# Otherwise, we assume that topdir = scriptdir
topdir1=`echo ${scriptdir} | sed 's%/SPECS$%%'`
topdir2=`echo ${scriptdir} | sed 's%/CYGWIN-PATCHES$%%'`
if [ "x$topdir1" != "x$scriptdir" ] ; then # SPECS
  topdir=`cd ${scriptdir}/..; pwd`
else
  if [ "x$topdir2" != "x$scriptdir" ] ; then # CYGWIN-PATCHES
    topdir=`cd ${scriptdir}/../..; pwd`
  else
    topdir=`cd ${scriptdir}; pwd`
  fi
fi

tscriptname=`basename $0 .sh`
export PKG=`echo $tscriptname | sed -e 's/\-[^\-]*\-[^\-]*$//'`
export PKG2=perl-${PKG}
export PKG3=lib${PKG}-devel
export VER=`echo $tscriptname | sed -e "s/${PKG}\-//" -e 's/\-[^\-]*$//'`
export REL=`echo $tscriptname | sed -e "s/${PKG}\-${VER}\-//"`
export BASEPKG=${PKG}-${VER}
export BASEPKG2=${PKG2}-${VER}
export BASEPKG3=${PKG3}-${VER}
export FULLPKG=${BASEPKG}-${REL}
export FULLPKG2=${BASEPKG2}-${REL}
export FULLPKG3=${BASEPKG3}-${REL}

# determine correct decompression option and tarball filename
export src_orig_pkg_name=
if [ -e "${src_orig_pkg_name}" ] ; then
  export opt_decomp=? # Make sure tar punts if unpack() is not redefined
elif [ -e ${BASEPKG}.tar.bz2 ] ; then
  export opt_decomp=j
  export src_orig_pkg_name=${BASEPKG}.tar.bz2
elif [ -e ${BASEPKG}.tar.gz ] ; then
  export opt_decomp=z
  export src_orig_pkg_name=${BASEPKG}.tar.gz
elif [ -e ${BASEPKG}.tgz ] ; then
  export opt_decomp=z
  export src_orig_pkg_name=${BASEPKG}.tgz
elif [ -e ${BASEPKG}.tar ] ; then
  export opt_decomp=
  export src_orig_pkg_name=${BASEPKG}.tar
else
  echo Cannot find original package.
  exit 1
fi

export src_orig_pkg=${topdir}/${src_orig_pkg_name}

# determine correct names for generated files
export src_pkg_name=${FULLPKG2}-src.tar.bz2
export src_patch_name=${FULLPKG2}.patch
export bin_pkg_name=${FULLPKG}.tar.bz2
export bin_pkg2_name=${FULLPKG2}.tar.bz2
export bin_pkg3_name=${FULLPKG3}.tar.bz2

export src_pkg=${topdir}/${src_pkg_name}
export src_patch=${topdir}/${src_patch_name}
export bin_pkg=${topdir}/${bin_pkg_name}
export bin_pkg2=${topdir}/${bin_pkg2_name}
export bin_pkg3=${topdir}/${bin_pkg3_name}
export srcdir=${topdir}/${BASEPKG}
export objdir=${srcdir}/.build
export instdir=${srcdir}/.inst
export srcinstdir=${srcdir}/.sinst
export checkfile=${topdir}/${FULLPKG2}.check

prefix=/usr
sysconfdir=/etc
pnoslash=`echo ${prefix} | sed 's%^/%%'`
snoslash=`echo ${sysconfdir} | sed 's%^/%%'`

if [ -z "$MY_CFLAGS" ]; then
  MY_CFLAGS="-O2"
fi
if [ -z "$MY_CFLAGS" ]; then
  MY_LDFLAGS=
fi

export install_docs="\
	ABOUT-NLS \
	ANNOUNCE \
	AUTHORS \
	BUG-REPORTS \
	Changes \
	CONTRIBUTORS \
	COPYING \
	CREDITS \
	ChangeLog* \
	FAQ \
	HOW-TO-CONTRIBUTE \
	INSTALL \
	KNOWNBUG \
	LEGAL \
	LICENCE \
	LICENSE \
	NEWS \
	NOTES \
	PROGLIST \
	README \
	THANKS \
	TODO \
"
#export install_docs=`for i in ${install_docs}; do echo $i; done | sort -u`
export test_rule=test
if [ -z "$SIG" ]; then
  export SIG=0		# set to 1 to turn on signing by default
fi

export MULTIPKG=0	# set to 1 to create multiple binary packages,
			# e.g. when shared libraries are built

# helper function
# unpacks the original package source archive into ./${BASEPKG}/
# change this if the original package was not tarred
# or if it doesn't unpack to a correct directory
unpack() {
  tar xv${opt_decomp}f "$1"
}

mkdirs() {
  (cd ${topdir} && \
  rm -fr ${objdir} ${instdir} ${srcinstdir} && \
  mkdir -p ${objdir} && \
  mkdir -p ${instdir} && \
  mkdir -p ${srcinstdir} )
}
prep() {
  (cd ${topdir} && \
  unpack ${src_orig_pkg} && \
  cd ${topdir} && \
  patch -Z -p0 < ${src_patch} && \
  mkdirs )
}
conf() {
  (cd ${srcdir} && \
  files=`find . -path './.inst' -prune -o -path './.build' -prune -o \
    -path './.sinst' -prune -o -print | sed 's%^.%%'`
  for f in $files ; do \
    if [ -d ${srcdir}$f -a ! -d ${objdir}$f ] ; then \
      mkdir -p ${objdir}$f ; \
    fi ; \
  done && \
  for f in $files ; do \
    ln -sf ${srcdir}$f ${objdir}$f > /dev/null ; \
  done ; \
  cd ${objdir} && \
  /usr/bin/perl Makefile.PL )
}
reconf() {
  (cd ${topdir} && \
  rm -fr ${objdir} && \
  mkdir -p ${objdir} && \
  conf )
}
build() {
  (cd ${objdir} && \
  CFLAGS="${MY_CFLAGS}" make && \
  make manifypods )
}
check() {
  (cd ${objdir} && \
  make ${test_rule} | tee ${checkfile} 2>&1 )
}
clean() {
  (cd ${objdir} && \
  make clean )
}
install() {
  (cd ${objdir} && \
  rm -fr ${instdir}/* && \
  make install DESTDIR=${instdir} && \
  for f in ${prefix}/share/info/dir ${prefix}/info/dir ; do \
    if [ -f ${instdir}${f} ] ; then \
      rm -f ${instdir}${f} ; \
    fi ;\
  done &&\
  find ${instdir} -name "perllocal.pod" -o -name ".packlist" | xargs rm -f && \
  for d in ${prefix}/share/doc/${BASEPKG2} ${prefix}/share/doc/Cygwin ; do \
    if [ ! -d ${instdir}${d} ] ; then \
      mkdir -p ${instdir}${d} ; \
    fi ;\
  done &&\
  if [ -d ${instdir}${prefix}/share/info ] ; then \
    find ${instdir}${prefix}/share/info -name "*.info" | xargs gzip -q ; \
  fi && \
  if [ -d ${instdir}${prefix}/share/man ] ; then \
    find ${instdir}${prefix}/share/man -name "*.1" -o -name "*.3" -o \
      -name "*.3x" -o -name "*.3pm" -o -name "*.5" -o -name "*.6" -o \
      -name "*.7" -o -name "*.8" | xargs gzip -q ; \
  fi && \
  templist="" && \
  for f in ${install_docs} ; do \
    if [ -f ${srcdir}/$f ] ; then \
      templist="$templist ${srcdir}/$f" ; \
    fi ; \
  done && \
  if [ ! "x$templist" = "x" ] ; then \
    /usr/bin/install -m 644 $templist \
         ${instdir}${prefix}/share/doc/${BASEPKG2} ; \
  fi && \
  if [ -f ${srcdir}/CYGWIN-PATCHES/${PKG}.README ] ; then \
    /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/${PKG}.README \
      ${instdir}${prefix}/share/doc/Cygwin/${BASEPKG2}.README ; \
  elif [ -f ${srcdir}/CYGWIN-PATCHES/README ] ; then \
    /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/README \
      ${instdir}${prefix}/share/doc/Cygwin/${BASEPKG2}.README ; \
  fi && \
  if [ "${MULTIPKG}" ] ; then \
    if [ -f ${srcdir}/CYGWIN-PATCHES/${PKG3}.README ] ; then \
      /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/${PKG3}.README \
        ${instdir}${prefix}/share/doc/Cygwin/${BASEPKG3}.README ; \
    fi ; \
  fi && \
  if [ -f ${srcdir}/CYGWIN-PATCHES/${PKG}.sh ] ; then \
    if [ ! -d ${instdir}${sysconfdir}/postinstall ]; then \
      mkdir -p ${instdir}${sysconfdir}/postinstall ; \
    fi && \
    /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/${PKG}.sh \
      ${instdir}${sysconfdir}/postinstall/${PKG}.sh ; \
  elif [ -f ${srcdir}/CYGWIN-PATCHES/postinstall.sh ] ; then \
    if [ ! -d ${instdir}${sysconfdir}/postinstall ] ; then \
      mkdir -p ${instdir}${sysconfdir}/postinstall ; \
    fi && \
    /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/postinstall.sh \
      ${instdir}${sysconfdir}/postinstall/${PKG}.sh ; \
  fi )
}
strip() {
  (cd ${instdir} && \
  find . -name "*.dll" -or -name "*.exe" | xargs -r strip 2>&1 ; \
  true )
}
list() {
  (cd ${instdir} && \
  find . -name "*" ! -type d | sed 's%^\.%  %' ; \
  true )
}
depend() {
  (cd ${instdir} && \
  find ${instdir} -name "*.exe" -o -name "*.dll" | xargs -r cygcheck | \
  sed -e '/\.exe/d' -e 's,\\,/,g' | sort -bu | xargs -r -n1 cygpath -u \
  | xargs -r cygcheck -f | sed 's%^%  %' ; \
  true )
}
pkg() {
  (cd ${instdir} && \
  if [ "${MULTIPKG}" -eq 1 ] ; then \
    tar cvjf ${bin_pkg} * \
      --exclude="${pnoslash}/include" \
      --exclude="${pnoslash}/lib" \
      --exclude="${pnoslash}/bin/*.dll" \
      --exclude="${pnoslash}/share/doc/Cygwin/${PKG3}-${VER}.README" ; \
    tar cvjf ${bin_pkg2} ${pnoslash}/bin/*.dll ; \
    tar cvjf ${bin_pkg3} ${pnoslash}/lib/ \
      ${pnoslash}/include/ \
      ${pnoslash}/share/doc/Cygwin/${PKG3}-${VER}.README ; \
  else \
    tar cvjf ${bin_pkg2} * ; \
  fi )
}
mkpatch() {
  (cd ${srcdir} && \
  find . -name "autom4te.cache" | xargs rm -rf ; \
  unpack ${src_orig_pkg} && \
  mv ${BASEPKG} ../${BASEPKG}-orig && \
  cd ${topdir} && \
  diff -urN -x '.build' -x '.inst' -x '.sinst' \
    ${BASEPKG}-orig ${BASEPKG} > \
    ${srcinstdir}/${src_patch_name} ; \
  rm -rf ${BASEPKG}-orig )
}
spkg() {
  (mkpatch && \
  if [ "${SIG}" -eq 1 ] ; then \
    name=${srcinstdir}/${src_patch_name} text="PATCH" sigfile ; \
  fi && \
  cp ${src_orig_pkg} ${srcinstdir}/${src_orig_pkg_name} && \
  if [ -e ${src_orig_pkg}.sig ] ; then \
    cp ${src_orig_pkg}.sig ${srcinstdir}/ ; \
  fi && \
  cp $0 ${srcinstdir}/`basename $0` && \
  name=$0 text="SCRIPT" sigfile && \
  if [ "${SIG}" -eq 1 ] ; then \
    cp $0.sig ${srcinstdir}/ ; \
  fi && \
  cd ${srcinstdir} && \
  tar cvjf ${src_pkg} * )
}
finish() {
  rm -rf ${srcdir}
}
sigfile() {
  if [ \( "${SIG}" -eq 1 \) -a \( -e $name \) -a \( \( ! -e $name.sig \) -o \( $name -nt $name.sig \) \) ] ; then \
    if [ -x /usr/bin/gpg ] ; then \
      echo "$text signature need to be updated" ; \
      rm -f $name.sig ; \
      /usr/bin/gpg --detach-sign $name ; \
    else \
      echo "You need the gnupg package installed in order to make signatures." ; \
    fi ; \
  fi
}
checksig() {
  if [ -x /usr/bin/gpg ] ; then \
    if [ -e ${src_orig_pkg}.sig ] ; then \
      echo "ORIGINAL PACKAGE signature follows:" ; \
      /usr/bin/gpg --verify ${src_orig_pkg}.sig ${src_orig_pkg} ; \
    else \
      echo "ORIGINAL PACKAGE signature missing." ; \
    fi ; \
    if [ -e $0.sig ] ; then \
      echo "SCRIPT signature follows:" ; \
      /usr/bin/gpg --verify $0.sig $0 ; \
    else \
      echo "SCRIPT signature missing." ; \
    fi ; \
    if [ -e ${src_patch}.sig ] ; then \
      echo "PATCH signature follows:" ; \
      /usr/bin/gpg --verify ${src_patch}.sig ${src_patch} ; \
    else \
      echo "PATCH signature missing." ; \
    fi ; \
  else
    echo "You need the gnupg package installed in order to check signatures." ; \
  fi
}
case $1 in
  prep)		prep ; STATUS=$? ;;
  mkdirs)	mkdirs ; STATUS=$? ;;
  conf)		conf ; STATUS=$? ;;
  configure)	conf ; STATUS=$? ;;
  reconf)	reconf ; STATUS=$? ;;
  build)	build ; STATUS=$? ;;
  make)		build ; STATUS=$? ;;
  check)	check ; STATUS=$? ;;
  test)		check ; STATUS=$? ;;
  clean)	clean ; STATUS=$? ;;
  install)	install ; STATUS=$? ;;
  list)		list ; STATUS=$? ;;
  depend)	depend ; STATUS=$? ;;
  strip)	strip ; STATUS=$? ;;
  package)	pkg ; STATUS=$? ;;
  pkg)		pkg ; STATUS=$? ;;
  mkpatch)	mkpatch ; STATUS=$? ;;
  src-package)	spkg ; STATUS=$? ;;
  spkg)		spkg ; STATUS=$? ;;
  finish)	finish ; STATUS=$? ;;
  checksig)	checksig ; STATUS=$? ;;
  first)	mkdirs && spkg && finish ; STATUS=$? ;;
  all)		checksig && prep && conf && build && install && \
		strip && pkg && spkg; \
		STATUS=$? ;;
  *) echo "Error: bad arguments" ; exit 1 ;;
esac
exit ${STATUS}

