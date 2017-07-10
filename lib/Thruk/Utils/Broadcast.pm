package Thruk::Utils::Broadcast;

=head1 NAME

Thruk::Utils::Broadcast - Broadcast Utilities Collection for Thruk

=head1 DESCRIPTION

Broadcast Utilities Collection for Thruk

=cut

use strict;
use warnings;

##############################################

=head1 METHODS

=head2 get_broadcasts($c, [$unfiltered], [$file])

  get_broadcasts($c, [$unfiltered], [$file])

return list of broadcasts for this contact

=cut
sub get_broadcasts {
    my($c, $unfiltered, $filefilter) = @_;
    my $list = [];

    my $now    = time();
    my $groups = {};
    if($c->stash->{'remote_user'}) {
        $groups = $c->cache->get->{'users'}->{$c->stash->{'remote_user'}}->{'contactgroups'};
    }
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
            $c->log->error("could not read broadcast file $file: ".$@);
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

        my $contacts           = [grep(!/^\!/mx, @{$broadcast->{'contacts'}})];
        my $contactgroups      = [grep(!/^\!/mx, @{$broadcast->{'contactgroups'}})];

        if(!$unfiltered && (scalar @{$contacts} > 0 || scalar @{$contactgroups} > 0)) {
            my $allowed = 0;
            # allowed for specific contacts
            if(scalar @{$contacts}) {
                my $contacts = Thruk::Utils::array2hash($contacts);
                if($contacts->{$c->stash->{'remote_user'}}) {
                    $allowed = 1;
                    last;
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
            next if(!$allowed && !$unfiltered);
        }

        # hide from certain contacts or groups by exclamation mark
        if(!$unfiltered) {
            my $contacts_hide      = [grep(/^\!/mx, @{$broadcast->{'contacts'}})];
            if(scalar @{$contacts_hide}) {
                my $contacts = Thruk::Utils::array2hash($contacts_hide);
                if($contacts->{$c->stash->{'remote_user'}}) {
                    next;
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
                next if $hidden;
            }
        }

        # date / time filter
        $broadcast->{'expires_ts'} = 0;
        if($broadcast->{'expires'}) {
            my $expires_ts = Thruk::Utils::_parse_date($c, $broadcast->{'expires'});
            $broadcast->{'expires_ts'} = $expires_ts;
            if($now > $expires_ts) {
                next unless $unfiltered;
            }
        }

        $broadcast->{'hide_before_ts'} = 0;
        if($broadcast->{'hide_before'}) {
            my $hide_before_ts = Thruk::Utils::_parse_date($c, $broadcast->{'hide_before'});
            $broadcast->{'hide_before_ts'} = $hide_before_ts;
            if($now < $hide_before_ts) {
                next unless $unfiltered;
            }
        }

        $broadcast->{'new'} = 0;
        if(!$unfiltered && !defined $already_read->{$basename}) {
            $broadcast->{'new'} = 1;
            $new_count++;
        }

        $broadcast->{'author'}      = $broadcast->{'author'}        // 'none';
        $broadcast->{'expires'}     = $broadcast->{'expires'}       // '';
        $broadcast->{'hide_before'} = $broadcast->{'hide_before'}   // '';

        push @{$list}, $broadcast;
    }

    return([]) if($new_count == 0 && !$unfiltered);

    # sort by read status and filename
    @{$list} = sort { $b->{'new'} <=> $a->{'new'} || $b->{'basefile'} cmp $a->{'basefile'} } @{$list};

    return($list);
}

########################################

=head2 update_dismiss($c)

  update_dismiss($c)

mark all broadcasts as read for the current user

=cut
sub update_dismiss {
    my($c) = @_;

    my $now = time();
    my $broadcasts = get_broadcasts($c);
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
        text            => '',
        expires         => '',
        hide_before     => '',
        contacts        => [],
        contactgroups   => [],
    };
    return($broadcast);
}

########################################

1;

__END__

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
