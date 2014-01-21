package Thruk::Backend::Pool;

use strict ();
use warnings ();
use threads ();
use Carp qw/confess/;

use Thruk::Pool::Simple ();
use Thruk::Backend::Peer ();
use Config::General ();
use File::Slurp qw/read_file/;

=head1 NAME

Thruk::Backend::Pool - Pool of backend connections

=head1 DESCRIPTION

Pool of backend connections

=head1 METHODS

=cut

$SIG{PIPE} = sub {
    confess("broken pipe");
};

######################################

=head2 set_default_config

return config with defaults added

=cut

sub set_default_config {
    my( $config ) = @_;

    # defaults
    unless($config->{'url_prefix_fixed'}) {
        $config->{'url_prefix'} = exists $config->{'url_prefix'} ? $config->{'url_prefix'} : '';
        $config->{'url_prefix'} =~ s|/+$||mx;
        $config->{'url_prefix'} =~ s|^/+||mx;
        $config->{'product_prefix'} = $config->{'product_prefix'} || 'thruk';
        $config->{'product_prefix'} =~ s|^/+||mx;
        $config->{'product_prefix'} =~ s|/+$||mx;
        $config->{'url_prefix'} = '/'.$config->{'url_prefix'}.'/'.$config->{'product_prefix'}.'/';
        $config->{'url_prefix'} =~ s|/+|/|gmx;
        $config->{'url_prefix_fixed'} = 1;
    }
    my $defaults = {
        'cgi.cfg'                       => 'cgi.cfg',
        bug_email_rcpt                  => 'bugs@thruk.org',
        home_link                       => 'http://www.thruk.org',
        mode_file                       => '0660',
        mode_dir                        => '0770',
        backend_debug                   => 0,
        connection_pool_size            => undef,
        product_prefix                  => 'thruk',
        use_ajax_search                 => 1,
        ajax_search_hosts               => 1,
        ajax_search_hostgroups          => 1,
        ajax_search_services            => 1,
        ajax_search_servicegroups       => 1,
        ajax_search_timeperiods         => 1,
        shown_inline_pnp                => 1,
        use_feature_trends              => 1,
        use_wait_feature                => 1,
        wait_timeout                    => 10,
        use_frames                      => 1,
        use_strict_host_authorization   => 0,
        make_auth_user_lowercase        => 0,
        make_auth_user_uppercase        => 0,
        can_submit_commands             => 1,
        group_paging_overview           => '*3, 10, 100, all',
        group_paging_grid               => '*5, 10, 50, all',
        group_paging_summary            => '*10, 50, 100, all',
        default_theme                   => 'Thruk',
        datetime_format                 => '%Y-%m-%d  %H:%M:%S',
        datetime_format_long            => '%a %b %e %H:%M:%S %Z %Y',
        datetime_format_today           => '%H:%M:%S',
        datetime_format_log             => '%B %d, %Y  %H',
        datetime_format_trends          => '%a %b %e %H:%M:%S %Y',
        title_prefix                    => '',
        use_pager                       => 1,
        start_page                      => $config->{'url_prefix'}.'main.html',
        documentation_link              => $config->{'url_prefix'}.'docs/index.html',
        show_notification_number        => 1,
        strict_passive_mode             => 1,
        hide_passive_icon               => 0,
        show_full_commandline           => 1,
        show_modified_attributes        => 1,
        show_config_edit_buttons        => 0,
        show_backends_in_table          => 0,
        show_logout_button              => 0,
        backends_with_obj_config        => {},
        use_feature_statusmap           => 0,
        use_feature_statuswrl           => 0,
        use_feature_histogram           => 0,
        use_feature_configtool          => 0,
        use_feature_recurring_downtime  => 1,
        use_feature_bp                  => 0,
        use_service_description         => 0,
        use_bookmark_titles             => 0,
        use_dynamic_titles              => 1,
        use_new_search                  => 1,
        use_new_command_box             => 1,
        all_problems_link               => $config->{'url_prefix'}."cgi-bin/status.cgi?style=combined&amp;hst_s0_hoststatustypes=4&amp;hst_s0_servicestatustypes=31&amp;hst_s0_hostprops=10&amp;hst_s0_serviceprops=0&amp;svc_s0_hoststatustypes=3&amp;svc_s0_servicestatustypes=28&amp;svc_s0_hostprops=10&amp;svc_s0_serviceprops=10&amp;svc_s0_hostprop=2&amp;svc_s0_hostprop=8&amp;title=All+Unhandled+Problems",
        show_long_plugin_output         => 'popup',
        info_popup_event_type           => 'onclick',
        info_popup_options              => 'STICKY,CLOSECLICK,HAUTO,MOUSEOFF',
        cmd_quick_status                => {
                    default                => 'reschedule next check',
                    reschedule             => 1,
                    downtime               => 1,
                    comment                => 1,
                    acknowledgement        => 1,
                    active_checks          => 1,
                    notifications          => 1,
                    submit_result          => 1,
                    reset_attributes       => 1,
        },
        cmd_defaults                    => {
                    ahas                   => 0,
                    broadcast_notification => 0,
                    force_check            => 0,
                    force_notification     => 0,
                    send_notification      => 1,
                    sticky_ack             => 1,
                    persistent_comments    => 1,
                    persistent_ack         => 0,
                    ptc                    => 0,
                    use_expire             => 0,
        },
        command_disabled                    => {},
        force_sticky_ack                    => 0,
        force_send_notification             => 0,
        force_persistent_ack                => 0,
        force_persistent_comments           => 0,
        downtime_duration                   => 7200,
        expire_ack_duration                 => 86400,
        show_custom_vars                    => [],
        themes_path                         => './themes',
        priorities                      => {
                    5                       => 'Business Critical',
                    4                       => 'Top Production',
                    3                       => 'Production',
                    2                       => 'Standard',
                    1                       => 'Testing',
                    0                       => 'Development',
        },
        no_external_job_forks               => 0,
        host_action_icon                    => 'action.gif',
        service_action_icon                 => 'action.gif',
        cookie_path                         => $config->{'url_prefix'},
        thruk_bin                           => '/usr/bin/thruk',
        thruk_init                          => '/etc/init.d/thruk',
        thruk_shell                         => '/bin/bash -l -c',
        first_day_of_week                   => 0,
        weekdays                        => {
                    '0'                     => 'Sunday',
                    '1'                     => 'Monday',
                    '2'                     => 'Tuesday',
                    '3'                     => 'Wednesday',
                    '4'                     => 'Thursday',
                    '5'                     => 'Friday',
                    '6'                     => 'Saturday',
                    '7'                     => 'Sunday',
                                           },
        'mobile_agent'                  => 'iPhone,Android,IEMobile',
        'show_error_reports'            => 1,
        'skip_js_errors'                => [ 'cluetip is not a function', 'sprite._defaults is undefined' ],
        'cookie_auth_login_url'             => 'thruk/cgi-bin/login.cgi',
        'cookie_auth_restricted_url'        => 'http://localhost/thruk/cgi-bin/restricted.cgi',
        'cookie_auth_session_timeout'       => 86400,
        'cookie_auth_session_cache_timeout' => 5,
        'perf_bar_mode'                     => 'match',
        'sitepanel'                         => 'auto',
        'ssl_verify_hostnames'              => 1,
        'precompile_templates'              => 1,
        'report_use_temp_files'             => 14,
        'report_max_objects'                => 1000,
        'perf_bar_pnp_popup'                => 1,
        'status_color_background'           => 0,
        'apache_status'                     => {},
    };
    $defaults->{'thruk_bin'} = 'script/thruk' if -f 'script/thruk';
    for my $key (keys %{$defaults}) {
        $config->{$key} = exists $config->{$key} ? $config->{$key} : $defaults->{$key};
    }

    # make a nice path
    for my $key (qw/tmp_path var_path/) {
        $config->{$key} =~ s/\/$//mx if $config->{$key};
    }

    # merge hashes
    for my $key (qw/cmd_quick_status cmd_defaults/) {
        $config->{$key} = { %{$defaults->{$key}}, %{ $config->{$key}} };
    }
    # command disabled should be a hash
    if(ref $config->{'command_disabled'} ne 'HASH') {
        $config->{'command_disabled'} = array2hash(expand_numeric_list($config->{'command_disabled'}));
    }

    $ENV{'THRUK_SRC'} = 'SCRIPTS' unless defined $ENV{'THRUK_SRC'};
    # external jobs can be disabled by env
    if(defined $ENV{'NO_EXTERNAL_JOBS'}
       or $ENV{'THRUK_SRC'} eq 'SCRIPTS'
       or $ENV{'THRUK_SRC'} eq 'CLI')
    {
        $config->{'no_external_job_forks'} = 1;
    }

    $config->{'extra_version'}      = '' unless defined $config->{'extra_version'};
    $config->{'extra_version_link'} = '' unless defined $config->{'extra_version_link'};
    if(defined $ENV{'OMD_ROOT'} and -s $ENV{'OMD_ROOT'}."/version") {
        my $omdlink = readlink($ENV{'OMD_ROOT'}."/version");
        $omdlink    =~ s/.*?\///gmx;
        $omdlink    =~ s/^(\d+)\.(\d+).(\d{4})(\d{2})(\d{2})/$1.$2~$3-$4-$5/gmx; # nicer snapshots
        $config->{'extra_version'}      = 'OMD '.$omdlink;
        $config->{'extra_version_link'} = 'http://www.omdistro.org';
    }
    elsif($config->{'project_root'} && -s $config->{'project_root'}.'/naemon-version') {
        $config->{'extra_version'}      = read_file($config->{'project_root'}.'/naemon-version');
        $config->{'extra_version_link'} = 'http://www.naemon.org';
    }

    # set apache status url
    if($ENV{'CONFIG_APACHE_TCP_PORT'}) {
        $config->{'apache_status'}->{'Site'} = 'http://127.0.0.1:'.$ENV{'CONFIG_APACHE_TCP_PORT'}.'/server-status';
    }

    # additional user template paths?
    if(defined $config->{'user_template_path'} and defined $config->{templates_paths}) {
        if(scalar @{$config->{templates_paths}} == 0 || $config->{templates_paths}->[0] ne $config->{'user_template_path'}) {
            unshift @{$config->{templates_paths}}, $config->{'user_template_path'};
        }
    }

    $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = $config->{'ssl_verify_hostnames'};

    return;
}

