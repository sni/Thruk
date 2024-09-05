use warnings;
use strict;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'local test only'   if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'test skipped'      if defined $ENV{'NO_DISABLED_PLUGINS_TEST'};

    # enable plugin
    `cd plugins/plugins-enabled && ln -s ../plugins-available/editor .`;

    plan tests => 30;
};

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# test modules
unshift @INC, 'plugins/plugins-available/editor/lib';
use_ok 'Thruk::Controller::editor';

###########################################################
# test main page
TestUtils::test_page(
    'url'             => '/thruk/cgi-bin/editor.cgi',
    'like'            => 'Editor',
);

# make sure syntax highlighting works
for my $alias (qw/naemon nagios/) {
    TestUtils::test_page(
        'url'             => '/thruk/vendor/ace-builds-1.4.12/src-min-noconflict/mode-'.$alias.'.js',
        'like'            => ['TextHighlightRules', 'servicegroup_members', 'NaemonHighlightRules'],
    );
}

# restore default
`cd plugins/plugins-enabled && rm -f editor`;