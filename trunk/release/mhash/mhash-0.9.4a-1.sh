#!/bin/sh
#custom vars
#where to drop the cygwin packages
rsync_up_target="xarch:software/cygwin/release"

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
export VER=`echo $tscriptname | sed -e "s/${PKG}\-//" -e 's/\-[^\-]*$//'`
export REL=`echo $tscriptname | sed -e "s/${PKG}\-${VER}\-//"`
export BASEPKG=${PKG}-${VER}
export FULLPKG=${BASEPKG}-${REL}

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
export src_pkg_name=${FULLPKG}-src.tar.bz2
export src_patch_name=${FULLPKG}.patch
export bin_pkg_name=${FULLPKG}.tar.bz2

export src_pkg=${topdir}/${src_pkg_name}
export src_patch=${topdir}/${src_patch_name}
export bin_pkg=${topdir}/${bin_pkg_name}
export srcdir=${topdir}/${BASEPKG}
export objdir=${srcdir}/.build
export instdir=${srcdir}/.inst
export srcinstdir=${srcdir}/.sinst
export checkfile=${srcinstdir}/make-check.log

prefix=/usr
sysconfdir=/etc
localstatedir=/var
if [ -z "$MY_CFLAGS" ]; then
  MY_CFLAGS="-O3"
fi
if [ -z "$MY_LDFLAGS" ]; then
  MY_LDFLAGS=-Wl,--enable-auto-image-base
fi

export install_docs="\
	ABOUT-NLS \
	ANNOUNCE \
	AUTHORS \
	BUG-REPORTS \
	CHANGES \
	CONTRIBUTORS \
	COPYING \
	COPYRIGHT \
	CREDITS \
	CHANGELOG \
	ChangeLog* \
	FAQ* \
	HOW-TO-CONTRIBUTE \
	INSTALL \
	KNOWN_BUGS \
	LEGAL \
	LICENSE \
	MISSING_FEATURES \
	NEWS \
	NOTES \
	PROGLIST \
	README \
	README.* \
	RELEASE_NOTES \
	THANKS \
	TODO \
	doc/md5-rfc1321.txt \
	doc/skid2-authentication \
"
export install_docs="`for i in ${install_docs}; do echo $i; done | sort -u`"
export test_rule=""
if [ -z "$SIG" ]; then
  export SIG=0	# set to 1 to turn on signing by default
fi

