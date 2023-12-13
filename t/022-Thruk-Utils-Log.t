#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;

use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

use_ok('Thruk::Utils::Log');

open(my $ph, '-|', 'bash -c "find ./lib ./plugins/plugins-available/*/lib -type f" 2>&1 | grep -v results/') or die('find failed: '.$!);
while(<$ph>) {
    my $line = $_;
    chomp($line);
    check_logger($line);
}
done_testing();


sub check_logger {
    my($file) = @_;
    ok($file, $file);
    return if $file =~ m|/Monitoring/Livestatus.pm$|gmx;
    return if $file =~ m|/Thruk/Utils/Log.pm$|gmx;
    my $content = Thruk::Utils::IO::read($file);
    return if $content =~ m/\Quse Thruk::Utils::Log\E/gmx;
    $content =~ s|::make_info\(||gmx; # reduce false positive
    if($content =~ m/^(.*(_debug|_error|_warn|_info|_audit_log)\(.*)/gmx) {
        my $line = $1;
        unless($content =~ m/\Quse Thruk::Utils::Log\E/gmx) {
            fail($file." uses logger but misses 'use Thruk::Utils::Log'");
            diag($line);
        }
    }
    return;
}
