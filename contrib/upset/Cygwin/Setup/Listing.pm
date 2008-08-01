package Cygwin::Setup;

use strict;
use Archive::Tar;

BEGIN {
    $Cygwin::Setup::Listing::stem = 'packages';
    $Cygwin::Setup::Listing::dir = "/www/sourceware/htdocs/cygwin/$Cygwin::Setup::Listing::stem";
    %Cygwin::Setup::Listing::uncs = ('b'=>'I', 'g'=>'z');
}

sub listout($$);

sub update_autodep($$) {
    my $self = shift;
    my $p = shift;
    my $files = shift;
    my $pkg = $self->{$p}{''};
    for my $k (keys %{$self->{-autodep}}) {
	next if grep($k eq $_, @{$pkg->{'noautodep'}});
	for my $pat (@{$self->{-autodep}{$k}}) {
	    if (grep($_->{'name'} =~ /^$pat$/, @{$files})) {
		$self->addrequires ($p, $k);
		$self->incver($k) if $self->{$k}{-incver};
	    }
	}
    }
}

sub update_autodep_from_old {
    my $self = shift;
    my $k = shift;
    my ($p, $f) = ($k =~ m!^(.*)/(.*)$!);
    my $pkg = $self->{$p}{''};
    my @old_requires = (split(' ', $pkg->{'old-requires'})) or return;
    for my $k (keys %{$self->{-autodep}}) {
        next if grep($k eq $_, @{$pkg->{'noautodep'}});
	if (grep($_ eq $k, @old_requires)) {
	    $self->addrequires ($p, $k);
	}
    }
}

sub update_listing() {
    my $self = shift;
    my $listing = $self->{-listing};
    my $wild = "$Cygwin::Setup::Listing::dir/*/*";
    foreach (glob($wild)) {
	next if -d $_;
	my ($p, $f) = (m!^$Cygwin::Setup::Listing::dir/([^/]+)/(.*)$!o);
	my $key = "$p/$f";
	if (!defined($listing->{$key})) {
	    unlink $_;
	} else {
	    delete $listing->{$key};
	    $self->update_autodep_from_old($key);
	}
    }

    if (keys %{$listing}) {
	open(INDEX, ">$Cygwin::Setup::Listing::dir/index.html") or do {
	    $self->{-error} = "couldn't open $Cygwin::Setup::Listing::dir/index.html - $!";
	    return undef;
	};
	print INDEX <<EOF;
<html>
<head>
<title>Cygwin Package List</title>
</head>
<!--#include virtual="cygwin-header.html" -->
<center><h1>Cygwin Package List</h1></center>
<form method="GET" action="http://cygwin.com/cgi-bin2/package-grep.cgi">
<center>Search Package List: <INPUT type="text" size=40 name="grep"> <INPUT type=submit value="Go"></center><br>
</form>
<table>
EOF
	foreach my $p ($self->names) {
	    next if $self->{$p}{''}{'skip'};
	    if (!-f "$Cygwin::Setup::Listing::dir/$p/.htaccess") {
		mkdir "$Cygwin::Setup::Listing::dir/$p", 0777;
		open(PACKAGE_HTACCESS, ">$Cygwin::Setup::Listing::dir/$p/.htaccess");
		print PACKAGE_HTACCESS <<'EOF';
Options Indexes
IndexOptions -FancyIndexing
EOF
		close PACKAGE_HTACCESS;
	    }
	    my $header = $self->{$p}{''}{'sdesc'} or next;
	    $header =~ s/"//g;
	    print INDEX '<tr><td><img src="http://sources.redhat.com/icons/ball.gray.gif" height=10 width=10 alt=""></a></td><td cellspacing=10><a href="' . $p . '">' . $p . '</a></td><td align="left">' . $header . "</td></tr>\n";
	 }
	print INDEX <<EOF;
</table>
<!--#include virtual="cygwin-footer.html" -->
</body>
</html>
EOF
	close INDEX;

	# Output all of the listing files
	foreach my $k (sort keys(%{$listing})) {
	    my ($p, $f) = ($k =~ m!^(.*)/(.*)$!);
	    $self->listout($p, $listing->{$k});
	}
    }
    system "exec rmdir $Cygwin::Setup::Listing::dir/* 2>/dev/null";
}

sub addrequires($$) {
    my $self = shift;
    my $p = shift;
    my $category = shift;
    my $curr = $self->{$p}{''};
    return if $curr->{'requires'} =~ /\b$category\b/;
    $curr->{'requires'} .= ' ' if length($curr->{'requires'});
    $curr->{'requires'} .= $category;
}

sub incver {
    my $self = shift;
    my $p = shift;

    $self->{$p}{-incver} = 0;

    my $oldinst = $self->{$p}{''}{'install'};
    $self->{$p}{''}{'install'} =~ s/-(0\d{3,})-/sprintf "-%0*d-", length($1), $1 + 1/e;
    my $newinst = $self->{$p}{''}{'install'};
    $oldinst =~ s/\s+.*$//o;
    $newinst =~ s/\s+.*$//o;
    rename($oldinst, $newinst) or
	warn "couldn't bump version for $oldinst - $!";

    my $oldsource = $self->{$p}{''}{'source'} or return;
    $self->{$p}{''}{'source'} =~ s/-(0\d{3,})-/sprintf "-%0*d-", length($1), $1 + 1/e;
    my $newsource = $self->{$p}{''}{'source'};
    $oldsource =~ s/\s+.*$//o;
    $newsource =~ s/\s+.*$//o;
    rename($oldsource, $newsource) or
	warn "couldn't bump version for $oldsource - $!";
}

sub listout($$) {
    my $self = shift;
    my $p = shift;
    my $fn = shift;
    my $pkg = $self->{$p};

    my ($d, $f);
    $fn =~ m!^(.*)/([^/]*)$!;
    if (!length($1)) {
	$d = '';
	$f = $fn;
    } else {
	$d = $1;
	$f = $2;
    }
    $f =~ s/.tar\.([gb])z2?$//;
    my $unc = $Cygwin::Setup::Listing::uncs{$1} or do {
	warn "unknown filename '$fn'\n";
	return;
    };
    mkdir "$Cygwin::Setup::Listing::dir/$p", 0777;
    my $pid;
    open(LST, ">$Cygwin::Setup::Listing::dir/$p/$f");
    # open(STDERR, ">/dev/null");
    my $header = $pkg->{''}{'sdesc'};
    if (!$header) {
	$header = $p;
    } else {
	$header =~ s/"//g;
	$header = "$p: $header";
    };
    if ($f =~ /-src/) {
	$header .= " (source code)";
    } else {
	$header .= " (installed binaries and support files)";
    }
    print LST <<EOF;
<body bgcolor="white" text="black" link="#0000EE" VLINK="#551A8B" ALINK="red">
<html>
<title>$header</title>
<blockquote><blockquote><h3>$header</h3></blockquote>
<tt><pre>
EOF
    my $tar = new Archive::Tar;
    my @files = $tar->list_archive($fn, ['name', 'mtime', 'linkname', 'size']);
    for my $file (@files) {
	printf LST "    %-27s%12d %s", scalar(gmtime($file->{'mtime'})), $file->{'size'}, $file->{'name'};
	print LST " -> ", $file->{'linkname'} if $file->{'linkname'};
	print LST "\n";
    }
    $self->update_autodep($p, \@files) unless $fn =~ /-src\.tar/;
    
    print LST <<EOF;
</pre></tt></blockquote>
</body>
</html>
EOF
    close LST;
}

1;
