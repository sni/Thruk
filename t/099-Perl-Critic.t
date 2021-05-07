#!/usr/bin/env perl
#
# $Id$
#
use warnings;
use strict;
use Digest::MD5;
use English qw(-no_match_vars);
use Storable qw/nfreeze thaw/;
use Test::More;

use Thruk::Utils::IO ();

my $cachefile = $ENV{'THRUK_CRITIC_CACHE_FILE'} || '/tmp/perl-critic-cache.'.$>.'.storable';
my $cache     = {};

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}

eval "use Test::Perl::Critic;";
if ( $EVAL_ERROR ) {
   my $msg = 'Test::Perl::Critic required to criticise code';
   plan( skip_all => $msg );
}
require Perl::Critic::Utils;
require Perl::Critic::Policy::Dynamic::NoIndirect;
require Perl::Critic::Policy::NamingConventions::ProhibitMixedCaseSubs;
require Perl::Critic::Policy::ValuesAndExpressions::ProhibitAccessOfPrivateData;
require Perl::Critic::Policy::Modules::ProhibitPOSIXimport;
require Perl::Critic::Policy::TooMuchCode::ProhibitUnusedImport;

sub save_cache {
    return if scalar keys %{$cache} == 0;
    open(my $fh, '>', $cachefile);
    print $fh nfreeze($cache);
    close($fh);
    chmod(0666, $cachefile);
    exit;
}
$SIG{'INT'} = 'save_cache';

my $rcfile = 't/perlcriticrc';
Test::Perl::Critic->import( -profile => $rcfile );
if(-e $cachefile) {
    eval {
        $cache = thaw(Thruk::Utils::IO::read($cachefile));
        #diag("loaded $cachefile");
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
        my $ctx = Digest::MD5->new;
        open(FILE, '<', $file);
        $ctx->addfile(*FILE);
        close(FILE);
        my $md5 = $ctx->hexdigest;
        if($cache->{$file} and $cache->{$file} eq $md5) {
            ok(1, 'Test::Perl::Critic for "'.$file.'" cached OK');
        } else {
            critic_ok($file) and do { $cache->{$file} = $md5 };
        }
    }
}
save_cache();

END {
    save_cache();
}
