use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 64;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# test report templates
use_ok('Thruk::Utils::Reports');
my $c         = TestUtils::get_c();
my $templates = Thruk::Utils::Reports::get_report_templates($c);
for my $template (sort keys %{$templates}) {
    TestUtils::test_page(
        url          => '/thruk/cgi-bin/reports2.cgi?report=new&template='.$template.'&action=edit2',
        skip_doctype => 1,
    );
}
