use warnings;
use strict;
use Test::More;

use Thruk::Utils::Crypt ();
use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cachefile   = $ENV{'THRUK_TEST_MODULES_CACHE'} || '/tmp/thruk-mod-cache.'.$>.'.json';
my $cache       = {};
my $checkscript = './script/thruk_format_perl_modules';
my $scripthash  = Thruk::Utils::Crypt::hexdigest(Thruk::Utils::IO::read($0).Thruk::Utils::IO::read($checkscript));

sub save_cache {
    return if scalar keys %{$cache} == 0;
    Thruk::Utils::IO::json_lock_store($cachefile, $cache, { skip_config => 1 });
    exit;
}
$SIG{'INT'} = 'save_cache';

if(-e $cachefile) {
    eval {
        $cache = Thruk::Utils::IO::json_lock_retrieve($cachefile);
    };
    diag($@) if $@;
}

open(my $ph, '-|', 'bash -c "find ./t ./script ./lib ./plugins/plugins-available/*/lib -type f" 2>&1') or die('find failed: '.$!);
while(<$ph>) {
    my $file = $_;
    chomp($file);
    if($ARGV[0] && $ARGV[0] ne $file) { next; }
    check_modules($file);
}
close($ph);

save_cache();
END {
    save_cache();
}

done_testing();

################################################################################
sub check_modules {
    my($file) = @_;
    my $content = Thruk::Utils::IO::read($file);
    if($file !~ m/\.(pl|pm|t)$/mx && $content !~ m|\#\!/usr/bin/perl|mx && $content !~ m|\Qexec perl -x\E|mx) {
        return;
    }

    my $hashsum = Thruk::Utils::Crypt::hexdigest($scripthash.$content);
    if($cache->{$file} && $cache->{$file} eq $hashsum) {
        ok(1, sprintf("%s - cached", $file));
        return;
    }

    ok(1, $file);
    my($rc,$out) = Thruk::Utils::IO::cmd([$checkscript, '-n', $file]);
    if($rc != 0) {
        fail("modules in ".$file." not linted. Please run ./script/thruk_format_perl_modules");
        diag($out);
    } else {
        $cache->{$file} = $hashsum;
    }
    return;
}
