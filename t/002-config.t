use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 4;

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

# name will be set upon initialization
if(defined Thruk->config->{'Thruk::Backend'}->{'peer'}) {
    my $backends = Thruk->config->{'Thruk::Backend'}->{'peer'};
    if(ref $backends ne 'ARRAY') { $backends = [$backends]; }
    for my $backend (@{$backends}) {
        delete $backend->{options}->{name};
        delete $backend->{options}    if scalar keys %{$backend->{options}}    == 0;
        delete $backend->{configtool} if scalar keys %{$backend->{configtool}} == 0;
    }
}
is_deeply($config, Thruk->config, 'config matches');

$config = Thruk::Config::get_config('t/data/test_c_style.conf');
is($config->{'Thruk::Backend'}->{'peer'}->{'configtool'}->{'obj_readonly'}, '^(?!.*/test)', 'parsing c style comments');