########################################

=head2 init_backend_thread_pool

  init_backend_thread_pool()

init thread connection pool

=cut

sub init_backend_thread_pool {
    our($peer_order, $peers, $pool, $pool_size);
    if(defined $peers) {
        return;
    }

    $peer_order  = [];
    $peers       = {};

    my $config       = get_config();
    my $peer_configs = $config->{'Component'}->{'Thruk::Backend'}->{'peer'} || $config->{'Thruk::Backend'}->{'peer'};
    $peer_configs    = ref $peer_configs eq 'HASH' ? [ $peer_configs ] : $peer_configs;
    $peer_configs    = [] unless defined $peer_configs;
    my $num_peers    = scalar @{$peer_configs};
    if(defined $config->{'connection_pool_size'}) {
        $pool_size   = $config->{'connection_pool_size'};
    } elsif($num_peers >= 3) {
        $pool_size   = $num_peers;
    } else {
        $pool_size   = 1;
    }
    $config->{'deprecations_shown'} = {};
    $pool_size       = $num_peers if $num_peers < $pool_size;

    # if we have multiple https backends, make sure we use the thread safe IO::Socket::SSL
    my $https_count = 0;
    for my $peer_config (@{$peer_configs}) {
        if($peer_config->{'options'} && $peer_config->{'options'}->{'peer'} && $peer_config->{'options'}->{'peer'} =~ m/^https/mxio) {
            $https_count++;
        }
    }

    if($https_count > 2 and $pool_size > 1) {
        eval {
            require IO::Socket::SSL;
            IO::Socket::SSL->import();
        };
        if($@) {
            die('IO::Socket::SSL and Net::SSLeay (>1.43) is required for multiple parallel https connections: '.$@);
        }
        if(!$Net::SSLeay::VERSION or $Net::SSLeay::VERSION < 1.43) {
            die('Net::SSLeay (>=1.43) is required for multiple parallel https connections, you have '.($Net::SSLeay::VERSION ? $Net::SSLeay::VERSION : 'unknown'));
        }
        if($INC{'Crypt/SSLeay.pm'}) {
            die('Crypt::SSLeay must not be loaded for multiple parallel https connections!');
        }
    }

    if($num_peers > 0) {
        $SIG{'ALRM'} = 'IGNORE'; # shared signals will kill waiting threads
        my  $peer_keys   = {};
        for my $peer_config (@{$peer_configs}) {
            my $peer = Thruk::Backend::Peer->new( $peer_config, $config->{'logcache'}, $peer_keys );
            $peer_keys->{$peer->{'key'}} = 1;
            $peers->{$peer->{'key'}}     = $peer;
            push @{$peer_order}, $peer->{'key'};
            if($peer_config->{'groups'} and !$config->{'deprecations_shown'}->{'backend_groups'}) {
                $Thruk::deprecations_log = [] unless defined $Thruk::deprecations_log;
                push @{$Thruk::deprecations_log}, "*** DEPRECATED: using groups option in peers is deprecated and will be removed in future releases.";
                $config->{'deprecations_shown'}->{'backend_groups'} = 1;
            }
        }
        if($pool_size > 1) {
            printf(STDERR "mem:% 7s MB  before pool with %d members\n", Thruk::Utils::get_memory_usage(), $pool_size) if $ENV{'THRUK_PERFORMANCE_DEBUG'};
            $SIG{'USR1'}  = undef;
            $pool = Thruk::Pool::Simple->new(
                min      => $pool_size,
                max      => $pool_size,
                do       => [\&Thruk::Backend::Pool::_do_thread ],
            );
            printf(STDERR "mem:% 7s MB  after pool\n", Thruk::Utils::get_memory_usage()) if $ENV{'THRUK_PERFORMANCE_DEBUG'};
        } else {
            $ENV{'THRUK_NO_CONNECTION_POOL'} = 1;
        }
    }

    return;
}

########################################

=head2 _do_thread

  _do_thread()

do the work on threads

=cut

sub _do_thread {
    my($key, $function, $arg) = @_;
    return(do_on_peer($key, $function, $arg));
}

########################################

=head2 do_on_peer

  do_on_peer($key, $function, $args)

run a function on a backend peer

=cut

sub do_on_peer {
    my($key, $function, $arg) = @_;

    # make it possible to run code in thread context
    if(ref $arg eq 'ARRAY') {
        for(my $x = 0; $x <= scalar @{$arg}; $x++) {
            if($arg->[$x] and $arg->[$x] eq 'eval') {
                my $inc;
                my $code = $arg->[$x+1];
                if(ref($code) eq 'HASH') {
                    chomp(my $pwd = `pwd`);
                    for my $path ('/', (defined $ENV{'OMD_ROOT'} ? $ENV{'OMD_ROOT'}.'/share/thruk/plugins/plugins-available/' : $pwd.'/plugins/plugins-available/')) {
                        if(-e $path.'/'.$code->{'inc'}) {
                            $inc  = $path.'/'.$code->{'inc'};
                            last;
                        }
                    }
                    $code = $code->{'code'};
                    push @INC, $inc if $inc;
                }
                ## no critic
                eval($code);
                ## use critic
                if($@) {
                    require Data::Dumper;
                    Data::Dumper->import();
                    die("eval failed:".Dumper(`pwd`, $arg, $@));
                }
                pop @INC if $inc;
            }
        }
    }

    my $peer = $Thruk::Backend::Pool::peers->{$key};
    confess("no peer for key: $key, got: ".join(', ', keys %{$Thruk::Backend::Pool::peers})) unless defined $peer;
    my($type, $size, $data, $last_error);
    my $errors = 0;
    while($errors < 3) {
        eval {
            ($data,$type,$size) = $peer->{'class'}->$function( @{$arg} );
            if(defined $data and !defined $size) {
                if(ref $data eq 'ARRAY') {
                    $size = scalar @{$data};
                }
                elsif(ref $data eq 'HASH') {
                    $size = scalar keys %{$data};
                }
            }
            $size = 0 unless defined $size;
        };
        if($@) {
            $last_error = $@;
            $last_error =~ s/\s+at\s+.*?\s+line\s+\d+//gmx;
            $last_error =~ s/thread\s+\d+//gmx;
            $last_error =~ s/^ERROR:\ //gmx;
            $last_error = "ERROR: ".$last_error;
            $errors++;
            if($last_error =~ m/can't\ get\ db\ response,\ not\ connected\ at/mx) {
                $peer->{'class'}->reconnect();
            } else {
                last;
            }
        } else {
            last;
        }
    }

    # don't keep connections open
    if($peer->{'logcache'}) {
        $peer->{'logcache'}->_disconnect();
    }

    return([$type, $size, $data, $last_error]);
}

