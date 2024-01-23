#!/usr/bin/env bash

# read rc files if exist
unset PROFILEDOTD
[ -e /etc/thruk/thruk.env  ] && . /etc/thruk/thruk.env
[ -e ~/etc/thruk/thruk.env ] && . ~/etc/thruk/thruk.env
[ -e ~/.thruk              ] && . ~/.thruk
[ -e ~/.profile            ] && . ~/.profile

BASEDIR=$(dirname $0)/..

# git version
if [ -d $BASEDIR/.git -a -e $BASEDIR/lib/Thruk.pm ]; then
  export PERL5LIB="$BASEDIR/lib:$PERL5LIB";
  if [ "$OMD_ROOT" != "" -a "$THRUK_CONFIG" = "" ]; then export THRUK_CONFIG="$OMD_ROOT/etc/thruk"; fi
  if [ "$THRUK_CONFIG" = "" ]; then export THRUK_CONFIG="$BASEDIR/"; fi

# omd
elif [ "$OMD_ROOT" != "" ]; then
  export PERL5LIB=$OMD_ROOT/share/thruk/lib:$PERL5LIB
  if [ "$THRUK_CONFIG" = "" ]; then export THRUK_CONFIG="$OMD_ROOT/etc/thruk"; fi

# pkg installation
else
  export PERL5LIB=$PERL5LIB:@DATADIR@/lib:@THRUKLIBS@;
  if [ "$THRUK_CONFIG" = "" ]; then export THRUK_CONFIG='@SYSCONFDIR@'; fi
fi

eval 'exec perl -x $0 ${1+"$@"} ;'
    if 0;

#! -*- perl -*-
# vim: expandtab:ts=4:sw=4:syntax=perl
#line 35

###################################################
use warnings;
use strict;

use lib 'lib';
use File::Copy qw/move/;
use Getopt::Long;
use Pod::Usage;

use Thruk::Config;
use Thruk::Utils::Log qw/:all/;

my @remove = qw/dataVar dataVal
                filterValue dataUserVar
                optBoxValue
               /;

my @folders;
my $options = {
    'verbose'  => 0,
    'dry'      => 0,
};
Getopt::Long::Configure('no_ignore_case');
Getopt::Long::Configure('bundling');
Getopt::Long::GetOptions(
   "h|help"     => \$options->{'help'},
   "v|verbose"  => sub { $options->{'verbose'}++ },
   "n|dry-run"  => \$options->{'dry'},
   "<>"         => sub { push @folders, shift; },
) or do {
    print "usage: $0 [<options>]\n";
    Pod::Usage::pod2usage( { -verbose => 2, -exit => 3 } );
    exit 3;
};
if($options->{'help'}) {
    print "usage: $0 [<options>]\n";
    Pod::Usage::pod2usage( { -verbose => 2, -exit => 3 } );
}

if(scalar @folders == 0) {
    @folders = ("./templates", glob("./plugins/plugins-available/*/templates"));
}
my @files;
for my $f (@folders) {
    push @files, @{Thruk::Utils::IO::find_files($f, '\.tt$')};
}
@files = grep(!/\.git\//, @files);

$ENV{'THRUK_VERBOSE'} = $options->{'verbose'};
Thruk::Config::set_config_env();

for my $file (@files) {
    my $orig = Thruk::Utils::IO::read($file);
    my $content = $orig;

    # remove know legacy classes
    $content =~ s/(class=")([^"]+)(")/&_remove_legacy_classes($1, $2, $3)/gemx;
    $content =~ s/(class=')([^']+)(')/&_remove_legacy_classes($1, $2, $3)/gemx;

    # remove empty class attributes
    $content =~ s/\s*class=''\s*/ /gmx;
    $content =~ s/\s*class=""\s*/ /gmx;

    # remove whitespace
    $content =~ s/<(\w+)\s+>/<$1>/gmx;

    next if $content eq $orig;
    if(!$options->{'dry'}) {
        _info("cleaned %s", $file);
        Thruk::Utils::IO::write($file, $content);
    }
}

_info("checked %d templates", scalar @files);

###############################################################################
sub _remove_legacy_classes {
    my($pre, $str, $post) = @_;

    my @classes = split/\s+/, $str;

    my $remove = join('|', @remove);
    @classes = grep(!/^($remove)$/, @classes);

    return($pre.join(" ", @classes).$post);
}