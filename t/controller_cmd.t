use strict;
use warnings;
use Test::More tests => 1721;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::cmd' }

for my $file (sort glob("templates/cmd/*")) {
    if($file eq '.' or $file eq '..') {}
    elsif($file =~ m/templates\/cmd\/cmd_typ_(\d+)\.tt/mx) {
        TestUtils::test_page(
            'url'     => '/cmd?cmd_typ='.$1,
            'like'    => 'External Command Interface',
            'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
        );
        TestUtils::test_page(
            'url'     => '/cmd?cmd_typ='.$1.'&cmd_mod=2&test_only=1',
            'like'    => 'External Command Interface',
            'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
        );
    }
    elsif($file =~ m/templates\/cmd\/cmd_typ_c(\d+)\.tt/mx) {
        TestUtils::test_page(
            'url'     => '/thruk/cgi-bin/cmd.cgi?quick_command='.$1.'&confirm=no',
            'like'    => 'External Command Interface',
            'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
        );
    }
    else {
        BAIL_OUT("found file which does not match cmd template: ".$file);
    }
}
