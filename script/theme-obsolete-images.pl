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
use Getopt::Long;
use Pod::Usage;

use Thruk::Config;
use Thruk::Utils::Log qw/:all/;

my $options = {
    'verbose'  => 0,
};
Getopt::Long::Configure('no_ignore_case');
Getopt::Long::Configure('bundling');
Getopt::Long::GetOptions(
   "h|help"     => \$options->{'help'},
   "v|verbose"  => sub { $options->{'verbose'}++ },
) or do {
    print "usage: $0 [<options>]\n";
    Pod::Usage::pod2usage( { -verbose => 2, -exit => 3 } );
    exit 3;
};
if($options->{'help'}) {
    print "usage: $0 [<options>]\n";
    Pod::Usage::pod2usage( { -verbose => 2, -exit => 3 } );
}

my @folders = ("./root/thruk/images", glob("./themes/themes-available/*/images"), glob("./plugins/plugins-available/*/root/images/"));
my @files;
for my $f (@folders) {
    push @files, @{Thruk::Utils::IO::find_files($f, '\.\w+$')};
}

$ENV{'THRUK_VERBOSE'} = $options->{'verbose'};
Thruk::Config::set_config_env();

my $images = {};
for my $file (@files) {
    my $img = $file;
    $img =~ s/^.*\///gmx;
    next if $img eq '.gitignore';
    $images->{$img} = $file;
}

for my $img (sort values %{$images}) {
    my $file = $img;
    $img =~ s/^.*\///gmx;
    next if $img eq 'logo.svg';     # should not be removed
    next if $img eq 'dropdown.png'; # should not be removed
    next if $img =~ /^criticity_\d+/mx; # used for shinken
    my $res = `grep -r "$img" templates/ root/thruk/javascript/ plugins/plugins-available/ lib/ 2>/dev/null`;
    if(!$res) {
        _warn("image: %40s is not used anywhere and could be removed. path: %s", $img, $file);
    }
}
