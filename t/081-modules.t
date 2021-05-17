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
END {
    save_cache();
}

if(-e $cachefile) {
    eval {
        $cache = Thruk::Utils::IO::json_lock_retrieve($cachefile);
    };
    diag($@) if $@;
}

################################################################################
my @files = Thruk::Utils::IO::all_perl_files("./t", "./script", "./lib", glob("./plugins/plugins-available/*/lib"));
plan( tests => scalar @files);
for my $file (@files) {
    check_modules($file);
}
exit;

################################################################################
sub check_modules {
    my($file) = @_;
    my $hashsum = Thruk::Utils::Crypt::hexdigest($scripthash.Thruk::Utils::IO::read($file));
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
