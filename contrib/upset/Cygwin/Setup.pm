#!/usr/bin/perl -s
# forked from the cygwin.com module
# cgf: I'm not interested in turning it into a general purpose tool and I'm not
#      interested in bug reports, patches, augmentations, etc.
#      http://cygwin.com/ml/cygwin-apps/2004-10/msg00560.html

package Cygwin::Setup;

use FileHandle;
use strict;
use constant 'DEVEL' => 1;

BEGIN {
    # only Debian. only cgf may add. sync with http://cygwin.com/setup.html
    @Cygwin::Setup::categories = qw(
				    Admin 	Archive 	Base 	Comm 	Database
				    Devel 	Doc 	Editors 	Games 	Graphics
				    Interpreters 	Libs 	Mail 	Math 	Mingw
				    Net 	Perl	Publishing 	Science Shells 	Sound
				    System 	Text 	Utils 	Web 	X11);
    $Cygwin::Setup::stringkeys = qr!^(?:sdesc|ldesc)$!io;
    $Cygwin::Setup::validstates = qr!^(?:curr|test|prev|exp)!;
    @Cygwin::Setup::pkgkeys = DEVEL ? qw(requires Recommends Replaces Depends Pre-Depends Build-Depends
				         Conflicts Suggests Provides)
                                    : qw(requires);
    @Cygwin::Setup::otherkeys = DEVEL ? qw(Maintainer Architecture Source Binary Standards-Version
				           Priority Files Directory)
                                      : ();
    @Cygwin::Setup::replacekeys = qw( sdesc ldesc category requires skip verpat external-source );
    # always recalculate, FIXME: warn if md5 and date changed but version is the same.
    @Cygwin::Setup::skipkeys = qw( version install source );
    if (DEVEL) {
	push(@Cygwin::Setup::replacekeys, (@Cygwin::Setup::skipkeys));
	@Cygwin::Setup::skipkeys = ();
    }
    push(@Cygwin::Setup::replacekeys, (@Cygwin::Setup::pkgkeys, @Cygwin::Setup::otherkeys));
    $Cygwin::Setup::replacekeys = qr!^(?:@{[join('|' => @Cygwin::Setup::replacekeys)]})$!io;
    $Cygwin::Setup::skipkeys = qr!^(?:@{[join('|' => @Cygwin::Setup::skipkeys)]})$!io;
    $Cygwin::Setup::validinikeys = qr!^(?:setup-timestamp|setup-version)$!io;
}

sub new {
    my $self;
    bless $self = {}, shift;
    $self->{-static} = {-package=>'__setup', -state=>''};
    $self->{-static}{-hint} = '';
    return $self;
}

sub nextline($) {
    my $what = shift;
    return $_ = shift @{$what} if ref($what) eq 'ARRAY';
    return $_ = <$what>;
}

sub states(\%$$\$;\$) {
    my $self = shift;
    my $filename = shift;
    my $pkg = shift;
    my $state = shift;
    my $val = shift;
    if (${$state} !~ $Cygwin::Setup::validstates) {
	$val or $self->{-error} = "$filename($.): unknown state \"[${$state}]\"";
	return undef;
    }
    ${$state} = '' if ${$state} eq 'curr';
    if ($val) {
	${$val} = '0' if ${$val} eq '-';
	my $pat;
	if (defined($self->{$pkg}{''}{'verpat'})) {
	    $pat = $self->{$pkg}{''}{'verpat'};
	} else {
	    $pat = '(' . $self->{_me} . '-)(.*)(\.tar\.[bg]z2?)';
	}
	my ($norver, $ver) = (Cygwin::Setup::Version::Normalize((${$val} =~ /^[a-z]/ ? '' : 'dummy-') . ${$val}, $pat))[1,2];
	push(@{$self->{$pkg}{'override'}}, {'n'=>${$state}, 'ver'=>$ver, 'norver'=>$norver});
    }
    return 1;
}

sub quoteit {
    my $fh = shift;
    my $text = shift;
    if ($text =~ /^"[^"]*$/) {
	$text .= "\n";
	do {
	    last unless length nextline($fh);
	    chomp $_;
	    s/(\S)\s+$/$1/g;
	    $text .= $_ . "\n";
	} while (!/"$/);
	chomp $text;
    };
    return $text;
}

sub quotesplit {
    my $text = shift;
    my ($a, $b);
    if ($text =~ /^"/) {
	return ($text =~ /"([^"]+)"\s+(.*)/);
    } else {
	return split(' ', $text, 2);
    }
}

# iniparse(filename, fileglob)

