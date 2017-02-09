package Thruk::Utils::News;

=head1 NAME

Thruk::Utils::News - News Utilities Collection for Thruk

=head1 DESCRIPTION

News Utilities Collection for Thruk

=cut

use strict;
use warnings;

##############################################

=head1 METHODS

=head2 get_news($c)

  get_news($c)

return list of news for this contact

=cut
sub get_news {
    my($c) = @_;
    my $list = [];

    my $now       = time();
    my $groups    = $c->cache->get->{'users'}->{$c->stash->{'remote_user'}}->{'contactgroups'};
    for my $file (reverse sort glob($c->config->{'var_path'}.'/news/*.json')) {
        my $news = Thruk::Utils::read_data_file($file);
        $news->{'file'} = $file;
        my $basename = $file;
        $basename =~ s%.*?([^/]+\.json)$%$1%mx;
        $news->{'basefile'} = $basename;
        my $allowed = 0;

        $news->{'contacts'}      = Thruk::Utils::list($news->{'contacts'});
        $news->{'contactgroups'} = Thruk::Utils::list($news->{'contactgroups'});

        # not restriced at all
        if(scalar @{$news->{'contacts'}} == 0 && scalar @{$news->{'contactgroups'}} == 0) {
            $allowed = 1;
        }
        # allowed for specific contacts
        if(scalar @{$news->{'contacts'}}) {
            my $contacts = Thruk::Utils::array2hash($news->{'contacts'});
            if($contacts->{$c->stash->{'remote_user'}}) {
                $allowed = 1;
            }
        }
        # allowed for specific contactgroups
        if(scalar @{$news->{'contactgroups'}}) {
            my $contactgroups = Thruk::Utils::array2hash($news->{'contactgroups'});
            for my $group (keys %{$groups}) {
                if($contactgroups->{$group}) {
                    $allowed = 1;
                    last;
                }
            }
        }

        # date / time filter
        if($news->{'expires'}) {
            my $expires_ts = Thruk::Utils::_parse_date($c, $news->{'expires'});
            if($now > $expires_ts) {
                next;
            }
        }

        if($news->{'hide_before'}) {
            my $hide_before_ts = Thruk::Utils::_parse_date($c, $news->{'hide_before'});
            if($now < $hide_before_ts) {
                next;
            }
        }

        next unless $allowed;
        push @{$list}, $news;
    }

    # marked as read already?
    if(scalar @{$list} > 0) {
        my $user_data = Thruk::Utils::get_user_data($c);
        if($user_data->{'news'} && $user_data->{'news'}->{'read'} && $user_data->{'news'}->{'read'} eq $list->[0]->{'basefile'}) {
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
