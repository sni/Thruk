use strict;
use warnings;
use Test::More;

BEGIN {
    # enable plugin
    `cd plugins/plugins-enabled && rm -f reports2`;
    `cd plugins/plugins-enabled && ln -s ../plugins-available/reports .`;
}

END {
    # restore default
    `cd plugins/plugins-enabled && rm -f reports`;
    `cd plugins/plugins-enabled && ln -s ../plugins-available/reports2 .`;
    unlink('root/thruk/plugins/reports');
}


use lib 'plugins/plugins-enabled/reports/lib';
use_ok 'Thruk::View::PDF::Reuse';

done_testing();
