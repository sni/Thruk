package Thruk::Controller::Root;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Data::Dumper;
use URI::Escape qw/uri_escape/;
use File::Slurp;
use JSON::XS;
use POSIX qw/strftime/;
use Thruk::Utils::Filter;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

Thruk::Controller::Root - Root Controller for Thruk

=head1 DESCRIPTION

Root Controller of the Thruk Monitoring Webinterface

=head1 METHODS

=cut

######################################

=head2 begin

sets the doc link and decides if frames are used
begin, running at the begin of every req

=cut

sub begin : Private {
    my( $self, $c ) = @_;

    # make some configs available in stash
    for my $key (qw/url_prefix title_prefix use_pager start_page documentation_link
                  use_feature_statusmap use_feature_statuswrl use_feature_histogram use_feature_configtool
                  datetime_format datetime_format_today datetime_format_long datetime_format_log
                  use_new_search ajax_search show_notification_number strict_passive_mode hide_passive_icon
                  show_full_commandline all_problems_link use_ajax_search show_long_plugin_output
                  priorities show_modified_attributes downtime_duration expire_ack_duration
                  show_backends_in_table host_action_icon service_action_icon cookie_path
                  use_feature_trends show_error_reports skip_js_errors perf_bar_mode
                  bug_email_rcpt home_link first_day_of_week sitepanel perf_bar_pnp_popup
                  status_color_background show_logout_button use_feature_recurring_downtime
                  use_service_description
                /) {
        $c->stash->{$key} = $c->config->{$key};
    }

    # user data
    $c->stash->{'user_data'} = { bookmarks => {} };

    # frame options
    my $use_frames = $c->config->{'use_frames'};
    my $show_nav_button = 1;
    if( exists $c->{'request'}->{'parameters'}->{'nav'} and $c->{'request'}->{'parameters'}->{'nav'} ne '' ) {
        if( $c->{'request'}->{'parameters'}->{'nav'} ne '1' ) {
            $show_nav_button = 1;
        }
        $use_frames = 1;
        if( $c->{'request'}->{'parameters'}->{'nav'} eq '1' ) {
            $use_frames = 0;
        }
    }
    if( $c->config->{'use_frames'} == 1 ) {
        $show_nav_button = 0;
    }
    $c->stash->{'use_frames'}         = $use_frames;
    $c->stash->{'show_nav_button'}    = $show_nav_button;
    $c->stash->{'reload_nav'}         = $c->{'request'}->{'parameters'}->{'reload_nav'} || '';
    $c->stash->{'show_sounds'}        = 0;

    # use pager?
    Thruk::Utils::set_paging_steps($c, $c->config->{'paging_steps'});

    # which theme?
    my($param_theme, $cookie_theme);
    if( $c->{'request'}->{'parameters'}->{'theme'} ) {
        $param_theme = $c->{'request'}->{'parameters'}->{'theme'};
    }
    elsif( defined $c->request->cookie('thruk_theme') ) {
        my $theme_cookie = $c->request->cookie('thruk_theme');
        $cookie_theme = $theme_cookie->value if defined $theme_cookie->value and grep $theme_cookie->value, $c->config->{'themes'};
    }
    my $theme = $param_theme || $cookie_theme || $c->config->{'default_theme'};
    my $available_themes = Thruk::Utils::array2hash($c->config->{'View::TT'}->{'PRE_DEFINE'}->{'themes'});
    $theme = $c->config->{'default_theme'} unless defined $available_themes->{$theme};
    $c->stash->{'theme'} = $theme;
    if( defined $c->config->{templates_paths} ) {
        # themes have to override plugins templates
        $c->stash->{additional_template_paths} = [ $c->config->{themes_path}.'/themes-enabled/'.$theme.'/templates', @{ $c->config->{templates_paths} } ];
    }
    else {
        $c->stash->{additional_template_paths} = [ $c->config->{themes_path}.'/themes-enabled/'.$theme.'/templates' ];
    }
    $c->stash->{all_in_one_css} = 0;
    if($theme eq 'Thruk') {
        $c->stash->{all_in_one_css} = 1;
    }

    if(exists $c->{'request'}->{'parameters'}->{'noheader'}) {
        $c->{'request'}->{'parameters'}->{'hidetop'}  = 1;
    }
    $c->stash->{hidetop} = $c->{'request'}->{'parameters'}->{'hidetop'} || '';

    # minmal custom monitor screen
    $c->stash->{minimal}               = $c->{'request'}->{'parameters'}->{'minimal'} || '';
    $c->stash->{show_nav_button}       = 0 if $c->stash->{minimal};

    # initialize our backends
    unless ( defined $c->{'db'} ) {
        $c->{'db'} = $c->model('Thruk');
        if( defined $c->{'db'} ) {
            $c->{'db'}->init(
                'backend_debug' => $c->config->{'backend_debug'},
            );
        }
    }
    # needed for the autoload methods
    $Thruk::Backend::Manager::c     = $c;

    # menu cookie set?
    my $menu_states = {};
    for my $key (keys %{$c->config->{'initial_menu_state'}}) {
        my $val = $c->config->{'initial_menu_state'}->{$key};
        $key = lc $key;
        $key =~ s/\ /_/gmx;
        $menu_states->{$key} = $val;
    }
    if( defined $c->request->cookie('thruk_side') ) {
        my $cookie_val = $c->request->cookie('thruk_side')->{'value'};
        if(ref $cookie_val ne 'ARRAY') { $cookie_val = [$cookie_val]; }
        for my $state (@{$cookie_val}) {
            my($k,$v) = split(/=/mx,$state,2);
            $k = lc $k;
            $k =~ s/\ /_/gmx;
            $menu_states->{$k} = $v;
        }
    }

    $c->stash->{'menu_states'}      = $menu_states;
    $c->stash->{'menu_states_json'} = encode_json($menu_states);

    my $target = $c->{'request'}->{'parameters'}->{'target'};
    if( !$c->stash->{'use_frames'} and defined $target and $target eq '_parent' ) {
        $c->stash->{'target'} = '_parent';
    }

    # redirect to error page unless we have a connection
    if(    !defined $c->{'db'}
        or !defined $c->{'db'}->{'backends'}
        or ref $c->{'db'}->{'backends'} ne 'ARRAY'
        or scalar @{$c->{'db'}->{'backends'}} == 0 ) {

        # return here for static content, no backend needed
        if(   $c->request->action =~ m|thruk/\w+\.html|mx
           or $c->request->action =~ m|thruk\/\w+\.html|mx
           or $c->request->action =~ m|thruk\/cgi\-bin\/conf\.cgi\?sub=backends|mx
           or $c->request->action =~ m|thruk\/cgi\-bin\/remote\.cgi|mx
           or $c->request->action =~ m|thruk\/cgi\-bin\/login\.cgi|mx
           or $c->request->action =~ m|thruk\/cgi\-bin\/restricted\.cgi|mx
           or $c->request->action =~ m|^/$|mx
           or $c->request->action eq 'thruk$'
           or $c->request->action eq 'thruk\\/docs\\/' ) {
            $c->stash->{'no_auto_reload'} = 1;
            return;
        }
        # redirect to backends manager if admin user
        if( $c->config->{'use_feature_configtool'} ) {
            $c->{'request'}->{'parameters'}->{'sub'} = 'backends';
            return $c->detach('/conf/index');
        } else {
            return $c->detach("/error/index/14");
        }
    }

    # set check_local_states
    unless(defined $c->config->{'check_local_states'}) {
        $c->config->{'check_local_states'} = 0;
        if(scalar @{$c->{'db'}->{'backends'}} > 1) {
            $c->config->{'check_local_states'} = 1;
        }
    }

    # when adding nav=1 to a url in frame mode, redirect to frame.html with this url
    if( defined $c->{'request'}->{'parameters'}->{'nav'}
            and $c->{'request'}->{'parameters'}->{'nav'} eq '1'
            and $c->config->{'use_frames'} == 1 ) {
        my $path = $c->request->uri->path_query;
        $path =~ s/nav=1//gmx;
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/frame.html?link=".uri_escape($path));
    }

    # icon image path
    $c->config->{'logo_path_prefix'} = exists $c->config->{'logo_path_prefix'} ? $c->config->{'logo_path_prefix'} : $c->stash->{'url_prefix'}.'thruk/themes/'.$c->stash->{'theme'}.'/images/logos/';
    $c->stash->{'logo_path_prefix'}  = $c->config->{'logo_path_prefix'};

    # additional views on status pages
    $c->stash->{'additional_views'} = $Thruk::Utils::Status::additional_views || {};

    # sound cookie set?
    if(defined $c->request->cookie('thruk_sounds')) {
        my $sound_cookie = $c->request->cookie('thruk_sounds');
        if(defined $sound_cookie->value and $sound_cookie->value eq 'off') {
            $c->stash->{'play_sounds'} = 0;
        }
        if(defined $sound_cookie->value and $sound_cookie->value eq 'on') {
            $c->stash->{'play_sounds'} = 1;
        }
    }

    # favicon cookie set?
    if(defined $c->request->cookie('thruk_favicon')) {
        my $favicon_cookie = $c->request->cookie('thruk_favicon');
        if(defined $favicon_cookie->value and $favicon_cookie->value eq 'off') {
            $c->stash->{'fav_counter'} = 0;
        }
        if(defined $favicon_cookie->value and $favicon_cookie->value eq 'on') {
            $c->stash->{'fav_counter'} = 1;
        }
    }

    if( defined $c->request->cookie('thruk_auth') ) {
        $c->stash->{'cookie_auth'} = 1;
    }

    # make private _ hash keys available
    $Template::Stash::PRIVATE = undef;

    return 1;
}

######################################

=head2 default

show our 404 error page

=cut

sub default : Path {
    my( $self, $c ) = @_;
    $c->response->body('Page not found');
    return $c->response->status(404);
}

######################################

=head2 index

redirect from /

=cut

sub index : Path('/') {
    my( $self, $c ) = @_;
    if( scalar @{ $c->request->args } > 0 and $c->request->args->[0] ne 'index.html' ) {
        return $c->detach("default");
    }
    return $c->response->redirect($c->stash->{'url_prefix'}."thruk/");
}

######################################

=head2 index_html

redirect from /index.html

because we dont want index.html in the url

=cut

sub index_html : Path('/index.html') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."thruk/cgi-bin/mobile.cgi");
    if( $c->stash->{'use_frames'} ) {
        return $c->detach("thruk_index_html");
    }
    else {
        return $c->detach("thruk_main_html");
    }
}

######################################

=head2 thruk_index

redirect from /thruk/
but if used not via fastcgi/apache, there is no way around

=cut

sub thruk_index : Path('/thruk/') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."thruk/cgi-bin/mobile.cgi");
    if( scalar @{ $c->request->args } > 0 and $c->request->args->[0] ne 'index.html' ) {
        return $c->detach("default");
    }

    # redirect from /thruk to /thruk/
    if($c->request->path eq 'thruk') {
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/");
    }

    if( $c->stash->{'use_frames'} and !$c->stash->{'show_nav_button'} ) {
        return $c->detach("thruk_index_html");
    }

    # custom start page?
    $c->stash->{'start_page'} = $c->stash->{'url_prefix'}.'thruk/main.html' unless defined $c->stash->{'start_page'};
    if( CORE::index($c->stash->{'start_page'}, $c->stash->{'url_prefix'}.'thruk/') != 0 ) {

        # external link, put in frames
        my $start_page = uri_escape( $c->stash->{'start_page'} );
        $c->log->debug( "redirecting to framed start page: '".$c->stash->{'url_prefix'}."thruk/frame.html?link=" . $start_page . "'" );
        return $c->response->redirect( $c->stash->{'url_prefix'}."thruk/frame.html?link=" . $start_page );
    }
    elsif ( $c->stash->{'start_page'} ne $c->stash->{'url_prefix'}.'thruk/main.html' ) {

        # internal link, no need to put in frames
        $c->log->debug( "redirecting to default start page: '" . $c->stash->{'start_page'} . "'" );
        return $c->response->redirect( $c->stash->{'start_page'} );
    }

    return $c->detach("thruk_main_html");
}

######################################

=head2 thruk_index_html

page: /thruk/index.html

=cut

sub thruk_index_html : Path('/thruk/index.html') :MyAction('AddSafeDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."thruk/cgi-bin/mobile.cgi");
    unless ( $c->stash->{'use_frames'} ) {
        return $c->detach("thruk_main_html");
    }

    $c->stash->{'title'}          = $c->config->{'name'};
    $c->stash->{'main'}           = '';
    $c->stash->{'target'}         = '';
    $c->stash->{'template'}       = 'index.tt';
    $c->stash->{'no_auto_reload'} = 1;

    return 1;
}

######################################

=head2 thruk_side_html

page: /thruk/side.html

=cut

sub thruk_side_html : Path('/thruk/side.html') :MyAction('AddSafeDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    Thruk::Utils::check_pid_file($c);
    Thruk::Utils::Menu::read_navigation($c) unless defined $c->stash->{'navigation'} and $c->stash->{'navigation'} ne '';

    $c->stash->{'use_frames'}     = 1;
    $c->stash->{'title'}          = $c->config->{'name'};
    $c->stash->{'template'}       = 'side.tt';
    $c->stash->{'no_auto_reload'} = 1;

    return 1;
}

######################################

=head2 thruk_frame_html

page: /thruk/frame.html
# creates frame for external pages