# helper function
# unpacks the original package source archive into ./${BASEPKG}/
# change this if the original package was not tarred
# or if it doesn't unpack to a correct directory
unpack() {
  tar xv${opt_decomp}f "$1"
  # packaging inconsistency
  if [ "${VER}" = "0.9.4a" -a -d ${PKG}-0.9.4 ]; then 
    mv ${PKG}-0.9.4 ${BASEPKG}
    rm -rf ${BASEPKG}/autom4te.cache
    #find ${BASEPKG} -type d -name CVS -exec rm -rf \{\} \;
  fi
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
  if [ -d ${srcdir} ]; then rm -rf ${srcdir}; fi && \
  unpack ${src_orig_pkg} && \
  cd ${topdir} && \
  if [ -f ${src_patch} ] ; then \
    patch -b -N -Z -p0 < ${src_patch} && (\
    find ${srcdir} -name \*.orig | xargs --no-run-if-empty chmod u+rw ;\ 
    rm ${srcdir}/CYGWIN-PATCHES/*.orig ) \
  fi && \
  mkdirs )
}
conf() {
  (cd ${objdir} && \
  CFLAGS="${MY_CFLAGS}" LDFLAGS="${MY_LDFLAGS}" \
  ${srcdir}/configure \
  --srcdir=${srcdir} --prefix="${prefix}" \
  --exec-prefix='${prefix}' --sysconfdir="${sysconfdir}" \
  --libdir='${prefix}/lib' --includedir='${prefix}/include' \
  --mandir='${prefix}/share/man' --infodir='${prefix}/share/info' \
  --libexecdir='${sbindir}' --localstatedir="${localstatedir}" \
  --datadir='${prefix}/share' --with-docdir="${prefix}/share/doc/${BASEPKG}" && \
  cp ${objdir}/config.log ${srcinstdir}/ )
}
reconf() {
  (cd ${topdir} && \
  rm -fr ${objdir} && \
  mkdir -p ${objdir} && \
  echo "autoreconf'ing ${srcdir}..." && \
  cd ${srcdir} \
    rm aclocal.m4; aclocal && \
    libtoolize -c --force && \
    autoheader -f && \
    automake -a -c
    autoconf -f 
  # make distclean
  conf )
}
build() {
  (cd ${objdir} && \
  CFLAGS="${MY_CFLAGS}" make 2>&1 | tee ${srcinstdir}/make.log 2>&1 )
#  (cd ${srcdir} && \
#  CFLAGS="${MY_CFLAGS}" make -C contrib | tee ${srcinstdir}/make-contrib.log 2>&1 )
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
  make install DESTDIR=${instdir} | tee ${srcinstdir}/make-install.log 2>&1
  #mv ${instdir}/usr/lib/*.dll ${instdir}/usr/bin/
  for f in ${prefix}/share/info/dir ${prefix}/info/dir ; do \
    if [ -f ${instdir}${f} ] ; then \
      rm -f ${instdir}${f} ; \
    fi ;\
  done &&\
  for d in ${prefix}/share/doc/${BASEPKG} ${prefix}/share/doc/Cygwin ; do \
    if [ ! -d ${instdir}${d} ] ; then \
      mkdir -p ${instdir}${d} ;\
    fi ;\
  done &&\
  if [ -d ${instdir}${prefix}/share/info ] ; then \
    find ${instdir}${prefix}/share/info -name "*.info" | xargs -r gzip -q ; \
  fi && \
  if [ -d ${instdir}${prefix}/share/man ] ; then \
    find ${instdir}${prefix}/share/man -name "*.1" -o -name "*.3" -o \
      -name "*.3x" -o -name "*.3pm" -o -name "*.5" -o -name "*.6" -o \
      -name "*.7" -o -name "*.8" | xargs gzip -q ; \
  fi && \
  templist="" && \
  for f in ${install_docs} ; do \
    if [ -f ${srcdir}/$f ] ; then \
      templist="$templist ${srcdir}/$f"; \
    fi ; \
  done && \
  if [ ! "x$templist" = "x" ]; then \
    /usr/bin/install -m 644 $templist \
         ${instdir}${prefix}/share/doc/${BASEPKG} ; \
  fi && \
  if [ -f ${srcdir}/CYGWIN-PATCHES/${PKG}.README ]; then \
    /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/${PKG}.README \
      ${instdir}${prefix}/share/doc/Cygwin/${BASEPKG}.README ; \
  elif [ -f ${srcdir}/CYGWIN-PATCHES/README ] ; then \
    /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/README \
      ${instdir}${prefix}/share/doc/Cygwin/${BASEPKG}.README ; \
  fi && \
  if [ -f ${srcdir}/CYGWIN-PATCHES/${PKG}.sh ] ; then \
    if [ ! -d ${instdir}${sysconfdir}/postinstall ]; then \
      mkdir -p ${instdir}${sysconfdir}/postinstall ; \
    fi && \
    /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/${PKG}.sh \
      ${instdir}${sysconfdir}/postinstall/${PKG}.sh ; \
  elif [ -f ${srcdir}/CYGWIN-PATCHES/postinstall.sh ] ; then \
    if [ ! -d ${instdir}${sysconfdir}/postinstall ]; then \
      mkdir -p ${instdir}${sysconfdir}/postinstall ; \
    fi && \
    /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/postinstall.sh \
      ${instdir}${sysconfdir}/postinstall/${PKG}.sh ; \
  fi && \
  if [ -f ${srcdir}/CYGWIN-PATCHES/preremove.sh ] ; then \
    if [ ! -d ${instdir}${sysconfdir}/preremove ]; then \
      mkdir -p ${instdir}${sysconfdir}/preremove ; \
    fi && \
    /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/preremove.sh \
      ${instdir}${sysconfdir}/preremove/${PKG}.sh ; \
  fi )
}
strip() {
  (cd ${instdir} && \
  find . -name "*.dll" -or -name "*.exe" | xargs strip 2>&1 ; \
  true )
}
list() {
  (cd ${instdir} && \
  find . -name "*" ! -type d | sed 's%^\.%  %' ; \
  true )
}
depend() {
  (cd ${instdir} && \
  find ${instdir} -name "*.exe" -o -name "*.dll" | xargs cygcheck | \
    sed -e '/\.exe/d' -e 's,\\,/,g' | sort -bu | xargs -n1 cygpath -u \
    | xargs cygcheck -f | sed 's%^%  %' | sort -bu ; \
  true )
}
pkg() {
  (cd ${instdir} && \
  tar cvjf ${bin_pkg} * && \
  if [ "${SIG}" -eq 1 ] ; then \
    name=${bin_pkg} text="PKG" sigfile ; \
  fi )
}
difforig() {
  (cd ${topdir} && \
  echo "difforig ${FULLPKG} > ${topdir}/${src_patch_name}" 1>&2
  find ${BASEPKG}/CYGWIN-PATCHES -type f ! -name '*~' ! -name '*.orig*' ! -name '*.log' -print | sort | while read FILE
  do
    echo "$FILE" 1>&2
    diff -N -ub $FILE.orig $FILE # > ${topdir}/${src_patch_name}
  done
  find ${BASEPKG} \( -type d -path "${BASEPKG}/CYGWIN-PATCHES" \) -prune -o  -type f -name '*.orig' -print | sort | while read FILE
  do
    NEW="`dirname $FILE`/`basename $FILE .orig`"
    echo "$NEW" 1>&2
    diff -N -ub $FILE $NEW # > ${topdir}/${src_patch_name}
  done )
}
mkpatchd() {
  $0 difforig > ${src_patch_name}
  true
}
mkpatch() {
  (cd ${srcdir} && \
  find . -name "autom4te.cache" | xargs rm -rf ; \
  unpack ${src_orig_pkg} && \
  mv ${BASEPKG} ../${BASEPKG}-orig && \
  cd ${topdir} && \
  diff -urN -x '.build' -x '.inst' -x '.sinst' -x 'autom4te.cache' \
    ${BASEPKG}-orig ${BASEPKG} > \
    ${srcinstdir}/${src_patch_name} ; \
  rm -rf ${BASEPKG}-orig )
}
spkg() {
  (mkpatch && \
  cd ${srcinstdir} && \
  if [ -e make.log ]; then \ 
    FILES="*.log"; \
    tar cvjf ${FULLPKG}-log.tar.bz2 ${FILES} && rm ${FILES}; \
  fi && \
  cd ${topdir} && \
  if [ "${SIG}" -eq 1 ] ; then \
    name=${src_patch_name} text="PATCH" sigfile ; \
  fi && \
  cp ${src_orig_pkg} ${srcinstdir}/${src_orig_pkg_name} && \
  if [ -e ${src_orig_pkg}.sig ] ; then \
    cp ${src_orig_pkg}.sig ${srcinstdir}/ ; \
  fi && \
  cp ${src_patch_name} ${srcinstdir}/ && \
  cp $0 ${srcinstdir}/ && \
  name=$0 text="SCRIPT" sigfile && \
  if [ "${SIG}" -eq 1 ] ; then \
    cp $0.sig ${srcinstdir}/ ; \
  fi && \
  cd ${srcinstdir} && \
  tar cvjf ${src_pkg} * )
}
up() {
  (cd ${topdir} && \
    FILES="README setup.hint $tscriptname.sh ${src_patch_name} $src_pkg_name $bin_pkg_name" && \
    for f in $FILES; do \
      if [ ! -e $f ]; then if [ -e ${BASEPKG}/CYGWIN-PATCHES/$f ]; then \
        ln -s ${BASEPKG}/CYGWIN-PATCHES/$f $f; \
      fi; fi; \
    done && \
    for f in get.sh ${src_pkg_name}.sig ${bin_pkg_name}.sig ${srcinstdir}/${FULLPKG}-log.tar.bz2; do \
      if [ -e $f ]; then FILES="${FILES} $f"; fi; done && \
    rsync -azL $FILES ${rsync_up_target}/${PKG}/ && \
    ssh $(echo $rsync_up_target| cut -d: -f1) ls -al $(echo $rsync_up_target| cut -d: -f2)/${PKG} && \
    FILES= && \
    true )
}
finish() {
  rm -rf ${srcdir}
}
sigfile() {
  if [ \( "${SIG}" -eq 1 \) -a \( -e $name \) -a \( \( ! -e $name.sig \) -o \( $name -nt $name.sig \) \) ]; then \
    if [ -x /usr/bin/gpg ]; then \
      echo "$text signature need to be updated"; \
      rm -f $name.sig; \
      /usr/bin/gpg --detach-sign $name; \
    else \
      echo "You need the gnupg package installed in order to make signatures."; \
    fi; \
  fi
}
checksig() {
  if [ -x /usr/bin/gpg ]; then \
    if [ -e ${src_orig_pkg}.sig ]; then \
      echo "ORIGINAL PACKAGE signature follows:"; \
      /usr/bin/gpg --verify ${src_orig_pkg}.sig ${src_orig_pkg}; \
    else \
      echo "ORIGINAL PACKAGE signature missing."; \
    fi; \
    if [ -e $0.sig ]; then \
      echo "SCRIPT signature follows:"; \
      /usr/bin/gpg --verify $0.sig $0; \
    else \
      echo "SCRIPT signature missing."; \
    fi; \
    if [ -e ${src_patch}.sig ]; then \
      echo "PATCH signature follows:"; \
      /usr/bin/gpg --verify ${src_patch}.sig ${src_patch}; \
    else \
      echo "PATCH signature missing."; \
    fi; \
  else
    echo "You need the gnupg package installed in order to check signatures." ; \
  fi
}
while test -n "$1" ; do
  case $1 in
    prep)		prep ; STATUS=$? ;;
    mkdirs)		mkdirs ; STATUS=$? ;;
    conf)		conf ; STATUS=$? ;;
    configure)		conf ; STATUS=$? ;;
    reconf)		reconf ; STATUS=$? ;;
    build)		build ; STATUS=$? ;;
    make)		build ; STATUS=$? ;;
    check)		check ; STATUS=$? ;;
    test)		check ; STATUS=$? ;;
    clean)		clean ; STATUS=$? ;;
    install)		install ; STATUS=$? ;;
    list)		list ; STATUS=$? ;;
    depend)		depend ; STATUS=$? ;;
    strip)		strip ; STATUS=$? ;;
    package)		pkg ; STATUS=$? ;;
    pkg)		pkg ; STATUS=$? ;;
    difforig)           difforig ; STATUS=$? ;;
    mkpatch)		mkpatch ; STATUS=$? ;;
    mkpatchd)		mkpatchd ; STATUS=$? ;;
    src-package)	spkg ; STATUS=$? ;;
    spkg)		spkg ; STATUS=$? ;;
    up)			up ; STATUS=$? ;;
    finish)		finish ; STATUS=$? ;;
    checksig)		checksig ; STATUS=$? ;;
    first)		mkdirs && spkg && finish ; STATUS=$? ;;
    all)		checksig && prep && conf && build && check && install && \
			pkg && spkg && finish ; \
			STATUS=$? ;;
    *) echo "Error: bad arguments" ; exit 1 ;;
  esac
  ( exit ${STATUS} ) || exit ${STATUS}
  shift
done
