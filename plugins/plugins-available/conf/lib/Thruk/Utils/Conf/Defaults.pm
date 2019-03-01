package Thruk::Utils::Conf::Defaults;

use strict;
use warnings;
use Thruk::Utils::Conf;
use Thruk::Authentication::User;

=head1 NAME

Thruk::Utils::Conf::Defaults - Defaults for various configuration settings

=head1 DESCRIPTION

Defaults for various configuration settings

=head1 METHODS

=cut

##########################################################

=head2 get_thruk_cfg

return defaults for the thruk_local.conf

=cut
sub get_thruk_cfg {
    my ( $self, $c ) = @_;
    my $conf = {
                title_prefix                            => ['STRING', ''],
                use_timezone                            => ['STRING', 'CET'],
                server_timezone                         => ['STRING', ''],
                default_user_timezone                   => ['STRING', ''],
                use_strict_host_authorization           => ['BOOL',   '0'],
                use_frames                              => ['BOOL',   '0'],
                strict_passive_mode                     => ['BOOL',   '1'],
                start_page                              => ['STRING', ''],
                documentation_link                      => ['STRING', ''],
                all_problems_link                       => ['STRING', ''],
                allowed_frame_links                     => ['STRING', ''],
                default_theme                           => ['LIST',   'Thruk', Thruk::Utils::array2hash($c->config->{'View::TT'}->{'PRE_DEFINE'}->{'themes'}) ],
                tmp_path                                => ['STRING', ''],
                ssi_path                                => ['STRING', ''],
                plugin_path                             => ['STRING', ''],
                user_template_path                      => ['STRING', ''],
                use_pager                               => ['BOOL',   '1'],
                paging_steps                            => ['ARRAY',  []],
                group_paging_overview                   => ['ARRAY',  []],
                group_paging_summary                    => ['ARRAY',  []],
                group_paging_grid                       => ['ARRAY',  []],
                show_long_plugin_output                 => ['LIST', 'popup', Thruk::Utils::array2hash([qw/popup inline off/]) ],
                info_popup_event_type                   => ['LIST', 'onclick', Thruk::Utils::array2hash([qw/onclick onmouseover/]) ],
                info_popup_options                      => ['STRING', ''],
                show_notification_number                => ['BOOL',   '1'],
                show_backends_in_table                  => ['BOOL',   '0'],
                show_full_commandline                   => ['LIST',   '', { '0' => 'off', '1' => 'authorized_for_configuration_information only', '2' => 'everyone' } ],
                resource_file                           => ['STRING', ''],
                shown_inline_pnp                        => ['BOOL',   '1'],
                show_modified_attributes                => ['BOOL',   '1'],
                show_custom_vars                        => ['ARRAY',  []],
                use_new_command_box                     => ['BOOL',   '1'],
                can_submit_commands                     => ['BOOL',   '1'],
                datetime_format                         => ['STRING', ''],
                datetime_format_today                   => ['STRING', ''],
                datetime_format_long                    => ['STRING', ''],
                datetime_format_log                     => ['STRING', ''],
                datetime_format_trends                  => ['STRING', ''],
                use_wait_feature                        => ['BOOL',   '1'],
                wait_timeout                            => ['STRING',   '10'],
    };

    # search useful defaults
    for my $key (keys %{$conf}) {
        if(exists $c->stash->{$key}) {
            $conf->{$key}->[1] = $c->stash->{$key};
        } elsif(exists $c->config->{$key}) {
            $conf->{$key}->[1] = $c->config->{$key};
        } elsif(   $key eq 'use_timezone'
                or $key eq 'server_timezone'
                or $key eq 'default_user_timezone'
                or $key eq 'allowed_frame_links'
                or $key eq 'resource_file'
                or $key eq 'plugin_path'
                or $key eq 'user_template_path'
               ) {
            # no useful default for these onse
        } else {
            die('no default for '.$key);
        }
        if($conf->{$key}->[0] eq 'ARRAY' and ref $conf->{$key}->[1] ne 'ARRAY') {
            $conf->{$key}->[1] = [ split(/\s*,\s*/mx,$conf->{$key}->[1]) ];
        }
    }
    return $conf;
}


##########################################################

=head2 get_cgi_cfg

return defaults for the cgi.cfg

=cut
sub get_cgi_cfg {
    my ( $self ) = @_;

    my $conf = {
        'show_context_help'                         => ['BOOL',   '0'],
        'use_pending_states'                        => ['BOOL',   '1'],
        'default_user_name'                         => ['STRING', 'thrukadmin' ],
        'use_authentication'                        => ['BOOL',   '1'],
        'use_ssl_authentication'                    => ['BOOL',   '0'],
        'lock_author_names'                         => ['BOOL',   '1'],
        'refresh_rate'                              => ['INT', '90'],
        'escape_html_tags'                          => ['BOOL',   '1'],
        'action_url_target'                         => ['STRING', ''],
        'notes_url_target'                          => ['STRING', ''],
    };
    for my $key (@{$Thruk::Authentication::User::possible_roles}) {
        $conf->{$key} = ['MULTI_LIST', [], {} ];
        my $groupkey = $key;
        $groupkey =~ s/^authorized_for_/authorized_contactgroup_for_/gmx;
        $conf->{$groupkey} = ['MULTI_LIST', [], {} ];
    }
    return $conf;
}


##########################################################

1;