sub iniparse($$$) {
    my $self = shift;
    my $f = shift;
    my $fh = shift;
    my $hint = shift || '';
    my @empty;
    while (defined(nextline($fh))) {
	chomp;
	my $pre = '';
	my $quote_closed = 1;
	while (/^([^"]*")(.*)$/) {
	    $pre .= $1;
	    $_ = $2;
	    $quote_closed ^= 1;
	}

	s/#.*$//g if $quote_closed;
	s/(\S)\s+$/$1/g;
	s/^\s+//;
	$_ = $pre . $_;
	last if length($_);
    }
    if (!defined($_) || !length($_)) {
	$self->{-static} = {-package=>'__setup', -state=>''};
	$self->{-static}{-hint} = '';
	$self->{-static}{-state} = '';
	return @empty;
    }
    my $here;
    my $key = '';
    my $text = '';
    my ($pkg, $what);
    if ($hint && $self->{-static}{-hint} ne $hint) {
	$pkg = $self->{-static}{-package} = $hint;
	$what = $self->{-static}{-state} = '';
	$self->{-static}{-hint} = $hint;
    } else {
	$pkg = $self->{-static}{-package};
	$what = $self->{-static}{-state};
    }
    if (/^\s*@\s+(.*)/) {
	$text = $1;
	$self->{$pkg}{_me} = $text if $hint;
	$self->{$text} = {} unless $self->{$text};
	$self->{$text}{'_me'} = $text;
	$here = \$self->{-static}{-package};
	$self->{-static}{-state} = '';
    } elsif (/^\s*\[([^\]]+)\]\s*$/) {
	$text = lc $1;
	$hint and do {
	    $self->{-error} = "$f($.): can't use [] here";
	    return undef;
	};
	$self->states($f, $pkg, \$text) or return undef;
	
	$text = '' if $text eq 'curr';
	$text = '0' if $text eq '-';
	$here = \$self->{-static}{-state};
    } elsif (/^([^:\s]+):?(?:\s+(.*))?/) {
	$key = $1;
	$text = defined ($2) ? $2 : '';
	$key =~ $Cygwin::Setup::skipkeys and return 1;
	return 1 if $hint && $self->states($f, $pkg, \$key, \$text);
	if ($key =~ $Cygwin::Setup::replacekeys ||
	    ($pkg eq '__setup' && $key =~ $Cygwin::Setup::validinikeys)) {
	    $here = \$self->{$pkg}{$what}{$key};
	    $self->{$pkg}{$what}{"old-$key"} = ${$here} if defined($here);
        } elsif ($key eq 'autodep') {
	    if (!defined($text)) {
		$self->{-error} = "$f:$.: bad autodef line '$_'";
		return undef;
	    }
	    $self->{-autodep}{$self->{$pkg}{_me}} = []
		unless defined($self->{-autodep}{$self->{$pkg}{_me}});
	    $here = $self->{-autodep}{$self->{$pkg}{_me}};
        } elsif ($key eq 'noautodep') {
	    if (!defined($text)) {
		$self->{-error} = "$f($.): bad autodef line '$_'";
		return undef;
	    }
	    $self->{$pkg}{$what}{$key} = []
		unless defined($self->{$pkg}{$what}{$key});
	    
	    $here = $self->{$pkg}{$what}{$key};
        } elsif ($key eq 'incver_ifdep') {
	    if ($text !~ /^[01yn]/oi) {
		$self->{-error} = "$f($.): bad incver_ifdep line '$_'";
		return undef;
	    }
	    $text = $text =~ /[1y]/oi ? 1 : 0;
	    $here = \$self->{$pkg}{-incver};
	} else {
	    $self->{-error} = "$f:$.: unknown key '$_'";
	    return undef;
	}
    } else {
	warn "$f: unknown setup construct '$_' at $.\n";
	return undef
    };
    $text = quoteit($fh, $text);
    if (!defined($text)) {
	$text = '';
    } elsif ($key =~ $Cygwin::Setup::stringkeys) {
	$text = "\"$text\"" if $text =~ /\s/o && $text !~ /^"/o;
	$text =~ s/(.)"(.)/$1'$2/mg;
    }
    if (ref $here eq 'ARRAY') {
	push(@{$here}, $text);
    } else {
	${$here} = $text;
    }
    return 1;
}

# exe_version(filename)

sub exe_version($) {
    my $self = shift;
    my $fh = new FileHandle "< $_[0]";
    return undef unless $fh;
    while (<$fh>) {
	if (/%%% setup-version ([^\s\0]+)/) {
	    $self->{'__setup'}{''}{'setup-version'} = $1;
	    last;
	}
    }
    $fh->close;
    return 1;
}

# force packages which begin with '!' to be lexically first
# and packages which begin with '_" to be lexically last
sub lex {
    my $x = shift;
    my $c = substr($x, 0, 1);
    if ($c eq '!') {
	substr($x, 0, 1) = chr(0);
    } elsif ($c eq '_') {
	substr($x, 0, 1) = chr(255)
    }
    return $x;
}

sub names() {
    my $self = shift;
    my @keys = ();
    foreach my $k (sort {lex($a) cmp lex($b)} keys %{$self}) {
	push(@keys, $k) unless substr($k, 0, 1) eq '-';
    }
    return @keys;
}
    
1;

# Local Variables:
# cperl-indent-level: 4
# End:
