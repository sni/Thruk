use warnings;
use strict;
use Data::Dumper;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk");
use_ok("Thruk::Config");
use_ok("Thruk::Action::AddDefaults");

my $config = Thruk::Config::set_config_env();
is(ref Thruk->config, 'HASH', "got a config");
ok(defined Thruk->config->{'thrukversion'}, "got a version");

chomp(my $makefile_version = `grep "^VERSION\ *=" Makefile | head -n 1 | awk '{ print \$3 }'`);
is($makefile_version, $Thruk::Config::VERSION, "Makefile shows Thruk::Config::VERSION: ".$Thruk::Config::VERSION);

$config = Thruk::Config::set_config_env('t/data/test_c_style.conf');
is($config->{'Thruk::Backend'}->{'peer'}->{'configtool'}->{'obj_readonly'}, '^(?!.*/test)', 'parsing c style comments');

eval "use Config::General";
if(!$@) {
    for my $file (qw|thruk.conf thruk_local.conf cgi.cfg support/naglint.conf.example t/data/test_hash_comments.cfg|) {
        next unless -f $file;
        ok(1, "reading: ".$file);
        my %general_conf = Config::General::ParseConfig(-ConfigFile => $file,
                                                        -UTF8       => 1,
                                                        -CComments  => 0,
        );
        my $thruk_conf = Thruk::Config::read_config_file($file);
        _clean_extra_config_data($thruk_conf);
        is_deeply($thruk_conf, \%general_conf, "Thruk::Config returns the same as Config::General for ".$file) or diag(Dumper($thruk_conf, \%general_conf));
    }
}

####################################################
{
    local $ENV{'THRUK_CONFIG'} = 't/data/nested_config';
    my $config = Thruk::Config::set_config_env();
    my $expected_backends = {
        'peer' => [{ 'name' => 'local1', '_FILE' => 't/data/nested_config/thruk_local.d/a.conf', '_LINE' => 4 },
                   { 'name' => 'local2', '_FILE' => 't/data/nested_config/thruk_local.d/b.conf', '_LINE' => 9 },
                   { 'name' => 'local3', '_FILE' => 't/data/nested_config/thruk_local.d/b.conf', '_LINE' => 12 },
                   { 'name' => 'local4', '_FILE' => 't/data/nested_config/thruk_local.conf', '_LINE' => 8 }
    ]};
    my $expected_bp_config = {
        'objects_reload_cmd' => '/bin/true',
        'refresh_interval' => 1,
    };
    my $expected_menu_states = {
        'General' => '0',
        'System' => '1',
        'Test' => '1'
    };
    is_deeply($config->{'Thruk::Backend'}, $expected_backends, "parsing backends from thruk_local.d");
    is_deeply($config->{'backend_debug'}, 1, "parsing scalars from thruk_local.d");
    is_deeply($config->{'Thruk::Plugin::BP'}, $expected_bp_config, "parsing component config from thruk_local.d");
    is_deeply($config->{'initial_menu_state'}, $expected_menu_states, "parsing menu states config from thruk_local.d");
};

####################################################
{
    local $ENV{'THRUK_CONFIG'} = 't/data/separated_hashes';
    my $config = Thruk::Config::set_config_env();
    my $expected_actions = {
        "a" => 1,
        "b" => 2,
        "c" => 3,
        "d" => 4,
    };
    is_deeply($config->{'action_menu_actions'}, $expected_actions, "parsing backends from thruk_local.d");
};

####################################################
{
    my $config = Thruk::Config::set_config_env('t/data/test_spaces.conf');
    my $expected_user = {
        'Test User' => {
            'show_full_commandline' => '2'
        }
    };
    is_deeply($config->{'User'}, $expected_user, "parsing blocks with space including names");
};

####################################################
{
    local $ENV{'THRUK_CONFIG'} = 't/data/scalar_values';
    my $config = Thruk::Config::set_config_env();
    is_deeply($config->{'cookie_auth_domain'}, 'test.local', "parsing cookie domain from thruk_local.d");
};

####################################################
{
    eval {
        my $conf = Thruk::Config::read_config_file([sort glob('t/data/broken_config/*.conf')]);
    };
    my $err = $@;
    like($err, "/\Qunclosed '<component>' block, started in: t/data/broken_config/a.conf:2\E/", "broken config returns error");
};

