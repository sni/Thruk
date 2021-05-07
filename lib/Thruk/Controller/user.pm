package Thruk::Controller::user;

use warnings;
use strict;

use Thruk ();
use Thruk::Action::AddDefaults ();
use Thruk::Authentication::User ();
use Thruk::Utils ();
use Thruk::Utils::APIKeys ();

=head1 NAME

Thruk::Controller::user - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=head2 index

=cut

##########################################################
sub index {
    my($c) = @_;

    $c->stash->{'page'}            = 'conf';
    $c->stash->{'title'}           = 'User Profile';
    $c->stash->{'infoBoxTitle'}    = 'User Profile';
    $c->stash->{'new_private_key'} = '';

    my $keywords = $c->req->uri->query;
    if($keywords && $keywords =~ m/setcookie/gmx) {
        my $url = delete $c->req->parameters->{'referer'};
        if(!$url || $url !~ m/^\//gmx) {
            $url = $c->stash->{'url_prefix'};
        } else {
            delete $c->req->parameters->{'setcookie'};
            $url = URI->new($url);
            $url->query_form($c->req->parameters);
            $url = $url->as_string;
        }
        return $c->redirect_to($url);
    }

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    if(defined $c->req->parameters->{'action'}) {
        my $action = $c->req->parameters->{'action'};
        my $send   = $c->req->parameters->{'send'};
        if($send && $send eq 'Create New API Key') {
            if(!$c->config->{'api_keys_enabled'}) {
                Thruk::Utils::set_message( $c, 'fail_message', 'API keys are disabled' );
                return $c->redirect_to('user.cgi');
            }
            if($c->config->{'max_api_keys_per_user'} <= 0 || $c->check_user_roles("authorized_for_read_only")) {
                Thruk::Utils::set_message( $c, 'fail_message', 'You have no permission to create API keys.' );
                return $c->redirect_to('user.cgi');
            }
            my $keys = Thruk::Utils::APIKeys::get_keys($c, { user => $c->stash->{'remote_user'}});
            if(scalar @{$keys} >= $c->config->{'max_api_keys_per_user'}) {
                Thruk::Utils::set_message( $c, 'fail_message', 'Maximum number of API keys ('.$c->config->{'max_api_keys_per_user'}.') for this user reached.' );
                return $c->redirect_to('user.cgi');
            }
            my($private_key, undef, undef) = Thruk::Utils::APIKeys::create_key_from_req_params($c);
            if($private_key) {
                Thruk::Utils::set_message( $c, 'success_message', 'API key created' );
                $c->stash->{'new_private_key'} = $private_key;
            }
            return(user_page($c));
        }
        if($action eq 'remove_key') {
            if($c->check_user_roles("authorized_for_read_only")) {
                Thruk::Utils::set_message( $c, 'fail_message', 'You have no permission to delete API keys.' );
                return $c->redirect_to('user.cgi');
            }
            Thruk::Utils::APIKeys::remove_key($c, $c->stash->{'remote_user'}, $c->req->parameters->{'file'});
            Thruk::Utils::set_message( $c, 'success_message', 'API key removed' );
            return $c->redirect_to('user.cgi');
        }
        if($action eq 'save') {
            my $data = Thruk::Utils::get_user_data($c);
            return unless Thruk::Utils::check_csrf($c);
            $data->{'tz'} = $c->req->parameters->{'timezone'};
            if(Thruk::Utils::store_user_data($c, $data)) {
                Thruk::Utils::set_message( $c, 'success_message', 'Settings saved' );
            }
            return $c->redirect_to('user.cgi');
        }
        if($action eq 'site_panel_bookmarks') {
            if($c->req->parameters->{'save'}) {
                my $data = Thruk::Utils::get_user_data($c);
                $data->{'site_panel_bookmarks'} = [] unless $data->{'site_panel_bookmarks'};
                push @{$data->{'site_panel_bookmarks'}}, {
                    name     => $c->req->parameters->{'name'},
                    backends => Thruk::Utils::list($c->req->parameters->{'backends[]'} || []),
                    sections => Thruk::Utils::list($c->req->parameters->{'sections[]'} || []),
                };
                Thruk::Utils::store_user_data($c, $data);
            }
            if($c->req->parameters->{'reorder'}) {
                my $data = Thruk::Utils::get_user_data($c);
                my $neworder = Thruk::Utils::list($c->req->parameters->{'order[]'});
                my $bookmarks = [];
                for my $index (@{$neworder}) {
                    push @{$bookmarks}, $data->{'site_panel_bookmarks'}->[$index];
                }
                $data->{'site_panel_bookmarks'} = $bookmarks;
                Thruk::Utils::store_user_data($c, $data);
            }
            if($c->req->parameters->{'remove'}) {
                my $data = Thruk::Utils::get_user_data($c);
                splice @{$data->{'site_panel_bookmarks'}}, $c->req->parameters->{'index'}, 1;
                Thruk::Utils::store_user_data($c, $data);
            }
            return $c->redirect_to('user.cgi');
        }
    }

    return(user_page($c));
}

##########################################################

=head2 user_page

    print user index page

=cut
sub user_page {
    my($c) = @_;

    $c->stash->{has_jquery_ui}     = 1;
    $c->stash->{'no_auto_reload'}  = 1;
    $c->stash->{'timezones'}       = Thruk::Utils::get_timezone_data($c, 1);

    my $found = 0;
    for my $tz (@{$c->stash->{'timezones'}}) {
        if($tz->{'text'} eq $c->stash->{'user_tz'}) {
            $found = 1;
            last;
        }
    }
    if(!$found) {
        unshift @{$c->stash->{'timezones'}}, {
            text   => $c->stash->{'user_tz'},
            abbr   => '',
            offset => 0,
        };
    }

    Thruk::Utils::ssi_include($c, 'user');

    $c->stash->{profile_user}    = $c->user;
    $c->stash->{api_keys}        = Thruk::Utils::APIKeys::get_keys($c, { user => $c->stash->{'remote_user'}});
    $c->stash->{superuser_keys}  = $c->check_user_roles('admin') ? Thruk::Utils::APIKeys::get_superuser_keys($c) : [];
    $c->stash->{available_roles} = $Thruk::Authentication::User::possible_roles;
    $c->stash->{template}        = 'user_profile.tt';

    return 1;
}

##########################################################

1;
