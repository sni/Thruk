package Thruk::Utils::Menu;

=head1 NAME

Thruk::Utils::Menu - Menu Utilities Collection for Thruk

=head1 DESCRIPTION

Menu Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp;
use Data::Dumper;
use File::Slurp;


##############################################
=head1 METHODS

=head2 read_navigation

  read_navigation()

reads the navigation

=cut
sub read_navigation {
    my $c = shift;

    $c->stats->profile(begin => "Utils::Menu::read_navigation()");

    my $file = $c->config->{'project_root'}.'/menu.conf';
    $file    = $c->config->{'project_root'}.'/menu_local.conf' if -e $c->config->{'project_root'}.'/menu_local.conf';

    # (dev,ino,mode,nlink,uid,gid,rdev,size,atime,mtime,ctime,blksize,blocks)
    my @menu_conf_stat = stat($file);
    my $last_stat = $c->cache->get('menu_conf_stat');
    if(!defined $last_stat
       or $last_stat->[1] != $menu_conf_stat[1] # inode changed
       or $last_stat->[9] != $menu_conf_stat[9] # modify time changed
      ) {
        $c->log->info("menu.conf has changed, updating...") if defined $last_stat;
        $c->cache->set('menu_conf_stat', \@menu_conf_stat);

        $Thruk::Utils::Menu::c          = $c;
        $Thruk::Utils::Menu::navigation = [];

        ## no critic
        eval(read_file($file));
        ## use critic
        if($@) {
            $c->log->error("error while loading navigation from ".$file.": ".$@);
            confess($@);
        }

        $c->stash->{'navigation'}  = $Thruk::Utils::Menu::navigation;
        $c->cache->set('navigation', $Thruk::Utils::Menu::navigation);
    } else {
        # return cached version
        $c->stash->{'navigation'}  = $c->cache->get('navigation');
        return;
    }

    $c->stats->profile(end => "Utils::Menu::read_navigation()");

    return;
}


##############################################

=head2 add_section

  add_section()

add a new section

=cut
sub add_section {
    my %section = @_;
    $section{'links'} = [];
    $section{'icon'}  = '' unless defined $section{'icon'};
    push(@{$Thruk::Utils::Menu::navigation}, \%section);
    return;
}


##############################################

=head2 add_link

  add_link()

add a new link to last section

=cut
sub add_link {
    my %link = @_;
    my $last_section = $Thruk::Utils::Menu::navigation->[scalar @{$Thruk::Utils::Menu::navigation} - 1];
    $link{'target'} = get_target() unless defined $link{'target'};
    $link{'links'}  = [] unless defined $link{'links'};
    $link{'href'}   = "" unless defined $link{'href'};
    push(@{$last_section->{'links'}}, \%link);
    return;
}


##############################################

=head2 add_sub_link

  add_sub_link()

add a new sub link to last link

=cut
sub add_sub_link {
    my %link = @_;
    my $last_section = $Thruk::Utils::Menu::navigation->[scalar @{$Thruk::Utils::Menu::navigation} - 1];
    my $last_link    = $last_section->{'links'}->[scalar @{$last_section->{'links'}} - 1];
    $link{'target'} = get_target() unless defined $link{'target'};
    $link{'links'}  = [] unless defined $link{'links'};
    $link{'href'}   = "" unless defined $link{'href'};
    $link{'name'}   = "" unless defined $link{'name'};
    push(@{$last_link->{'links'}}, \%link);
    return;
}


##############################################

=head2 add_sub_sub_link

  add_sub_sub_link()

add a new additional link to last sub link

=cut
sub add_sub_sub_link {
    my %link = @_;
    my $last_section  = $Thruk::Utils::Menu::navigation->[scalar @{$Thruk::Utils::Menu::navigation} - 1];
    my $last_link     = $last_section->{'links'}->[scalar @{$last_section->{'links'}} - 1];
    my $last_sub_link = $last_link->{'links'}->[scalar @{$last_link->{'links'}} - 1];
    $link{'target'}   = get_target() unless defined $link{'target'};
    $link{'href'}     = "" unless defined $link{'href'};
    $link{'name'}     = "" unless defined $link{'name'};
    push(@{$last_sub_link->{'links'}}, \%link);
    return;
}


##############################################

=head2 add_search

  add_search()

add a new search to the last section

=cut
sub add_search {
    my %search = @_;
    my $last_section = $Thruk::Utils::Menu::navigation->[scalar @{$Thruk::Utils::Menu::navigation} - 1];
    $search{'search'} = 1;
    $search{'target'} = get_target() unless defined $search{'target'};
    $search{'href'}   = "" unless defined $search{'href'};
    push(@{$last_section->{'links'}}, \%search);
    return;
}


##############################################

=head2 get_target

  get_target()

returns the current prefered target

=cut
sub get_target {
    my $c = $Thruk::Utils::Menu::c;

    return $c->{'stash'}->{'target'} if defined $c->{'stash'}->{'target'};
    if($c->{'stash'}->{'use_frames'}) {
        return("main");
    }
    return("_self");
}


1;

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