####################################################
{
    eval {
        my $conf = Thruk::Config::read_config_file([sort glob('t/data/broken_config2/*.conf')]);
    };
    my $err = $@;
    like($err, "/\Qunexpected closing block found: '</peer>' in: t/data/broken_config2/a.conf:5\E/", "broken config returns error");
};

####################################################
{
    local $ENV{'THRUK_CONFIG'} = 't/data/split_plugins';
    my $config = Thruk::Config::set_config_env();
    my $expected = {
        test => 2,
        a    => 1,
        b    => 1,
    };
    is_deeply($config->{'Thruk::Plugin::test'}, $expected, "parsing multiple plugin sections from t/data/split_plugins/");
};

####################################################
{
    local $ENV{'THRUK_CONFIG'} = 't/data/number_lists';
    my $config = Thruk::Config::set_config_env();
    my $exp = [ '3', '0-4,11-12' ];
    is_deeply($config->{'command_disabled'}, $exp, "parsing config from t/data/number_lists/");
};

####################################################
{
    local $ENV{'THRUK_CONFIG'} = 't/data/user_overrides';
    my $config = Thruk::Config::set_config_env();
    is_deeply($config->{'user_password_min_length'}, 5, "parsing value from t/data/user_overrides/");
    my $exp = { readonly => 1 };
    is_deeply($config->{'Thruk::Plugin::Panorama'}, $exp, "parsing value from t/data/user_overrides/");

    my $c = TestUtils::get_c();
    local $c->stash->{'remote_user'} = "test";
    Thruk::Action::AddDefaults::add_safe_defaults($c);

    is_deeply($c->config->{'user_password_min_length'}, 10, "parsing test user value from t/data/user_overrides/");
    $exp = { readonly => 0 };
    is_deeply($c->config->{'Thruk::Plugin::Panorama'}, $exp, "parsing test user value from t/data/user_overrides/");
};


####################################################
{
    local $ENV{'THRUK_CONFIG'} = 't/data/editor_config';
    my $config = Thruk::Config::set_config_env();
    my $exp = [{ 'files' => { 'action' => 'perl_editor_menu', 'filter' => '\\.pm$', 'folder' => 'etc/thruk/bp/', 'syntax' => 'perl' }, 'name' => 'BP Functions' },
               { 'files' => { 'filter' => '\\.tbp$', 'folder' => 'etc/thruk/bp/' }, 'name' => 'BP Files' }];
    is_deeply($config->{'editor'}, $exp, "parsing value from thruk_local.d");

    my $adm = [{ 'files' => { 'action' => 'perl_editor_menu', 'filter' => '\\.pm$', 'folder' => 'etc/thruk/bp/', 'syntax' => 'perl' }, 'name' => 'Admin BP1' },
               { 'files' => { 'filter' => '\\.tbp$', 'folder' => 'etc/thruk/bp/' }, 'name' => 'Admin BP2' } ];
    my $c = TestUtils::get_c();
    local $c->stash->{'remote_user'} = "test";
    local $c->{'config'} = $config;
    Thruk::Action::AddDefaults::add_safe_defaults($c);

    is_deeply($c->config->{'editor'}, $adm, "parsing test user value from t/data/editor_config/");
};

####################################################
{
    local $ENV{'THRUK_CONFIG'} = 't/data/nested_hash';
    my $config = Thruk::Config::set_config_env();
    my $exp = [
        { 'login' => 'l1', 'client_id' => 'c1', 'id' => 'p1' },
        { 'login' => 'l2', 'client_id' => 'c2', 'id' => 'p2' },
        { 'login' => 'l3', 'client_id' => 'c3', 'id' => 'p3' },
        { 'login' => 'l4', 'client_id' => 'c4', 'id' => 'oauth' },
    ];
    is_deeply($config->{'auth_oauth'}->{'provider'}, $exp, "parsing value from t/data/nested_hash/");
};

####################################################

done_testing();

####################################################
sub _clean_extra_config_data {
    my($thruk_conf) = @_;
    return unless ref $thruk_conf eq 'HASH';
    for my $key (sort keys %{$thruk_conf}) {
        if($key =~ m/^(_FILE|_LINE)$/mx) {
            delete $thruk_conf->{$key};
        }
        elsif(ref $thruk_conf->{$key} eq 'HASH') {
            _clean_extra_config_data($thruk_conf->{$key});
        }
        elsif(ref $thruk_conf->{$key} eq 'ARRAY') {
            for my $v (@{$thruk_conf->{$key}}) {
                _clean_extra_config_data($v);
            }
        }
    }
}
