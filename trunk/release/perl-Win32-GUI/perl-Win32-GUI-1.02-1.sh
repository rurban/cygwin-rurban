#!/bin/sh
#where to drop the cygwin packages
rsync_up_target="xarch:software/cygwin/release"
PATH=/bin:/usr/sbin:/usr/local/sbin:/usr/bin:/usr/local/bin:/usr/X11R6/bin

#set -x
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

cd ${topdir}

tscriptname=`basename $0 .sh`
export PKG=`echo $tscriptname | sed -e 's/\-[^\-]*\-[^\-]*$//'`
export VER=`echo $tscriptname | sed -e "s/${PKG}\-//" -e 's/\-[^\-]*$//'`
export REL=`echo $tscriptname | sed -e "s/${PKG}\-${VER}\-//"`
export BASEPKG=${PKG}-${VER}
export FULLPKG=${PKG}-${VER}-${REL}

export ORIG_PKG=`echo $PKG | sed -e 's/^perl-//'`

# determine correct decompression option and tarball filename
if [ -e ${ORIG_PKG}-${VER}.tar.gz ] ; then
  export opt_decomp=z
  export src_orig_pkg_ext=gz
  export src_orig_pkg_name=${ORIG_PKG}-${VER}.tar.gz
elif [ -e ${ORIG_PKG}-${VER}.tar.bz2 ] ; then
  export opt_decomp=j
  export src_orig_pkg_ext=bz2
  export src_orig_pkg_name=${ORIG_PKG}-${VER}.tar.bz2
elif [ -e ${ORIG_PKG}-${VER}.zip ] ; then
  export opt_decomp=
  export src_orig_pkg_name=${ORIG_PKG}-${VER}.zip
fi

export src_pkg_name=${FULLPKG}-src.tar.bz2
export src_patch_name=${FULLPKG}.patch
export bin_pkg_name=${FULLPKG}.tar.bz2

export src_orig_pkg=${topdir}/${src_orig_pkg_name}
export src_pkg=${topdir}/${src_pkg_name}
export src_patch=${topdir}/${src_patch_name}
export bin_pkg=${topdir}/${bin_pkg_name}
export srcdir=${topdir}/${PKG}-${VER}
export objdir=${srcdir}/.build
export instdir=${srcdir}/.inst
export srcinstdir=${srcdir}/.sinst
export checkfile=${topdir}/${FULLPKG}.check
# run on
host=i686-pc-cygwin
# if this package creates binaries, they run on
target=i686-pc-cygwin
prefix=/usr
sysconfdir=/etc

