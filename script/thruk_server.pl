#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib 'lib';

BEGIN {
    $ENV{'THRUK_SRC'} = 'DebugServer';
}

if(grep {/^\-r/} @ARGV) {
    @ARGV = grep {!/^\-r/} @ARGV;
    my @watch = qw/lib script thruk_local.conf thruk.conf/;
    for my $plugin (glob('plugins/plugins-enabled/*/lib')) {
        push @watch, $plugin;
    }
    push @ARGV, '-R', join(',', @watch);
}
# set default port to 3000 unless port is specified
if(!grep {/^\-p/} @ARGV) {
    push @ARGV, '-p', '3000';
}
# use -vvv for most verbose mode for backwards compatibility
if(grep {/^\-vvv/} @ARGV) {
    @ARGV = grep {!/^\-vvv/} @ARGV;
    $ENV{'THRUK_VERBOSE'} = 3;
}
# use -vv for very verbose mode for backwards compatibility
elsif(grep {/^\-vv/} @ARGV) {
    @ARGV = grep {!/^\-vv/} @ARGV;
    $ENV{'THRUK_VERBOSE'} = 2;
}
# use -v for verbose mode for backwards compatibility
if(grep {/^\-v/} @ARGV) {
    @ARGV = grep {!/^\-v/} @ARGV;
    $ENV{'THRUK_VERBOSE'} = 1 unless(defined $ENV{'THRUK_VERBOSE'} && $ENV{'THRUK_VERBOSE'} > 1);
}
# use -d for verbose mode for backwards compatibility
if(grep {/^\-d/} @ARGV) {
    @ARGV = grep {!/^\-d/} @ARGV;
    $ENV{'THRUK_VERBOSE'} = 3;
}

unshift(@ARGV, $Bin.'/thruk.psgi');
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
