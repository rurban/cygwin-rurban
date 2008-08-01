SRCDIR=perl-current
.PHONY: all build check patch-apply patch patch-check

all : patches

build:
	./build.sh

patch : $(wildcard pl-*.patch)

patch-apply :
	for p in pl-*.patch; do
	  (cd $(SRCDIR); patch -p1 -b <../$p ; cd -)
	done

patch-check : # check if all .orig files are handled in patches
	for s in `find $(SRCDIR) -name \*.orig`; do \
		x=`echo $$s|sed s,.orig,,`; grep $$x Makefile; \
	done

pl-43268-cyg-syslog-ng.patch : $(SRCDIR)/ext/Sys/Syslog/t/syslog.t
	-difforig $^ > /tmp.$$
	test -s /tmp.$$ && mv /tmp.$$ $@
	rm /tmp.$$

#pl-CYG02lib-ExtUtils-Embed.patch : $(SRCDIR)/lib/ExtUtils/Embed.pm
#	-difforig $^ > /tmp.$$
#	test -s /tmp.$$ && mv /tmp.$$ $@
#	rm /tmp.$$

pl-CYG03lib-Test-Harness-Straps.patch : $(SRCDIR)/lib/Test/Harness/Straps.pm
	-difforig $^ > /tmp.$$
	test -s /tmp.$$ && mv /tmp.$$ $@
	rm /tmp.$$

pl-CYG04major.version.cygwin.sh.patch : $(SRCDIR)/installperl
	-difforig $^ > /tmp.$$
	test -s /tmp.$$ && mv /tmp.$$ $@
	rm /tmp.$$

#pl-CYG06-cygwin-path6.patch : $(SRCDIR)/cygwin/cygwin.c $(SRCDIR)/README.cygwin $(SRCDIR)/t/lib/cygwin.t
#	-difforig $^ > /tmp.$$
#	test -s /tmp.$$ && mv /tmp.$$ $@
#	rm /tmp.$$

#pl-CYG07-File-Spec-casetol.patch : $(SRCDIR)/lib/File/Spec/Cygwin.pm $(SRCDIR)/lib/File/Spec/Win32.pm
#	-difforig $^ > /tmp.$$
#	test -s /tmp.$$ && mv /tmp.$$ $@
#	rm /tmp.$$

#pl-CYG08-no-perlld.patch : $(SRCDIR)/cflags.SH $(SRCDIR)/cygwin/Makefile.SHs $(SRCDIR)/cygwin/ld2.in $(SRCDIR)/cygwin/perlld.in $(SRCDIR)/hints/cygwin.sh
#	-difforig $^ > /tmp.$$
#	test -s /tmp.$$ && mv /tmp.$$ $@
#	rm /tmp.$$

#pl-CYG11-no-bs.patch : perl-current/lib/ExtUtils/Command.pm perl-current/lib/ExtUtils/MM_Any.pm perl-current/lib/ExtUtils/MM_Unix.pm
#	-difforig perl-current/lib/ExtUtils > /tmp.$$
#	test -s /tmp.$$ && mv /tmp.$$ $@
#	rm /tmp.$$

pl-t-taint-2.patch : perl-current/t/op/taint.t
	-difforig $^ > /tmp.$$
	test -s /tmp.$$ && mv /tmp.$$ $@
	rm /tmp.$$

pl-patch_win32api_file.patch : $(SRCDIR)/ext/Win32API/File/File.pm
	-difforig $^ > /tmp.$$
	test -s /tmp.$$ && mv /tmp.$$ $@
	rm /tmp.$$

pl-patchlevel-h.patch : $(SRCDIR)/patchlevel.h
	-difforig $^ > /tmp.$$
	test -s /tmp.$$ && mv /tmp.$$ $@
	rm /tmp.$$

pl-pod-html-enc1.patch : $(SRCDIR)/MANIFEST $(SRCDIR)/lib/Pod/Html.pm 
	-difforig $^ $(SRCDIR)/lib/Pod/t/htmlenc.pod $(SRCDIR)/lib/Pod/t/htmlenc.t > /tmp.$$
	test -s /tmp.$$ && mv /tmp.$$ $@
	rm /tmp.$$

