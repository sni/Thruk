package Thruk::Utils::Broadcast;

=head1 NAME

Thruk::Utils::Broadcast - Broadcast Utilities Collection for Thruk

=head1 DESCRIPTION

Broadcast Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 get_broadcasts

  get_broadcasts($c, [$unfiltered], [$file], [$panorama_only], [$templates_only])

return list of broadcasts for this contact

=cut
sub get_broadcasts {
    my($c, $unfiltered, $filefilter, $panorama_only, $templates_only) = @_;
    my $list = [];

    my $now    = time();
    my @files  = glob($c->config->{'var_path'}.'/broadcast/*.json');
    return([]) unless scalar @files > 0;

    my $user_data = Thruk::Utils::get_user_data($c);
    my $already_read = {};
    if($user_data->{'broadcast'} && $user_data->{'broadcast'}->{'read'}) {
        $already_read = $user_data->{'broadcast'}->{'read'};
    }

    my $new_count = 0;
    for my $file (@files) {
        my $broadcast;
        eval {
            $broadcast = Thruk::Utils::IO::json_lock_retrieve($file);
        };
        if($@) {
            _error("could not read broadcast file $file: ".$@);
            next;
        }

        $broadcast->{'file'} = $file;
        my $basename = $file;
        $basename =~ s%.*?([^/]+\.json)$%$1%mx;
        $broadcast->{'basefile'} = $basename;
        next if $filefilter && $basename ne $filefilter;

        if(!$c->stash->{'remote_user'} && !$broadcast->{'loginpage'}) {
            next;
        }

        $broadcast->{'contacts'}      = Thruk::Utils::list($broadcast->{'contacts'});
        $broadcast->{'contactgroups'} = Thruk::Utils::list($broadcast->{'contactgroups'});

        if(!$unfiltered) {
            next unless is_authorized_for_broadcast($c, $broadcast);
        }

        process_broadcast($c, $broadcast);

        if($broadcast->{'expires'} && $now > $broadcast->{'expires_ts'}) {
            next unless $unfiltered;
        }
        if($broadcast->{'hide_before'} && $now < $broadcast->{'hide_before_ts'}) {
            next unless $unfiltered;
        }

        next if($panorama_only && !$broadcast->{'panorama'});
        next if(!$unfiltered && $broadcast->{'template'});
        next if($templates_only && !$broadcast->{'template'});

        $broadcast->{'new'} = 0;
        if(!$unfiltered && !defined $already_read->{$basename}) {
            $broadcast->{'new'} = 1;
            $new_count++;
        }

        push @{$list}, $broadcast;
    }

    return([]) if($new_count == 0 && !$unfiltered);

    # sort by read status and filename
    @{$list} = sort { $b->{'new'} <=> $a->{'new'} || $b->{'basefile'} cmp $a->{'basefile'} } @{$list};

    return($list);
}

########################################

=head2 process_broadcast($c, $broadcast)

  process_broadcast($c, $broadcast)

replace macros, frontmatter, etc...

=cut
sub process_broadcast {
    my($c, $broadcast) = @_;

    # date / time filter
    $broadcast->{'expires_ts'} = 0;
    if($broadcast->{'expires'}) {
        my $expires_ts = Thruk::Utils::parse_date($c, $broadcast->{'expires'});
        $broadcast->{'expires_ts'} = $expires_ts;
    }

    $broadcast->{'hide_before_ts'} = 0;
    if($broadcast->{'hide_before'}) {
        my $hide_before_ts = Thruk::Utils::parse_date($c, $broadcast->{'hide_before'});
        $broadcast->{'hide_before_ts'} = $hide_before_ts;
    }

    $broadcast->{'name'}        = $broadcast->{'name'}          // '';
    $broadcast->{'text'}        = $broadcast->{'text'}          // '';
    $broadcast->{'author'}      = $broadcast->{'author'}        // 'none';
    $broadcast->{'authoremail'} = $broadcast->{'authoremail'}   // 'none';
    $broadcast->{'expires'}     = $broadcast->{'expires'}       // '';
    $broadcast->{'hide_before'} = $broadcast->{'hide_before'}   // '';
    $broadcast->{'loginpage'}   = $broadcast->{'loginpage'}     // 0;
    $broadcast->{'panorama'}    = $broadcast->{'panorama'}      // 0;
    $broadcast->{'annotation'}  = $broadcast->{'annotation'}    // '';
    $broadcast->{'template'}    = $broadcast->{'template'}      // 0;
    $broadcast->{'macros'}      = {
        date         => Thruk::Utils::Filter::date_format($c, (stat($broadcast->{'file'}))[9]),
        contact      => $broadcast->{'author'},
        contactemail => $broadcast->{'authoremail'},
        theme        => $c->stash->{'theme'},
    };
    _set_macros($c, $broadcast);
    _extract_front_matter_macros($broadcast);

    # merge frontmatter intro macros
    $broadcast->{'macros'} = {%{$broadcast->{'macros'}}, %{$broadcast->{'frontmatter'}}};

    return;
}

