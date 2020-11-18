#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

BEGIN {
    $ENV{'THRUK_MODE'} = 'DEVSERVER';
}

if(grep {/^\-r/} @ARGV) {
    @ARGV = grep {!/^\-r/} @ARGV;
    my @watch = qw/lib script thruk_local.conf thruk.conf thruk_local.d/;
    for my $plugin (glob('plugins/plugins-enabled/*/lib')) {
        push @watch, $plugin;
    }
    push @ARGV, '-R', join(',', @watch);
    # make Filesys-Notify-Simple fallback to simple folder watch.
    # linux-inotify2 somehow watch . as well
    $ENV{'PERL_FNS_NO_OPT'} = 1;
}
# set default port to 3000 unless port is specified
if(!grep {/^\-p/} @ARGV) {
    push @ARGV, '-p', '3000';
}
# set verbose mode
if(my($param) = grep {/^\-+(v+)/} @ARGV) {
    $param =~ s/^\-+//gmx;
    $ENV{'THRUK_VERBOSE'} = length($param);
    @ARGV = grep {!/^\-+v+/} @ARGV;
}
# use -d for debug mode for backwards compatibility
if(grep {/^\-d/} @ARGV) {
    @ARGV = grep {!/^\-d/} @ARGV;
    $ENV{'THRUK_VERBOSE'} = 3 if $ENV{'THRUK_VERBOSE'} < 3;
}

my $bin = $0;
$bin =~ s|/thruk_server.pl$||gmx;
unshift(@ARGV, $bin.'/thruk.psgi');
push @ARGV, '--no-default-middleware';

require Plack::Runner;
my $runner = Plack::Runner->new;
$runner->parse_options(@ARGV);
$runner->run;

###################################################

=head1 NAME

thruk_server.pl - Thruk Development Server

=head1 SYNOPSIS

thruk_server.pl [options]

   -p <port>            use tcp port. default: 3000
   -d                   debug mode
   -v                   verbose mode
   -vv                  very verbose mode
   -vvv                 debug mode
   -h                   display this help and exits
   -r                   restart when files get modified

  also all options from plackup -h should work.

=head1 DESCRIPTION

Run a Thruk Testserver.

=head1 AUTHORS

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
