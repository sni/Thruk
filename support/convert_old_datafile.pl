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

use warnings;
use strict;

use Thruk::Config;
use Thruk::Utils ();
use Thruk::Utils::IO ();

if(scalar @ARGV == 0) {
    print STDERR "usage: $0 <files...>\n";
    print STDERR "will convert old datafiles into new format.\n";
    exit 3;
}

for my $filename (@ARGV) {
    my $cont = Thruk::Utils::IO::read($filename);
    $cont = Thruk::Utils::IO::untaint($cont);

    # ensure right encoding
    Thruk::Utils::Encode::decode_any($cont);

    $cont =~ s/^\$VAR1\ =\ //mx;

    # replace broken escape sequences
    $cont =~ s/\\x\{[\w]{5,}\}/\x{fffd}/gmxi;

    # replace broken JSON::PP::Boolean
    $cont =~ s/JSON::PP::/JSON::XS::/gmx;

    # thruk uses Cpanel now
    $cont =~ s/(Cpanel::|)JSON::XS::/Cpanel::JSON::XS::/gmx;
    $cont =~ s/bless\(\ do\{\\\(my\ \$o\ =\ (\d+)\)\},\ 'Cpanel::JSON::XS::Boolean\'\ \)/$1/gmx;

    my $VAR1;
    ## no critic
    eval("#line 1 $filename\n".'$VAR1 = '.$cont.';');
    ## use critic

    if($@) {
        die("failed to read $filename: $@");
    }

    # save file to original destination
    Thruk::Utils::IO::json_lock_store($filename, $VAR1, { pretty => 1 });
}