########################################

=head2 is_authorized_for_broadcast($c, $broadcast)

  is_authorized_for_broadcast($c, $broadcast)

returns true if user is allowed to view this broadcast

=cut
sub is_authorized_for_broadcast {
    my($c, $broadcast) = @_;

    my $contacts           = [grep(!/^\!/mx, @{$broadcast->{'contacts'}})];
    my $contactgroups      = [grep(!/^\!/mx, @{$broadcast->{'contactgroups'}})];

    my $groups = {};
    if($c->user_exists) {
        $groups = Thruk::Utils::array2hash($c->user->{'groups'});
    }

    if(scalar @{$contacts} > 0 || scalar @{$contactgroups} > 0) {
        my $allowed = 0;
        # allowed for specific contacts
        if(scalar @{$contacts}) {
            my $contacts = Thruk::Utils::array2hash($contacts);
            if($c->stash->{'remote_user'} && $contacts->{$c->stash->{'remote_user'}}) {
                $allowed = 1;
            }
        }
        # allowed for specific contactgroups
        if(scalar @{$contactgroups}) {
            my $contactgroups = Thruk::Utils::array2hash($contactgroups);
            for my $group (keys %{$groups}) {
                if($contactgroups->{$group}) {
                    $allowed = 1;
                    last;
                }
            }
        }
        return unless $allowed;
    }

    # hide from certain contacts or groups by exclamation mark
    my $contacts_hide      = [grep(/^\!/mx, @{$broadcast->{'contacts'}})];
    if(scalar @{$contacts_hide}) {
        my $contacts = Thruk::Utils::array2hash($contacts_hide);
        if($contacts->{$c->stash->{'remote_user'}}) {
            return;
        }
    }
    my $contactgroups_hide = [grep(/^\!/mx, @{$broadcast->{'contactgroups'}})];
    if(scalar @{$contactgroups_hide}) {
        my $contactgroups = Thruk::Utils::array2hash($contactgroups_hide);
        my $hidden = 0;
        for my $group (keys %{$groups}) {
            if($contactgroups->{$group}) {
                $hidden = 1;
                last;
            }
        }
        return if $hidden;
    }
    return 1;
}

########################################

=head2 update_dismiss($c)

  update_dismiss($c)

mark all broadcasts as read for the current user

=cut
sub update_dismiss {
    my($c, $panorama_only) = @_;

    my $now = time();
    my $broadcasts = get_broadcasts($c, undef, undef, $panorama_only);
    my $data = Thruk::Utils::get_user_data($c);
    $data->{'broadcast'}->{'read'} = {} unless $data->{'broadcast'}->{'read'};

    # set current date for all broadcasts
    for my $b (@{$broadcasts}) {
        $data->{'broadcast'}->{'read'}->{$b->{'basefile'}} = $now unless $data->{'broadcast'}->{'read'}->{$b->{'basefile'}};
    }

    # remove old marks for non-existing files (with a 10 day delay)
    my $clean_delay = $now - (86400 * 10);
    for my $file (keys %{$data->{'broadcast'}->{'read'}}) {
        my $ts = $data->{'broadcast'}->{'read'}->{$file};
        if(!-e $c->config->{'var_path'}.'/broadcast/'.$file && $ts < $clean_delay) {
            delete $data->{'broadcast'}->{'read'}->{$file};
        }
    }

    Thruk::Utils::store_user_data($c, $data);
    return;
}

