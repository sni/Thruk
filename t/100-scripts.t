use warnings;
use strict;
use Test::More tests => 15;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
my @files = qw/naglint nagexp thruk/;
for my $file (@files) {
    check_script($file);
}
exit;

###########################################################
# SUBS
###########################################################
sub check_script {
    my($file) = @_;
    my $cmd = sprintf("./script/%s %s", $file, '-V');
    ok($cmd, "testing : ".$cmd);
    TestUtils::test_command({
        cmd     => $cmd,
        like    => '/\ v'.($Thruk::VERSION || '\d').'/',
        exit    => 0,
    });
    return;
}