=cut

sub thruk_frame_html : Path('/thruk/frame.html') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    # allowed links to be framed
    my $valid_links = [ quotemeta( $c->stash->{'url_prefix'}."thruk/cgi-bin" ), quotemeta( $c->stash->{'documentation_link'} ), quotemeta( $c->stash->{'start_page'} ), ];
    my $additional_links = $c->config->{'allowed_frame_links'};
    if( defined $additional_links ) {
        if( ref $additional_links eq 'ARRAY' ) {
            $valid_links = [ @{$valid_links}, @{$additional_links} ];
        }
        else {
            $valid_links = [ @{$valid_links}, $additional_links ];
        }
    }

    # check if any of the allowed links match
    my $link = $c->{'request'}->{'parameters'}->{'link'};
    if( defined $link ) {
        for my $pattern ( @{$valid_links} ) {
            if( $link =~ m/$pattern/mx ) {
                if($c->stash->{'use_frames'}) {
                    return $c->response->redirect($c->stash->{'url_prefix'}."thruk/#".$link);
                }
                $c->stash->{'target'}   = '_parent';
                $c->stash->{'main'}     = $link;
                $c->stash->{'title'}    = $c->config->{'name'};
                $c->stash->{'template'} = 'index.tt';

                return 1;
            }
        }
    }

    $c->stash->{'no_auto_reload'} = 1;

    # no link or none matched, display the usual index.html
    return $c->detach("thruk_index_html");
}

######################################

=head2 thruk_main_html

page: /thruk/main.html

=cut

sub thruk_main_html : Path('/thruk/main.html') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};

    # add defaults when not using frames, otherwise the menu would be incomplete
    if(!defined $c->stash->{'defaults_added'} and !$c->stash->{'use_frames'}) {
        Thruk::Action::AddDefaults::add_defaults(0, undef, $self, $c);
    }

    $c->stash->{'title'}                   = 'Thruk Monitoring Webinterface';
    $c->stash->{'page'}                    = 'splashpage';
    $c->stash->{'template'}                = 'main.tt';
    $c->stash->{'hide_backends_chooser'}   = 1;
    $c->stash->{'no_auto_reload'}          = 1;
    $c->stash->{'enable_shinken_features'} = 0;

    return 1;
}