########################################

=head2 get_default_broadcast($c)

  get_default_broadcast($c)

return empty default broadcast

=cut
sub get_default_broadcast {
    my($c) = @_;
    my $broadcast = {
        author          => $c->stash->{'remote_user'},
        id              => 'new',
        name            => '',
        text            => '',
        raw_text        => '',
        expires         => '',
        hide_before     => '',
        contacts        => [],
        contactgroups   => [],
        annotation      => '',
        loginpage       => 0,
        panorama        => 1,
        template        => 0,
        frontmatter     => {},
        macros          => {
            date         => Thruk::Utils::Filter::date_format($c, time()),
            contact      => $c->stash->{'remote_user'},
            contactemail => $c->user ? $c->user->{'email'} : 'none',
            theme        => $c->stash->{'theme'},
        },
    };
    return($broadcast);
}

########################################
sub _set_macros {
    my($c, $b) = @_;
    $b->{'macros'}      = {
        date         => Thruk::Utils::Filter::date_format($c, (stat($b->{'file'}))[9]),
        contact      => $b->{'author'},
        contactemail => $b->{'authoremail'},
        theme        => $c->stash->{'theme'},
        name         => $b->{'name'},
        title        => $b->{'name'},
    };
    return;
}

########################################
sub _extract_front_matter_macros {
    my($b) = @_;
    $b->{'raw_text'}    = $b->{'text'} unless $b->{'raw_text'};
    $b->{'frontmatter'} = {}           unless $b->{'frontmatter'};
    my($tmp, $frontmatter, $text) = split(/^\s*\-\-\-\s*$/mx, $b->{'text'}, 3);
    if($tmp || !$frontmatter) {
        return;
    }
    $b->{'text'} = $text;
    $b->{'text'} =~ s/^\s+//gmx;
    for my $line (split(/\n+/mx, $frontmatter)) {
        my($key, $val) = split(/:/mx, $line, 2);
        next unless $key;
        $key =~ s/^\s+//gmx;
        $key =~ s/\s+$//gmx;
        if($val) {
            $val =~ s/^\s+//gmx;
            $val =~ s/\s+$//gmx;
        }
        $b->{'frontmatter'}->{$key} = $val;
    }
    return;
}

##########################################################

=head2 update_broadcast_from_param($c, $broadcast)

  update_broadcast_from_param($c, $broadcast)

return broadcast with updated fields from parameters

=cut
sub update_broadcast_from_param {
    my($c, $broadcast) = @_;
    $broadcast->{'name'}          = $c->req->parameters->{'name'};
    $broadcast->{'author'}        = $c->stash->{'remote_user'};
    $broadcast->{'authoremail'}   = $c->user ? $c->user->{'email'} : 'none';
    $broadcast->{'contacts'}      = Thruk::Utils::extract_list($c->req->parameters->{'contacts'}, '/\s*,\s*/mx');
    $broadcast->{'contactgroups'} = Thruk::Utils::extract_list($c->req->parameters->{'contactgroups'}, '/\s*,\s*/mx');
    $broadcast->{'text'}          = $c->req->parameters->{'text'};
    $broadcast->{'expires'}       = $c->req->parameters->{'expires'} || '';
    $broadcast->{'hide_before'}   = $c->req->parameters->{'hide_before'} || '';
    $broadcast->{'loginpage'}     = $c->req->parameters->{'loginpage'} || 0;
    $broadcast->{'annotation'}    = $c->req->parameters->{'annotation'} || '';
    $broadcast->{'panorama'}      = $c->req->parameters->{'panorama'} || 0;
    $broadcast->{'template'}      = $c->req->parameters->{'template'} || 0;
    delete $broadcast->{'macros'};
    delete $broadcast->{'frontmatter'};
    delete $broadcast->{'expires_ts'};
    delete $broadcast->{'hide_before_ts'};
    if($broadcast->{'raw_text'}) {
        $broadcast->{'text'} = $broadcast->{'raw_text'};
        delete $broadcast->{'raw_text'};
    }
    return($broadcast);
}

########################################

1;
