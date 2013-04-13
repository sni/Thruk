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
use Storable qw/dclone/;

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
    if(defined $ENV{'CATALYST_CONFIG'}) {
        $file = $ENV{'CATALYST_CONFIG'}.'/menu.conf'       if -e $ENV{'CATALYST_CONFIG'}.'/menu.conf';
        $file = $ENV{'CATALYST_CONFIG'}.'/menu_local.conf' if -e $ENV{'CATALYST_CONFIG'}.'/menu_local.conf';
    }
    if(defined $ENV{'THRUK_CONFIG'}) {
        $file = $ENV{'THRUK_CONFIG'}.'/menu.conf'       if -e $ENV{'THRUK_CONFIG'}.'/menu.conf';
        $file = $ENV{'THRUK_CONFIG'}.'/menu_local.conf' if -e $ENV{'THRUK_CONFIG'}.'/menu_local.conf';
    }

    _renew_navigation($c, $file);

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
    $link{'links'}  = [] unless defined $link{'links'};
    $link{'target'} = _get_menu_target() unless defined $link{'target'};
    $link{'href'}   = _get_menu_link($link{'href'});
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
    $link{'target'}  = _get_menu_target() unless defined $link{'target'};
    $link{'links'}   = [] unless defined $link{'links'};
    $link{'href'}    = _get_menu_link($link{'href'});
    $link{'name'}    = "" unless defined $link{'name'};
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
    $link{'target'}   = _get_menu_target() unless defined $link{'target'};
    $link{'href'}     = _get_menu_link($link{'href'});
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
    my $last_section  = $Thruk::Utils::Menu::navigation->[scalar @{$Thruk::Utils::Menu::navigation} - 1];
    $search{'search'} = 1;
    $search{'target'} = _get_menu_target() unless defined $search{'target'};
    $search{'href'}   = _get_menu_link($search{'href'});
    push(@{$last_section->{'links'}}, \%search);
    return;
}

##############################################

=head2 insert_item

  insert_item()

add a new item in existing category

=cut
sub insert_item {
    my($category, $item) = @_;

    $Thruk::Utils::Menu::additional_items = [] unless defined $Thruk::Utils::Menu::additional_items;
    push @{$Thruk::Utils::Menu::additional_items}, [ $category, $item ];

    return 1;
}

##############################################

=head2 insert_sub_item

  insert_sub_item()

add a new sub item in existing category

=cut
sub insert_sub_item {
    my($category, $subcat, $item) = @_;

    $Thruk::Utils::Menu::additional_subitems = [] unless defined $Thruk::Utils::Menu::additional_subitems;
    push @{$Thruk::Utils::Menu::additional_subitems}, [ $category, $subcat, $item ];
    return 1;
}

##############################################

=head2 remove_item

  remove_item()

removes an existing item from an existing category

=cut
sub remove_item {
    my($category, $item_name) = @_;

    $Thruk::Utils::Menu::removed_items = {} unless defined $Thruk::Utils::Menu::removed_items;
    $Thruk::Utils::Menu::removed_items->{$category}->{$item_name} = 1;

    return 1;
}

##############################################

=head2 has_group

  has_group($c, $group)

returns 1 if the current user has this group

=cut
sub has_group {
    my($c, $group) = @_;

    my $cache = $c->cache;
    my $user  = $c->stash->{'remote_user'};
    if($cache and $user) {
        my $contactgroups = $cache->get($user);
        if($contactgroups and $contactgroups->{'contactgroups'}->{$group}) {
            return 1;
       }
    }
    return 0;
}

##############################################

=head2 has_role

  has_role($c, $role)

returns 1 if the current user has this role

=cut
sub has_role {
    my($c, $role) = @_;

    return 1 if $c->check_user_roles($role);
    return 0;
}

##############################################

=head2 _renew_navigation

  _renew_navigation()

returns the current prefered target