########################################

=head2 get_config

  get_config()

return small thruks config. Needed for the backends only.

=cut

sub get_config {
    for my $path ('.', $ENV{'CATALYST_CONFIG'}, $ENV{'THRUK_CONFIG'}) {
        next unless defined $path;
        push @files, $path.'/thruk.conf'       if -f $path.'/thruk.conf';
        push @files, $path.'/thruk_local.conf' if -f $path.'/thruk_local.conf';
    }

    my %config;
    for my $file (@files) {
        my %conf = Config::General::ParseConfig(-ConfigFile => $file,
                                                -UTF8       => 1,
                                                -CComments  => 0,
        );
        for my $key (keys %conf) {
            if(defined $config{$key} and ref $config{$key} eq 'HASH') {
                $config{$key} = { %{$config{$key}}, %{$conf{$key}} };
            } else {
                $config{$key} = $conf{$key};
            }
        }
    }

    set_default_config(\%config);

    return \%config;
}

########################################

=head2 expand_numeric_list

  expand_numeric_list($txt, $c)

return expanded list.
ex.: converts '3,7-9,15' -> [3,7,8,9,15]

=cut

sub expand_numeric_list {
    my $txt  = shift;
    my $c    = shift;
    my $list = {};
    return [] unless defined $txt;

    for my $item (ref $txt eq 'ARRAY' ? @{$txt} : $txt) {
        for my $block (split/\s*,\s*/mx, $item) {
            if($block =~ m/(\d+)\s*\-\s*(\d+)/gmx) {
                for my $nr ($1..$2) {
                    $list->{$nr} = 1;
                }
            } elsif($block =~ m/^(\d+)$/gmx) {
                    $list->{$1} = 1;
            } else {
                $c->log->error("'$block' is not a valid number or range") if defined $c;
            }
        }
    }

    my @arr = sort keys %{$list};
    return \@arr;
}

########################################

=head2 array2hash

  array2hash($data, [ $key, [ $key2 ]])

create a hash by key

=cut
sub array2hash {
    my $data = shift;
    my $key  = shift;
    my $key2 = shift;

    return {} unless defined $data;
    confess("not an array") unless ref $data eq 'ARRAY';

    my %hash;
    if(defined $key2) {
        for my $d (@{$data}) {
            $hash{$d->{$key}}->{$d->{$key2}} = $d;
        }
    } elsif(defined $key) {
        %hash = map { $_->{$key} => $_ } @{$data};
    } else {
        %hash = map { $_ => $_ } @{$data};
    }

    return \%hash;
}

########################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
