package Thruk::Utils::Conf::Defaults;

use strict;
use warnings;
use Thruk::Utils::Conf;

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
#                url_prefix
                title_prefix                            => ['STRING', ''],
                use_timezone                            => ['STRING', 'CET'],
                use_strict_host_authorization           => ['BOOL',   '0'],
#                cgi.cfg
                use_frames                              => ['BOOL',   '0'],
                strict_passive_mode                     => ['BOOL',   '1'],
#                delay_pages_after_backend_reload
                start_page                              => ['STRING', ''],
                documentation_link                      => ['STRING', ''],
                all_problems_link                       => ['STRING', ''],
                allowed_frame_links                     => ['STRING', ''],
                use_new_search                          => ['BOOL',   '1'],
                use_ajax_search                         => ['BOOL',   '1'],
                ajax_search_hosts                       => ['BOOL',   '1'],
                ajax_search_hostgroups                  => ['BOOL',   '1'],
                ajax_search_services                    => ['BOOL',   '1'],
                ajax_search_servicegroups               => ['BOOL',   '1'],
                default_theme                           => ['LIST',   'Classic', Thruk::Utils::Conf::to_hash($c->config->{'View::TT'}->{'PRE_DEFINE'}->{'themes'}) ],
                tmp_path                                => ['STRING', ''],
                ssi_path                                => ['STRING', ''],
                plugin_path                             => ['STRING', ''],
                user_template_path                      => ['STRING', ''],
#                log4perl_conf
                use_pager                               => ['BOOL',   '1'],
                paging_steps                            => ['ARRAY',  []],
                group_paging_overview                   => ['ARRAY',  []],
                group_paging_summary                    => ['ARRAY',  []],
                group_paging_grid                       => ['ARRAY',  []],
                info_popup_event_type                   => ['LIST', 'onclick', Thruk::Utils::Conf::to_hash([qw/onclick onmouseover/]) ],
                info_popup_options                      => ['STRING', ''],
                show_notification_number                => ['BOOL',   '1'],
                show_full_commandline                   => ['LIST',   '', { '0' => 'off', '1' => 'authorized_for_configuration_information only', '2' => 'everyone' } ],
                resource_file                           => ['STRING', ''],
                shown_inline_pnp                        => ['BOOL',   '1'],
                can_submit_commands                     => ['BOOL',   '1'],
#                command_disabled
                datetime_format                         => ['STRING', ''],
                datetime_format_today                   => ['STRING', ''],
                datetime_format_long                    => ['STRING', ''],
                datetime_format_log                     => ['STRING', ''],
                datetime_format_trends                  => ['STRING', ''],
                statusmap_default_type                  => ['LIST', '', Thruk::Utils::Conf::to_hash([qw/circle table/]) ],
                statusmap_default_groupby               => ['LIST', '', Thruk::Utils::Conf::to_hash([qw/parent address domain hostgroup servicegroup/]) ],
                use_wait_feature                        => ['BOOL',   '1'],
#                check_local_states
    };

    # search useful defaults
    for my $key (keys %{$conf}) {
        if(exists $c->stash->{$key}) {
            $conf->{$key}->[1] = $c->stash->{$key};
        } elsif(exists $c->config->{$key}) {
            $conf->{$key}->[1] = $c->config->{$key};
        } elsif(   $key eq 'use_timezone'
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
    my ( $self, $c ) = @_;

    my $contacts = $c->{'db'}->get_contacts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'contact' ) ],
                                             sort   => 'name',
                                             remove_duplicates => 1);
    my $all_contacts = {};
    for my $contact (@{$contacts}) {
        $all_contacts->{$contact->{'name'}} = $contact->{'name'}." - ".$contact->{'alias'};
    }

    my $conf = {
#        'main_config_file'                          => ['STRING', ''],
#        'physical_html_path'                        => ['STRING', ''],
#        'url_html_path'                             => ['STRING', ''],
#        'cgi_base_url'                              => ['STRING', ''],
        'show_context_help'                         => ['BOOL',   '0'],
        'use_pending_states'                        => ['BOOL',   '1'],
        'default_user_name'                         => ['STRING', 'thrukadmin' ],
        'use_authentication'                        => ['BOOL',   '1'],
        'use_ssl_authentication'                    => ['BOOL',   '0'],
        'authorized_for_system_commands'            => ['MULTI_LIST', [], $all_contacts ],
        'authorized_for_all_services'               => ['MULTI_LIST', [], $all_contacts ],
        'authorized_for_all_hosts'                  => ['MULTI_LIST', [], $all_contacts ],
        'authorized_for_all_service_commands'       => ['MULTI_LIST', [], $all_contacts ],
        'authorized_for_all_host_commands'          => ['MULTI_LIST', [], $all_contacts ],
        'authorized_for_system_information'         => ['MULTI_LIST', [], $all_contacts ],
        'authorized_for_configuration_information'  => ['MULTI_LIST', [], $all_contacts ],
        'lock_author_names'                         => ['BOOL',   '1'],
#        'default_statusmap_layout'                  =>
#        'default_statuswrl_layout'                  =>
#        'ping_syntax'                               => ['STRING', ''],
        'refresh_rate'                              => ['INT', '90'],
        'escape_html_tags'                          => ['BOOL',   '1'],
        'action_url_target'                         => ['STRING', ''],
        'notes_url_target'                          => ['STRING', ''],
    };
    return $conf;
}


##########################################################


=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