######################################

=head2 thruk_changes_html

page: /thruk/changes.html

=cut

sub thruk_changes_html : Path('/thruk/changes.html') :MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    $c->stash->{infoBoxTitle}            = 'Change Log';
    $c->stash->{'title'}                 = 'Change Log';
    $c->stash->{'no_auto_reload'}        = 1;
    $c->stash->{'hide_backends_chooser'} = 1;
    $c->stash->{'template'}              = 'changes.tt';
    $c->stash->{page}                    = 'splashpage';

    return 1;
}

######################################

=head2 thruk_docs

page: /thruk/docs/

=cut

sub thruk_docs : Path('/thruk/docs/') :MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    if( scalar @{ $c->request->args } > 0 and $c->request->args->[0] ne 'index.html' ) {
        return $c->detach("default");
    }

    $c->stash->{infoBoxTitle}            = 'Documentation';
    $c->stash->{'title'}                 = 'Documentation';
    $c->stash->{'no_auto_reload'}        = 1;
    $c->stash->{'hide_backends_chooser'} = 1;
    $c->stash->{'template'}              = 'docs.tt';
    $c->stash->{'extrabodyclass'}        = 'docs';
    $c->stash->{'page'}                  = 'splashpage';

    return 1;
}

######################################

=head2 tac_cgi

page: /thruk/cgi-bin/tac.cgi

=cut

sub tac_cgi : Path('/thruk/cgi-bin/tac.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/tac/index');
}

######################################

=head2 status_cgi

page: /thruk/cgi-bin/status.cgi

=cut

sub status_cgi : Path('/thruk/cgi-bin/status.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/status/index');
}

######################################

=head2 cmd_cgi

page: /thruk/cgi-bin/cmd.cgi

=cut

sub cmd_cgi : Path('/thruk/cgi-bin/cmd.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/cmd/index');
}

######################################

=head2 outages_cgi

page: /thruk/cgi-bin/outages.cgi

=cut

sub outages_cgi : Path('/thruk/cgi-bin/outages.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/outages/index');
}

######################################

=head2 avail_cgi

page: /thruk/cgi-bin/avail.cgi

=cut

sub avail_cgi : Path('/thruk/cgi-bin/avail.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/avail/index');
}

######################################

=head2 trends_cgi

page: /thruk/cgi-bin/trends.cgi

=cut

sub trends_cgi : Path('/thruk/cgi-bin/trends.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/trends/index');
}

######################################

=head2 history_cgi

page: /thruk/cgi-bin/history.cgi

=cut

sub history_cgi : Path('/thruk/cgi-bin/history.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/history/index');
}

######################################

=head2 summary_cgi

page: /thruk/cgi-bin/summary.cgi

=cut

sub summary_cgi : Path('/thruk/cgi-bin/summary.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/summary/index');
}

######################################

=head2 histogram_cgi

page: /thruk/cgi-bin/histogram.cgi

=cut

sub histogram_cgi : Path('/thruk/cgi-bin/histogram.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/histogram/index');
}

######################################

=head2 notifications_cgi

page: /thruk/cgi-bin/notifications.cgi

=cut

sub notifications_cgi : Path('/thruk/cgi-bin/notifications.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/notifications/index');
}

######################################

=head2 showlog_cgi

page: /thruk/cgi-bin/showlog.cgi

=cut

sub showlog_cgi : Path('/thruk/cgi-bin/showlog.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/showlog/index');
}

######################################

=head2 extinfo_cgi

page: /thruk/cgi-bin/extinfo.cgi

=cut

sub extinfo_cgi : Path('/thruk/cgi-bin/extinfo.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/extinfo/index');
}

######################################

=head2 config_cgi

page: /thruk/cgi-bin/config.cgi

=cut

sub config_cgi : Path('/thruk/cgi-bin/config.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/config/index');
}

######################################

