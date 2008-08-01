#!/usr/bin/perl -s
BEGIN {
    $main::replacekeys = qr!^(?:sdesc|ldesc|category|requires|skip)$!;
    $main::stringkeys = qr!^(?:sdesc|ldesc)$!;
    my $fn = readlink $0;
    $fn and $0 = $fn;
}

package Cygwin::Setup;
use DirHandle;
use FileHandle;
use File::Basename;
use Cygwin::Setup::Version;
use Digest::MD5;
use strict;

sub versort {
    local $_;
    my @norfiles = ();
    my %keyed = ();
    foreach my $f (@_) {
	my $nor = join ('/', (Cygwin::Setup::Version::Normalize($f))[1,0]);
	push(@norfiles, $nor);
	$keyed{$nor} = $f;
    }
    my @ret;
    foreach my $nor (reverse Cygwin::Setup::Version::Sort(\@norfiles)) {
	push(@ret, $keyed{$nor});
    }
    return @ret;
}

sub md5 {
    my $self = shift;
    my $f = shift;
    my $md5 = $self->{-md5}{$f};
    if (!defined($md5)) {
	open(F, "$f") or return '';
	my $ctx = Digest::MD5->new;
	$ctx->addfile(\*F);
	close F;
	$md5 = $ctx->hexdigest;
    }
    return ' ' . $md5;
}

sub allfiles {
    my $self = shift;
    my @files = ();
    my %pkgdir = ();
    my @dirs = sort @_;
    while (my $d = shift @dirs) {
	my @dirlater = ();
	my $dh = new DirHandle $d or do {
	    $self->{-error} = "error opening directory $d - $!";
	    return undef;
	};
	my ($stem, $dir) = fileparse($d);
	for my $f (sort readdir $dh) {
	    next if $f =~ /^\./o;
	    $f = "$d/$f";
	    if (-d $f) {
		push(@dirlater, $f);
	    } elsif ($f =~ m!/setup.hint$!o) {
		$pkgdir{$stem}{'hint'} = $f;
	    } elsif ($f =~ /\.tar\.(bz2|gz)/o) {
		push(@{$pkgdir{$stem}{'tars'}}, $f)
		  unless $f =~ /-log\.tar\.(bz2|gz)/o;
	    } elsif ($f eq "$d/md5.sum") {
		open(MD5, "$f") or next;
		while (<MD5>) {
		    my ($md5, $fn) = (/(\S+)\s+(\S+\.[gb]z2?)$/o) or next;
		    $self->{-md5}{"$d/$fn"} = $md5;
		}
		close MD5;
	    }
	}
	$dh->close;
	unshift(@dirs, @dirlater);
    }
    for my $k (sort keys %pkgdir) {
	push(@files, $pkgdir{$k}{'hint'}) if $pkgdir{$k}{'hint'};
	push(@files, versort(@{$pkgdir{$k}{'tars'}}));
    }
    return @files;
}

sub hint($$) {
    my $self = shift;
    my $pkg = shift;
    my $filename = shift;
    my $fh = new FileHandle "<$filename" or do {
        warn "update-setup: couldn't open $filename - $!\n";
        return;
    };
    $. = 0;
    1 while $self->iniparse($filename, $fh, $pkg);
    $fh->close;
    return $self->{-error} ? undef : 1;
}

sub package_from_file {
    my $f = shift;
    return ($f =~ /^([a-z].*?)-\d/io)[0];
}

sub dir_update(\%@) {
    my $self = shift;
    $self->{-listing} = {} unless $self->{-listing};
    my $listing = $self->{-listing};

    foreach my $f ($self->allfiles(@_)) {
	my ($p, $file) = $f =~ m!/?([^/]+)/([^/]+)$!;
	$p = package_from_file ($file) if $p eq '.';
	$self->{$p} = {} unless defined $self->{$p};
	my $pkgbase = $self->{$p};
	if (!defined($pkgbase->{_me})) {
	    $pkgbase->{'_me'} = $p;
	} elsif ($pkgbase->{_me} ne $p) {
	    $p = $pkgbase->{_me};
	    $pkgbase = $self->{$p};
	}
	if ($file eq 'setup.hint') {
	    return undef unless $self->hint($p, $f);
	    next;
	}
	next if defined ($pkgbase->{''}{'skip'});
	my ($filever_normal, $filever) = (Cygwin::Setup::Version::Normalize($f, $pkgbase->{_me}))[1, 2];
	my ($n, $ver);
	my $fnoext = $file;
	$fnoext =~ s/\.tar.[bg]z2?.*$//;
	$listing->{"$p/$fnoext"} = $f;
	for my $s (@{$pkgbase->{'override'}}) {
	    if ($s->{'norver'} eq $filever_normal) {
		$n = $s->{'n'};
		$ver = $s->{'ver'};
		last;
	    }
	}
	if (!defined($n)) {
	    next if @{$pkgbase->{'override'}};
	    for my $m ('', 'prev') {
		if (!defined($pkgbase->{$m}{'version'}) ||
		    $pkgbase->{$m}{'version'} eq $filever) {
		    $n = $m;
		    $ver = $filever;
		    last;
		}
	    }
	}
	my $key;
	my $line = $f . ' ' . int(-s $f) . $self->md5($f);
	# TODO: check if md5 changed and warn if same version
	if ($f !~ /-src\.tar/o) {
	    $key = 'install';
	} else {
	    my $base = basename($f);
	    if (defined($self->{'-sources'}{$base})) {
		# self->{-error} = "duplicate source file names for $base - $f vs. ", $self->{$base};
	    } else {
		$self->{'-sources'}{$base} = $line;
	    }
	    $key = 'source';
	}
	next unless defined($n);
	#$pkgbase->{$n}{'old-version'} = $ver;
	#$pkgbase->{$n}{"old-$key"} = $line;
	$pkgbase->{$n}{'version'} = $ver;
	$pkgbase->{$n}{$key} = $line;
    }
}

1;
