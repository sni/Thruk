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

=head2 get_broadcasts($c)

  get_broadcasts($c)

return list of broadcasts for this contact

=cut
sub get_broadcasts {
    my($c) = @_;
    my $list = [];

    my $now       = time();
    my $groups    = $c->cache->get->{'users'}->{$c->stash->{'remote_user'}}->{'contactgroups'};
    for my $file (reverse sort glob($c->config->{'var_path'}.'/broadcast/*.json')) {
        my $broadcast = Thruk::Utils::read_data_file($file);
        $broadcast->{'file'} = $file;
        my $basename = $file;
        $basename =~ s%.*?([^/]+\.json)$%$1%mx;
        $broadcast->{'basefile'} = $basename;
        my $allowed = 0;

        $broadcast->{'contacts'}      = Thruk::Utils::list($broadcast->{'contacts'});
        $broadcast->{'contactgroups'} = Thruk::Utils::list($broadcast->{'contactgroups'});

        # not restriced at all
        if(scalar @{$broadcast->{'contacts'}} == 0 && scalar @{$broadcast->{'contactgroups'}} == 0) {
            $allowed = 1;
        }
        # allowed for specific contacts
        if(scalar @{$broadcast->{'contacts'}}) {
            my $contacts = Thruk::Utils::array2hash($broadcast->{'contacts'});
            if($contacts->{$c->stash->{'remote_user'}}) {
                $allowed = 1;
            }
        }
        # allowed for specific contactgroups
        if(scalar @{$broadcast->{'contactgroups'}}) {
            my $contactgroups = Thruk::Utils::array2hash($broadcast->{'contactgroups'});
            for my $group (keys %{$groups}) {
                if($contactgroups->{$group}) {
                    $allowed = 1;
                    last;
                }
            }
        }

        # date / time filter
        if($broadcast->{'expires'}) {
            my $expires_ts = Thruk::Utils::_parse_date($c, $broadcast->{'expires'});
            if($now > $expires_ts) {
                next;
            }
        }

        if($broadcast->{'hide_before'}) {
            my $hide_before_ts = Thruk::Utils::_parse_date($c, $broadcast->{'hide_before'});
            if($now < $hide_before_ts) {
                next;
            }
        }

        next unless $allowed;
        push @{$list}, $broadcast;
    }

    # marked as read already?
    if(scalar @{$list} > 0) {
        my $user_data = Thruk::Utils::get_user_data($c);
        if($user_data->{'broadcast'} && $user_data->{'broadcast'}->{'read'} && $user_data->{'broadcast'}->{'read'} eq $list->[0]->{'basefile'}) {
            return([]);
        }
    }

    return($list);
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
