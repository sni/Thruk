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

my $target = './templates/theme_preview.tt';

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

my $icons = {};
for my $file (@files) {
    next if $file =~ m/theme_preview/mx;
    my $content = Thruk::Utils::IO::read($file);
    my @matches = $content =~ m/<i\s+[^<]*class=['"]+.*?(?:uil|fa-solid)\s.*?['"]+[^>]*>/gmxi;
    next if scalar @matches == 0;
    for my $m (@matches) {
        $m =~ s/\[%[^%]*?%\]/ /gmx;
        my @classes = split(/\s+/, ($m =~ m/<i\s+[^<]*class=['"]+(.*?(?:uil|fa-solid)\s.*)['"]+/gmxi)[0]);
        map { $_ =~ s/"//gmx } @classes;
        @classes = grep(/^(fa|uil|small|big|large|red|green|yellow|round)/, @classes);
        my $uniq = join(" ", sort grep(!/(small|big|large|round)/, @classes));
        $uniq =~ s/'//gmx;
        if(!$icons->{$uniq}) {
            my $class = join(" ", @classes);
            $icons->{$uniq} = {
                'class' => $class,
                'used'  => 0,
            };
        }
        $icons->{$uniq}->{'used'}++;
    }
}

if(!$options->{'dry'}) {
    _info("updating %s with %d icons", $target, scalar keys %{$icons});
    my $content = Thruk::Utils::IO::read($target);
    my @newicons;
    for my $class (sort { $icons->{$a}->{'class'} cmp $icons->{$b}->{'class'} } keys %{$icons}) {
        #next if $icons->{$class}->{'used'} == 1;
        push @newicons, '      <div><a class="flex" href="#"><i class="'.$icons->{$class}->{'class'}.'"></i>'.$icons->{$class}->{'class'}.'</a></div>';
    }
    my $newicons = join("\n", @newicons);
    $content =~ s/-->.*?<\!--/-->\n$newicons\n<!--/gmxs;
    Thruk::Utils::IO::write($target, $content);
}
