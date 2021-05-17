#!/usr/bin/env perl
#
# $Id$
#
use warnings;
use strict;
use English qw(-no_match_vars);
use Test::More;

use Thruk::Utils::Crypt ();
use Thruk::Utils::IO ();

my $cachefile  = $ENV{'THRUK_CRITIC_CACHE_FILE'} || '/tmp/perl-critic-cache.'.$>.'.json';
my $cache      = {};
my $rcfile     = 't/perlcriticrc';
my $extrahash  = Thruk::Utils::Crypt::hexdigest(Thruk::Utils::IO::read($0).Thruk::Utils::IO::read($rcfile));

plan(skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.') unless $ENV{TEST_AUTHOR};

eval "use Test::Perl::Critic;";
if($EVAL_ERROR) {
    plan(skip_all => 'Test::Perl::Critic required to criticise code');
}

sub save_cache {
    return if scalar keys %{$cache} == 0;
    Thruk::Utils::IO::json_lock_store($cachefile, $cache, { skip_config => 1 });
    exit;
}
$SIG{'INT'} = 'save_cache';
END {
    save_cache();
}

require Perl::Critic::Utils;
require Perl::Critic::Policy::Dynamic::NoIndirect;
require Perl::Critic::Policy::NamingConventions::ProhibitMixedCaseSubs;
require Perl::Critic::Policy::ValuesAndExpressions::ProhibitAccessOfPrivateData;
require Perl::Critic::Policy::Modules::ProhibitPOSIXimport;
require Perl::Critic::Policy::TooMuchCode::ProhibitUnusedImport;
Test::Perl::Critic->import( -profile => $rcfile );
if(-e $cachefile) {
    eval {
        $cache = Thruk::Utils::IO::json_lock_retrieve($cachefile);
    };
    diag($@) if $@;
}

if(scalar @ARGV > 0) {
    plan( tests => scalar @ARGV);
    for my $file (@ARGV) {
        critic_ok($file);
    }
}
else {
    my $dirs = [ 'lib', glob("plugins/plugins-enabled/*/lib") ];
    my @files = Perl::Critic::Utils::all_perl_files(@{$dirs});
    plan( tests => scalar @files);
    for my $file (sort @files) {
        my $hashsum = Thruk::Utils::Crypt::hexdigest($extrahash.Thruk::Utils::IO::read($file));
        if($cache->{$file} and $cache->{$file} eq $hashsum) {
            ok(1, sprintf('Test::Perl::Critic for "%s" - cached', $file));
        } else {
            critic_ok($file) and do { $cache->{$file} = $hashsum };
        }
    }
}
