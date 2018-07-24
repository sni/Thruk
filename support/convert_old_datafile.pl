#!/bin/bash

# read rc files if exist
[ -e ~/.profile ] && . ~/.profile
[ -e ~/.thruk   ] && . ~/.thruk

if [ -e $(dirname $0)/../lib/Thruk.pm ]; then
  export PERL5LIB="$PERL5LIB:$(dirname $0)/../lib";
  if [ "$OMD_ROOT" != "" -a "$THRUK_CONFIG" = "" ]; then export THRUK_CONFIG="$OMD_ROOT/etc/thruk"; fi
  if [ -z $THRUK_CONFIG ]; then export THRUK_CONFIG="$(dirname $0)/../"; fi
elif [ ! -z $OMD_ROOT ]; then
  export PERL5LIB=$OMD_ROOT/share/thruk/lib:$PERL5LIB
  if [ -z $THRUK_CONFIG ]; then export THRUK_CONFIG="$OMD_ROOT/etc/thruk"; fi
else
  export PERL5LIB=$PERL5LIB:/usr/share/thruk/lib:/usr/lib/thruk/perl5;
  if [ -z $THRUK_CONFIG ]; then export THRUK_CONFIG='/etc/thruk'; fi
fi

eval 'exec perl -x $0 ${1+"$@"} ;'
    if 0;

#! -*- perl -*-
# vim: expandtab:ts=4:sw=4:syntax=perl
#line 25

use warnings;
use strict;
use File::Slurp qw/read_file/;
use Thruk::Utils::IO;
use Thruk::Utils;

if(scalar @ARGV == 0) {
    print STDERR "usage: $0 <files...>\n";
    print STDERR "will convert old datafiles into new format.\n";
    exit 3;
}

for my $filename (@ARGV) {
    my $cont = read_file($filename);
    $cont = Thruk::Utils::IO::untaint($cont);

    # ensure right encoding
    Thruk::Utils::decode_any($cont);

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
    Thruk::Utils::IO::json_lock_store($filename, $VAR1, 1);
}
