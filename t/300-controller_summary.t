use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 185;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::summary' }

my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();

my $pages = [
# Step 1
    '/thruk/cgi-bin/summary.cgi',

# standard reports
    '/thruk/cgi-bin/summary.cgi?report=1&standardreport=1',
    '/thruk/cgi-bin/summary.cgi?report=1&standardreport=2',
    '/thruk/cgi-bin/summary.cgi?report=1&standardreport=3',
    '/thruk/cgi-bin/summary.cgi?report=1&standardreport=4',
    '/thruk/cgi-bin/summary.cgi?report=1&standardreport=5',

# custom reports
    '/thruk/cgi-bin/summary.cgi?report=1&displaytype=1&timeperiod=last7days&smon=2&sday=1&syear=2010&shour=0&smin=0&ssec=0&emon=2&eday=28&eyear=2010&ehour=24&emin=0&esec=0&hostgroup=all&servicegroup=all&host=all&alerttypes=3&statetypes=3&hoststates=7&servicestates=120&limit=25',
    '/thruk/cgi-bin/summary.cgi?report=1&displaytype=2&timeperiod=last7days&smon=2&sday=1&syear=2010&shour=0&smin=0&ssec=0&emon=2&eday=28&eyear=2010&ehour=24&emin=0&esec=0&hostgroup=all&servicegroup=all&host=all&alerttypes=3&statetypes=3&hoststates=7&servicestates=120&limit=25',
    '/thruk/cgi-bin/summary.cgi?report=1&displaytype=3&timeperiod=last7days&smon=2&sday=1&syear=2010&shour=0&smin=0&ssec=0&emon=2&eday=28&eyear=2010&ehour=24&emin=0&esec=0&hostgroup=all&servicegroup=all&host=all&alerttypes=3&statetypes=3&hoststates=7&servicestates=120&limit=25',
    '/thruk/cgi-bin/summary.cgi?report=1&displaytype=4&timeperiod=last7days&smon=2&sday=1&syear=2010&shour=0&smin=0&ssec=0&emon=2&eday=28&eyear=2010&ehour=24&emin=0&esec=0&hostgroup=all&servicegroup=all&host=all&alerttypes=3&statetypes=3&hoststates=7&servicestates=120&limit=25',
    '/thruk/cgi-bin/summary.cgi?report=1&displaytype=5&timeperiod=last7days&smon=2&sday=1&syear=2010&shour=0&smin=0&ssec=0&emon=2&eday=28&eyear=2010&ehour=24&emin=0&esec=0&hostgroup=all&servicegroup=all&host=all&alerttypes=3&statetypes=3&hoststates=7&servicestates=120&limit=25',
    '/thruk/cgi-bin/summary.cgi?report=1&displaytype=6&timeperiod=last7days&smon=2&sday=1&syear=2010&shour=0&smin=0&ssec=0&emon=2&eday=28&eyear=2010&ehour=24&emin=0&esec=0&hostgroup=all&servicegroup=all&host=all&alerttypes=3&statetypes=3&hoststates=7&servicestates=120&limit=25',
    '/thruk/cgi-bin/summary.cgi?report=1&displaytype=7&timeperiod=last7days&smon=2&sday=1&syear=2010&shour=0&smin=0&ssec=0&emon=2&eday=28&eyear=2010&ehour=24&emin=0&esec=0&hostgroup=all&servicegroup=all&host=all&alerttypes=3&statetypes=3&hoststates=7&servicestates=120&limit=25',

# Reports using Host/Servicegroups
    '/thruk/cgi-bin/summary.cgi?report=1&displaytype=1&timeperiod=last7days&smon=9&sday=1&syear=2013&shour=0&smin=0&ssec=0&emon=9&eday=24&eyear=2013&ehour=24&emin=0&esec=0&hostgroup='.$hostgroup.'&servicegroup=all&host=all&alerttypes=3&statetypes=3&hoststates=7&servicestates=120&limit=25',
    '/thruk/cgi-bin/summary.cgi?report=1&displaytype=1&timeperiod=last7days&smon=9&sday=1&syear=2013&shour=0&smin=0&ssec=0&emon=9&eday=24&eyear=2013&ehour=24&emin=0&esec=0&hostgroup=all&servicegroup='.$servicegroup.'&host=all&alerttypes=3&statetypes=3&hoststates=7&servicestates=120&limit=25',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Alert Summary Report',
    );
}