=cut
sub _renew_navigation {
    my($c, $file) = @_;

    $Thruk::Utils::Menu::c          = $c;
    $Thruk::Utils::Menu::navigation = [];

    # make a copy of additional menuitems
    # otherwise, items added from a menu_local.conf would be added once
    # per loading a page
    my $additional_items    = defined $Thruk::Utils::Menu::additional_items    ? dclone($Thruk::Utils::Menu::additional_items)    : [];
    my $additional_subitems = defined $Thruk::Utils::Menu::additional_subitems ? dclone($Thruk::Utils::Menu::additional_subitems) : [];

    ## no critic
    eval("#line 1 $file\n".read_file($file));
    ## use critic
    if($@) {
        $c->log->error("error while loading navigation from ".$file.": ".$@);
        confess($@);
    }

    $c->stash->{user_menu_items} = {};
    my $user_items;
    my $userdata = Thruk::Utils::get_user_data($c);
    $c->stash->{user_data} = $userdata;
    if(defined $userdata and defined $userdata->{'bookmarks'}) {
        for my $section (keys %{$userdata->{'bookmarks'}}) {
            for my $item (@{$userdata->{'bookmarks'}->{$section}}) {
                my $item = {
                        name => $item->[0],
                        href => $item->[1]
                };
                push @{$user_items}, [ $section, $item ];
            }
        }
    }

    my $globaldata = Thruk::Utils::get_global_user_data($c);
    $c->stash->{global_user_data} = $globaldata;
    if(defined $globaldata and defined $globaldata->{'bookmarks'}) {
        for my $section (keys %{$globaldata->{'bookmarks'}}) {
            for my $item (@{$globaldata->{'bookmarks'}->{$section}}) {
                my $item = {
                        name => $item->[0],
                        href => $item->[1]
                };
                push @{$user_items}, [ $section, $item ];
            }
        }
    }

    # add some more items
    if(defined $Thruk::Utils::Menu::additional_items or defined $user_items) {
        for my $to_add (@{$Thruk::Utils::Menu::additional_items}, @{$user_items}) {
            my $section       = _get_section_by_name($to_add->[0], 1);
            my $link          = $to_add->[1];

            # only visible for some roles?
            if(defined $link->{'roles'}) {
                my $has_access = 1;
                my @roles = ref $link->{'roles'} eq 'ARRAY' ? @{$link->{'roles'}} : [ $link->{'roles'} ];
                for my $role (@roles) {
                    $has_access = 0 unless $c->check_user_roles( $role );
                }
                next unless $has_access;
            }

            $link->{'links'}  = [] unless defined $link->{'links'};
            $link->{'target'} = _get_menu_target() unless defined $link->{'target'};
            $link->{'href'}   = _get_menu_link($link->{'href'});
            push(@{$section->{'links'}}, $link);
        }
    }

    # add some more sub items
    if(defined $Thruk::Utils::Menu::additional_subitems or defined $user_items) {
        for my $to_add (@{$Thruk::Utils::Menu::additional_subitems}, @{$user_items}) {
            my $section       = _get_section_by_name($to_add->[0], 1);
            next unless defined $section;
            my $sublink = _get_sublink_by_name($section, $to_add->[1]);
            next unless defined $sublink;

            my $link          = $to_add->[2];

            # only visible for some roles?
            if(defined $link->{'roles'}) {
                my $has_access = 1;
                my @roles = ref $link->{'roles'} eq 'ARRAY' ? @{$link->{'roles'}} : [ $link->{'roles'} ];
                for my $role (@roles) {
                    $has_access = 0 unless $c->check_user_roles( $role );
                }
                next unless $has_access;
            }

            $link->{'links'}  = [] unless defined $link->{'links'};
            $link->{'target'} = _get_menu_target() unless defined $link->{'target'};
            $link->{'href'}   = _get_menu_link($link->{'href'});

            push(@{$sublink->{'links'}}, $link);
        }
    }

    # remove unwanted items
    if(defined $Thruk::Utils::Menu::removed_items) {
        for my $section_name (keys %{$Thruk::Utils::Menu::removed_items}) {
            my $section = _get_section_by_name($section_name) || next;
            for my $item_name (keys %{$Thruk::Utils::Menu::removed_items->{$section_name}}) {
                my $new_links = [];
                for my $link (@{$section->{'links'}}) {
                    push @{$new_links}, $link unless $link->{'name'} eq $item_name
                }
                $section->{'links'} = $new_links;
            }
        }
    }

    # remove empty sections
    my $new_nav = [];
    for my $section (@{$Thruk::Utils::Menu::navigation}) {
        if(scalar @{$section->{'links'}} > 0) {
            push @{$new_nav}, $section;
        }
    }

    $c->stash->{'navigation'}  = $new_nav;

    # restore additional menuitems
    $Thruk::Utils::Menu::additional_items    = dclone($additional_items);
    $Thruk::Utils::Menu::additional_subitems = dclone($additional_subitems);

    return;
}

##############################################

=head2 _get_menu_target

  _get_menu_target()

returns the current prefered target

=cut
sub _get_menu_target {
    my $c = $Thruk::Utils::Menu::c;

    return $c->{'stash'}->{'target'} if defined $c->{'stash'}->{'target'} and $c->{'stash'}->{'target'} ne '';
    if($c->{'stash'}->{'use_frames'}) {
        return("main");
    }
    return("_self");
}


##############################################

=head2 _get_menu_link

  _get_menu_link()

returns the link with prefix

=cut
sub _get_menu_link {
    my $link = shift;
    my $c = $Thruk::Utils::Menu::c;
    return "" unless defined $link;
    return $c->stash->{'url_prefix'}.substr($link,1) if $link =~ m/^\/thruk\//mx;
    return $link;
}


##############################################

=head2 _get_section_by_name

  _get_section_by_name()

returns a section by name

=cut
sub _get_section_by_name {
    my $name   = shift;
    my $create = shift;

    for my $section (@{$Thruk::Utils::Menu::navigation}) {
        return $section if $section->{'name'} eq $name;
    }

    if($create) {
        my $section = {
            name  => $name,
            links => [],
            icon  => '',
        };
        push @{$Thruk::Utils::Menu::navigation}, $section;
        return $section;
    }

    return;
}

##############################################

=head2 _get_sublink_by_name

  _get_sublink_by_name()

returns a link by name

=cut

sub _get_sublink_by_name {
    my $section = shift;
    my $name    = shift;
    next unless defined $section->{'links'};
    for my $sublink (@{$section->{'links'}}) {
        if($sublink->{'name'} eq $name) {
            return($sublink);
        }
    }
    return;
}

1;

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