mkdirs() {
  (cd ${topdir} && \
  rm -fr ${objdir} ${instdir} ${srcinstdir} && \
  mkdir -p ${objdir} && \
  mkdir -p ${instdir} && \
  mkdir -p ${srcinstdir} )
}
prep() {
  (cd ${topdir} && \
  test -d ${srcdir} && rm -fr ${srcdir} ; \
  test -d ${ORIG_PKG}-${VER} && rm -fr ${ORIG_PKG}-${VER} ; \
  unzip -a ${src_orig_pkg} && \
  mv ${ORIG_PKG}-${VER} ${topdir}/${PKG}-${VER} ; \
  cd ${topdir} && \
  if [ -f ${src_patch} ] ; then \
    patch -b -N -Z -p0 < ${src_patch} ;\
    # workaround cygwin patch -b bug 
    find ${srcdir} -name \*.orig | xargs chmod u+rw ;\
    for f in ${srcdir}/CYGWIN-PATCHES/*.orig; do rm -f $f; done; \
  fi && \
  && mkdirs )
}
conf() {
  (cd ${srcdir} && \
  perl Makefile.PL INSTALLDIRS=vendor PREFIX=${instdir}/usr/ | \
    tee ${srcinstdir}/config.log 2>&1 )
}
build() {
  (cd ${srcdir} && \
    make all manifypods INSTALLDIRS=vendor | \
    tee ${srcinstdir}/make.log 2>&1 )
}
# 
check() {
  (cd ${srcdir} && \
  make test | tee ${checkfile} 2>&1 )
}
clean() {
  (cd ${srcdir} && \
  find . -name \*.orig -exec rm \{\} \; && \
  if test -f Makefile; then \
    make realclean; \
  elif test -f Makefile.old; then \
    make -f Makefile.old realclean; \
  fi )
}
install() {
  rm -rf ${instdir}/*; \
  (cd ${srcdir} && \
  make pure_install INSTALLDIRS=vendor \
	INSTALLMAN1DIR=${instdir}/usr/share/man/man1 \
  	INSTALLMAN3DIR=${instdir}/usr/share/man/man3 && \
  find ${instdir} \( -name '.packlist' -o -name 'perllocal.pod' \) -exec rm -f {} \; && \
  find ${instdir}/usr/share/man -name '*.3pm' -type f -exec gzip -9 {} \; && \
  for d in ${prefix}/share/doc/${PKG}-${VER} ${prefix}/share/doc/Cygwin ; do \
    if [ ! -d ${instdir}${d} ] ; then \
      mkdir -p ${instdir}${d} ;\
    fi ;\
  done &&\
  doclist="`find . \( \
  	    -path '*/doc/*' \
  	-or -path '*/docs/*' \
  	-or -path '*/eg/*' \
  	-or -path '*/ex/*' \
  	-or -path '*/sample*/*' \
  	-or -iregex '.*/\(ANNOUNCE\|Changes\|INSTALL\|KNOWNBUG\|LICENSE\|README\|TODO\|COPYING\)' \
	-or -name '*.t' \
	-or \( -name '*.pl' -not -path '*/hints/*' \) \
        -or \( -name '*.bat' -not -iname 'install.bat' \) \
  \) -not -path '*/CVS/*' -not -path '*/.inst/*' -not -path '*/CYGWIN-PATCHES/*' | \
  sed -e 's|^./||'`" && \
  if [ ! "x$doclist" = "x" ]; then \
    for i in $doclist; do \
      d=`dirname $i` ;\
      d_dest=`echo $d | sed -e 's|/t/|/tests/|' -e 's|/t$|/tests|'`; \
      i_dest=`echo $i | sed -e 's|/t/|/tests/|' -e 's|/t$|/tests|' -e 's|\.t$|.pl|'`; \
      /usr/bin/install -d ${instdir}${prefix}/share/doc/${PKG}-${VER}/$d_dest ;\
      if [ -d $i ]; then \
        /usr/bin/install -d ${instdir}${prefix}/share/doc/${PKG}-${VER}/$i_dest ;\
      else \
        /usr/bin/install -m 644 $i ${instdir}${prefix}/share/doc/${PKG}-${VER}/$i_dest ;\
      fi; \
    done; \
  fi && \
  if [ -f ${srcdir}/CYGWIN-PATCHES/${PKG}.README ]; then \
    /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/${PKG}.README \
      ${instdir}${prefix}/share/doc/Cygwin/${PKG}-${VER}.README ; \
  else \
    if [ -f ${srcdir}/CYGWIN-PATCHES/README ]; then \
      /usr/bin/install -m 644 ${srcdir}/CYGWIN-PATCHES/README \
        ${instdir}${prefix}/share/doc/Cygwin/${PKG}-${VER}.README ; \
    fi ;\
  fi ;\
  if [ -f ${srcdir}/CYGWIN-PATCHES/postinstall.sh ] ; then \
  /usr/bin/install -m 755 ${srcdir}/CYGWIN-PATCHES/postinstall.sh \
      ${instdir}${sysconfdir}/postinstall/${PKG}.sh; \
  fi )
}
strip() {
  (cd ${instdir} && \
  find . -name "*.dll" | xargs strip > /dev/null 2>&1
  find . -name "*.exe" | xargs strip > /dev/null 2>&1
  true )
}
list() {
  (cd ${instdir} && \
  find . -name "*" ! -type d | sed 's/\.\/\(.*\)/\1/'
  true )
}
depend() {
  (cd ${instdir} && \
  find ${instdir} -name "*.exe" -o -name "*.dll" | xargs cygcheck | \
  sed -e '/\.exe/d' -e 's,\\,/,g' | sort -bu | xargs -n1 cygpath -u \
  | xargs cygcheck -f | sed 's%^%  %' | sort -bu ; \
  true )
}
requires() {
  cd ${instdir}
  requires=  
  for p in $(find ${instdir} -name "*.exe" -o -name "*.dll" | xargs cygcheck | \
    sed -e '/\.exe/d' -e 's,\\,/,g' | sort -bu | xargs -n1 cygpath -u \
    | xargs cygcheck -f | sort -bu | sed -e 's/\-[^\-]*\-[^\-]*$//'); do
    requires="$requires $p"
  done; \
  echo "requires: $requires"
}
pkg() {
  (cd ${instdir} && \
  tar cvjf ${bin_pkg} * && \
  if [ "${SIG}" -eq 1 ] ; then \
    name=${bin_pkg} text="PKG" sigfile ; \
  fi )
}
# poor mans setup
# missing: preremove, remove old, update permissions, check if in use.
setup() {
  (cd ${topdir} && \
  tar -C / -jxvf ${FULLPKG}.tar.bz2 && \
  post="/etc/postinstall/${PKG}.sh"; \
  test -f ${post} && ${post} && mv ${post} ${post}.done )
}
# 1. install into /usr, run rebaseall, cp back to .inst
# or 2. run rebase for all dll's except ours
rebase1() {
  (cd ${instdir}
  set -x 
  find usr -name \*.dll -exec /usr/bin/install -D -p -s -m755 \{\} /\{\} \;
  rebaseall -v
  set +x )
}
rebase2() {
  (cd ${instdir}
  echo "copy back..."
  set -x 
  find usr -name \*.dll -exec cp -f /\{\} \{\} \;
  set +x )
}
mkpatch() {
  clean && \
  (cd ${topdir} && \
  unzip -a ${src_orig_pkg} && \
  diff --strip-trailing-cr -baruN -x '.build' -x '.inst' -x '.sinst' -x 'CVS' \
    -x '*.sw?' -x '.cvsignore' -x '\*.orig' -I ' $Id: ' \
    ${ORIG_PKG}-${VER} ${PKG}-${VER} > \
    ${srcinstdir}/${src_patch_name} ; \
  rm -rf ${ORIG_PKG}-${VER} )
}
difforig() {
  (cd ${topdir} && \
  echo "difforig ${BASEPKG} > ${topdir}/${src_patch_name}" 1>&2
  find ${BASEPKG}/CYGWIN-PATCHES -type f ! -name '*~' ! -name '*.orig*' -print | sort | while read FILE
  do
    echo "$FILE" 1>&2
    [ -e $FILE.orig ] && chmod +r $FILE.orig
    diff -N -ub $FILE.orig $FILE # > ${topdir}/${src_patch_name}
  done
  find ${BASEPKG} \( -type d -path "${BASEPKG}/CYGWIN-PATCHES" \) -prune -o  -type f -name '*.orig' -print | sort | while read FILE
  do
    chmod +r $FILE
    NEW="`dirname $FILE`/`basename $FILE .orig`"
    echo "$NEW" 1>&2
    diff -ub $FILE $NEW # > ${topdir}/${src_patch_name}
  done )
}
mkpatchd() {
  $0 difforig > ${src_patch_name}
  true
}
spkg() {
  (mkpatch && \
  cp ${src_orig_pkg} ${srcinstdir}/${src_orig_pkg_name} && \
  cp $0 ${srcinstdir}/`basename $0` && \
  cd ${srcinstdir} && \
  if [ -e make.log ]; then \ 
    cp ${checkfile} . && \
    FILES="*.log *.check"; \
    tar cvjf ${FULLPKG}-log.tar.bz2 ${FILES} && rm ${FILES}; \
  fi; \
  cd ${srcinstdir} && \
  tar --exclude='CVS*' -cjf ${src_pkg} * )
}
up() {
  (cd ${topdir} && \
    rsync -avz setup.hint $src_pkg_name $bin_pkg_name  ${rsync_up_target}/${PKG}/ && \
    for f in get.sh README $src_pkg_name.sig $bin_pkg_name.sig; do 
      if [ -e $f ]; then rsync -avz $f ${rsync_up_target}/${PKG}/; fi
    done; true )
} 
finish() {
  rm -rf ${srcdir} 
}

while test -n "$1" ; do
  case $1 in
  prep)		prep ; STATUS=$? ;;
  mkdirs)	mkdirs; STATUS=$? ;;
  conf)		conf ; STATUS=$? ;;
  build)	build ; STATUS=$? ;;
  make)		build ; STATUS=$? ;;
  check)	check ; STATUS=$? ;;
  test)		check ; STATUS=$? ;;
  clean)	clean ; STATUS=$? ;;
  install)	install ; STATUS=$? ;;
  list)	list ; STATUS=$? ;;
    depend)		depend ; STATUS=$? ;;
    requires)		requires ; STATUS=$? ;;
  strip)	strip ; STATUS=$? ;;
  package)	pkg ; STATUS=$? ;;
  pkg)	pkg ; STATUS=$? ;;
  mkpatch)	mkpatch ; STATUS=$? ;;
  mkpatchd)	mkpatchd ; STATUS=$? ;;
  difforig)	difforig ; STATUS=$? ;;
  src-package)	spkg ; STATUS=$? ;;
  spkg)	spkg ; STATUS=$? ;;
    up)			up ; STATUS=$? ;;
    setup)		setup ; STATUS=$? ;;
    rebase1)		rebase1 ; STATUS=$? ;;
    rebase2)		rebase2 ; STATUS=$? ;;
  finish) finish ; STATUS=$? ;;
  all) prep && conf && build && install && \
       strip && pkg && spkg && finish ; \
	  STATUS=$? ;;
    *) echo "Error: bad argument $1" ; exit 1 ;;
  esac
  ( exit ${STATUS} ) || exit ${STATUS}
  shift
done

