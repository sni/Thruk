use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 3;

use_ok("Thruk");
use_ok("Thruk::Config");
my $config = Thruk::Config::get_config();

# remove some keys which are know to be set later
for my $key (qw/cgi_cfg_stat
                cgi_cfg
                cgi.cfg_effective
                Plugin::Static::Simple
                Plugin::ConfigLoader
                has_feature_minemap
                use_feature_mobile
                use_feature_panorama
                use_feature_statusmap
                use_feature_configtool
                use_feature_reports
                root
                ssi_includes
                static
                secret_key/) {
    delete Thruk->config->{$key};
    delete $config->{$key};
}

is_deeply(Thruk->config, $config, 'config matches');