=head2 job_cgi

page: /thruk/cgi-bin/job.cgi

=cut

sub job_cgi : Path('/thruk/cgi-bin/job.cgi') :MyAction('AddSafeDefaults') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};

    return Thruk::Utils::External::job_page($c);
}

######################################

=head2 test_cgi

page: /thruk/cgi-bin/test.cgi

=cut

sub test_cgi : Path('/thruk/cgi-bin/test.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/test/index');
}

######################################

=head2 end

check and display errors (if any)

=cut

sub end : ActionClass('RenderView') {
    my( $self, $c ) = @_;

    Thruk::Utils::Menu::read_navigation($c) unless defined $c->stash->{'navigation'} and $c->stash->{'navigation'} ne '';

    my @errors = @{ $c->error };
    if( scalar @errors > 0 ) {
        for my $error (@errors) {
            $c->log->error($error);
        }
        return $c->detach('/error/index/13');
    }

    if($c->stash->{'debug_info'}) {
        # save debug info into tmp file
        my $tmp = $c->config->{'tmp_path'}.'/debug';
        Thruk::Utils::IO::mkdir_r($tmp);
        my $tmpfile = $tmp.'/'.strftime('%Y-%m-%d_%H_%M_%S', localtime).'.log';
        open(my $fh, '>', $tmpfile);
        print $fh 'Uri: '.Thruk::Utils::Filter::full_uri($c)."\n";
        print $fh "*************************************\n";
        print $fh "version: ".Thruk::Utils::Filter::fullversion($c)."\n";
        print $fh "parameters:\n";
        print $fh Dumper($c->{'request'}->{'parameters'});
        print $fh "debug info:\n";
        print $fh Thruk::Utils::get_debug_details();
        if($c->stash->{'original_url'}) {
            print $fh "*************************************\n";
            print $fh "job:\n";
            print $fh 'Uri: '.$c->stash->{'original_url'}."\n";
        }
        print $fh "*************************************\n";
        print $fh "\n";
        print $fh $c->stash->{'debug_info'};
        Thruk::Utils::IO::close($fh, $tmpfile);
        Thruk::Utils::set_message( $c, 'success_message fixed', 'Debug Information written to: '.$tmpfile );
    }

    if($ENV{THRUK_LEAK_CHECK}) {
        eval {
            $c->config->{'requests'} = 0 unless defined $c->config->{'requests'};
            $c->config->{'requests'}++;

            require Devel::Gladiator;
            Devel::Gladiator->import(qw(arena_ref_counts));
            my $refs = arena_ref_counts();
            if($c->config->{'arena'}) {
                my $res = {};
                for my $key (keys %{$refs}) {
                    $c->config->{'arena'}->{$key} = 0 unless defined $c->config->{'arena'}->{$key};
                    if($c->config->{'arena'}->{$key} > 0 and $c->config->{'arena'}->{$key} < $refs->{$key}) {
                        $res->{$key} = $refs->{$key} - $c->config->{'arena'}->{$key};
                    }
                }
                # there will be new scalars from time to time
                delete $res->{'SCALAR'} if $res->{'SCALAR'} and $res->{'SCALAR'} < 10;
                if($c->config->{'requests'} > 2 && scalar keys %{$res} > 0) {
                    print STDERR "request: ".$c->config->{'requests'}." (".$c->request->path."):\n";
                    for my $key (sort { ($res->{$b} <=> $res->{$a}) } keys %{$res}) {
                        printf(STDERR "+%-10i %30s  -  total %10i\n", $res->{$key}, $key, $c->config->{'arena'}->{$key});
                    }
                }
            }
            for my $key (keys %{$refs}) {
                if(!$c->config->{'arena'}->{$key} || $c->config->{'arena'}->{$key} < $refs->{$key}) {
                    $c->config->{'arena'}->{$key} = $refs->{$key}
                }
            }
        };
    }

    return 1;
}

######################################

=head1 AUTHOR

Sven Nierlein, 2009-2013, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
