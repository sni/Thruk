use strict;
use warnings;
use Test::More tests => 653;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::cmd' }

for my $file (glob("templates/cmd/*")) {
    if($file eq '.' or $file eq '..') {}
    elsif($file =~ m/templates\/cmd\/cmd_typ_(\d+)\.tt/mx) {
        TestUtils::test_page(
            'url'     => '/cmd?cmd_typ='.$1,
            'like'    => 'External Command Interface',
            'unlike'  => 'internal server error',
        );
    }
    else {
        BAIL_OUT("found file which does not match cmd template: ".$file);
    }
}
