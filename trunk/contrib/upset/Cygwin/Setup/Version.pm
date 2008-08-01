package Cygwin::Setup::Version;
require 5.000;
require Exporter;

$VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw();
@EXPORT = ();

sub Normalize {
    my $fn = shift;
    my $prematch = shift;
    my ($i, @v);
    my ($pre, $post);
    local($_) = $fn;
    $pre = $post = '';
    s!^(.*/)([^/]*)$!$2!o and $pre = $1;
    my $rawver;
    $prematch = ($pre =~ m%/([^/]+)/$%)[0] unless defined($prematch);
    
    if (($prematch && s/^(\Q$prematch\E-)//) || s/^((?:[a-z_][a-z\d._]*[^a-z\d._]?)+)//oi) {
	$pre .= $1;
    }
    $post .= $1 while s/([-\._](bz2|gz)|[-\._]bin|[-\._]tar|[-\._]tgz|[-\._]Z|[-\._]?elf|[-\._]lnx|[-\._][a-z]*doc[a-z]*|[-\._]linux|[-\._]hacker|[-\._]tool|[-\._]src)|^src\b//;
    $_ = '0' unless length($_);
    $rawver = $_;
    push(@v, split(/[-._]/));
    if (/-(\d+)$/o) {
	$v[$#v] = ":$v[$#v]";
    }
    for ($i = 0; $i < @v; $i++) {
	$v[$i] =~ s/^pl?// if $i < $#v;
	$v[$i] =~ /^(\d*)(.*)/o;
	if ($2 eq '') {
	    my $num = $1;
	    $num = 19 . $num if $num =~ /^99/;	# y2k kludge
	    $v[$i] = sprintf("%04d", $num);
	} elsif ($1 eq '') {
	    my $a = $2;
	    $a =~ /(\D+)(\d*)/;
	    splice(@v, $i++, 1, '0000', lc sprintf("%04.4s", $1));
	    splice(@v, $i + 1, 0, $2) if length($2);
	} else {
	    splice(@v, $i--, 1, $1, $2);
	}
    }

    return $fn unless length($_);

    $post =~ s/\.tgz/.tar.gz/;
    $post =~ s/\.bz2/.gz/;
    ($_ = join('', @v)) =~ s/ /0/g;
    return wantarray ? (($pre . $post), $_, $rawver) : $_;
}

sub sortkey {
    return ($a . (($maxlen - length($a)) x '0'))
			cmp
	   ($b . (($maxlen - length($b)) x '0'));
}

sub Sort {
    local *arr = shift;
    local $_;
    my $len;
    local $maxlen = 0;
    foreach (@arr) {
	my $len = length $_;
	$maxlen = $len if $len > $maxlen;
    }

    return sort sortkey @arr;
} 
1;
