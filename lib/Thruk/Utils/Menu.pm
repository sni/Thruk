package Thruk::Utils::Menu;

=head1 NAME

Thruk::Utils::Menu - Menu Utilities Collection for Thruk

=head1 DESCRIPTION

Menu Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp;
use File::Slurp qw/read_file/;
use Storable qw/dclone/;
use Thruk::Utils::Filter;
use Thruk::Utils::Log qw/:all/;

##############################################
=head1 METHODS

=head2 read_navigation

  read_navigation()

reads the navigation

=cut
sub read_navigation {
    my $c = shift;

    $c->stats->profile(begin => "Utils::Menu::read_navigation()");

    $c->{'stash'} = $c->stash; # required for backwards compatibility on old menu_local.confs

    my $file = $c->config->{'project_root'}.'/menu.conf';
    $file    = $c->config->{'project_root'}.'/menu_local.conf' if -e $c->config->{'project_root'}.'/menu_local.conf';
    if(defined $ENV{'THRUK_CONFIG'}) {
        $file = $ENV{'THRUK_CONFIG'}.'/menu.conf'       if -e $ENV{'THRUK_CONFIG'}.'/menu.conf';
        $file = $ENV{'THRUK_CONFIG'}.'/menu_local.conf' if -e $ENV{'THRUK_CONFIG'}.'/menu_local.conf';
    }

    local $Thruk::Request::c = $c;
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

=head2 insert_section

  insert_section()

insert a new section at the given index

=cut
sub insert_section {
    my ($idx, %section) = @_;
    $section{'links'} = [];
    $section{'icon'}  = '' unless defined $section{'icon'};
    splice(@{$Thruk::Utils::Menu::navigation}, $idx, 0, \%section);
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
    $link{'html'}   = $link{'html'};
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
    $link{'html'}   = $link{'html'};
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

  remove_item($category)
  remove_item($category, $item_name)
  remove_item($category, $subcategory, $item_name)
  remove_item($category, $subcategory, $item_name, $hintname)

removes an existing item from an existing category

=cut
sub remove_item {
    my($category, $subcategory, $item_name, $hintname) = @_;
    if(!defined $item_name) { $item_name = $subcategory; $subcategory = undef; }

    if($hintname) {
        $Thruk::Utils::Menu::removed_items->{$category}->{$subcategory}->{$item_name}->{$hintname} = 1;
    } elsif($subcategory) {
        $Thruk::Utils::Menu::removed_items->{$category}->{$subcategory}->{$item_name}->{'_ALL_'} = 1;
    } elsif($item_name) {
        $Thruk::Utils::Menu::removed_items->{$category}->{$item_name}->{'_ALL_'} = 1;
    } else {
        $Thruk::Utils::Menu::removed_items->{$category}->{'_ALL_'} = 1;
    }

    return 1;
}

##############################################

=head2 remove_section

  remove_section($category)

removes an existing section completely

=cut
sub remove_section {
    my($category) = @_;
    $Thruk::Utils::Menu::removed_items->{$category}->{'_ALL_'} = 1;
    return 1;
}

##############################################

=head2 has_group

  has_group($group)

returns 1 if the current user has this group

=cut
sub has_group {
    my($group, $tmp) = @_;
    my $c = $Thruk::Request::c;
    if(defined $tmp) { $group = $tmp; }  # keep backwards compatible with the old call has_group($c, $group)

    if($c->user_exists) {
        return($c->user->has_group($group));
    }
    return 0;
}

##############################################

=head2 has_role

  has_role($role)
  has_role([$role, ...])

returns 1 if the current user has this role

=cut
sub has_role {
    my @roles = @_;
    my $c = $Thruk::Request::c;

    for my $role (@roles) {
        for my $role2 (@{Thruk::Utils::list($role)}) {
            next if(ref $role2 eq 'Thruk::Context'); # keep backwards compatible with the old call has_role($c, $role)
            return 0 unless $c->check_user_roles($role2);
        }
    }
    return 1;
}

##############################################

=head2 is_user

  is_user($username)

returns 1 if the current user has the given name

=cut
sub is_user {
    my($name) = @_;
    my $c = $Thruk::Request::c;

    my $user  = $c->stash->{'remote_user'} || '';
    if($user eq $name) {
        return 1;
    }
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
    our $orig_additional_items;
    our $orig_additional_subitems;
    if(!defined $orig_additional_items) {
        $orig_additional_items    = defined $Thruk::Utils::Menu::additional_items    ? dclone($Thruk::Utils::Menu::additional_items)    : [];
        $orig_additional_subitems = defined $Thruk::Utils::Menu::additional_subitems ? dclone($Thruk::Utils::Menu::additional_subitems) : [];
    }
    $Thruk::Utils::Menu::additional_items    = dclone($orig_additional_items);
    $Thruk::Utils::Menu::additional_subitems = dclone($orig_additional_subitems);
    $Thruk::Utils::Menu::removed_items = {};

    ## no critic
    eval("#line 1 $file\n".read_file($file));
    ## use critic
    if($@) {
        _error("error while loading navigation from ".$file.": ".$@);
        confess($@);
    }

    $c->stash->{user_menu_items} = {};
    my $user_items;
    my $userdata   = $c->stash->{user_data}        || {};
    my $globaldata = $c->stash->{global_user_data} || {};
    for my $src ($userdata, $globaldata) {
        if(defined $src and defined $src->{'bookmarks'}) {
            for my $section (keys %{$src->{'bookmarks'}}) {
                for my $item (@{$src->{'bookmarks'}->{$section}}) {
                    my $href = $c->stash->{'use_bookmark_titles'} ? _uri_with($item->[1], {title => $item->[0]}) : $item->[1];
                    if($item->[2]) {
                        my $backends = Thruk::Utils::backends_hash_to_list($c, $item->[2]);
                        $href = _uri_with($href, { backend => join(',', @{$backends}) });
                    }
                    my $item = {
                        name => $item->[0],
                        href => $href,
                    };
                    push @{$user_items}, [ $section, $item ];
                }
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
            # visibility defined by callback?
            if(defined $link->{'visible_cb'}) {
                my $rc;
                ## no critic
                eval '$rc = '.$link->{'visible_cb'}.'($c);';
                ## use critic
                if($@) {
                    _error("error while running callback ".$link->{'visible_cb'}.": ".$@);
                }
                next unless $rc;
            }

            $link->{'links'}  = [] unless defined $link->{'links'};
            $link->{'target'} = _get_menu_target() unless defined $link->{'target'};
            $link->{'href'}   = _get_menu_link($link->{'href'});
            $link->{'html'}   = $link->{'html'};
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
            $link->{'html'}   = $link->{'html'};

            push(@{$sublink->{'links'}}, $link);
        }
    }

    # remove unwanted items
    for my $section_name (keys %{$Thruk::Utils::Menu::removed_items}) {
        my $section = _get_section_by_name($section_name) || next;
        for my $item_name (keys %{$Thruk::Utils::Menu::removed_items->{$section_name}}) {
            if($item_name eq '_ALL_') {
                $section->{'links'} = [];
                next;
            }
            for my $sub_item_name (keys %{$Thruk::Utils::Menu::removed_items->{$section_name}->{$item_name}}) {
                if($sub_item_name eq '_ALL_') {
                    $section->{'links'} = _remove_item_from_links($section->{'links'}, $item_name);
                } else {
                    for my $hintname (keys %{$Thruk::Utils::Menu::removed_items->{$section_name}->{$item_name}->{$sub_item_name}}) {
                        for my $link (@{$section->{'links'}}) {
                            if($link->{'name'} eq $item_name) {
                                if($hintname eq '_ALL_') {
                                    $link->{'links'} = _remove_item_from_links($link->{'links'}, $sub_item_name);
                                } else {
                                    for my $sublink (@{$link->{'links'}}) {
                                        if($sublink->{'name'} eq $sub_item_name) {
                                            $sublink->{'links'} = _remove_item_from_links($sublink->{'links'}, $hintname);
                                            last;
                                        }
                                    }
                                }
                                last;
                            }
                        }
                    }
                }
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

    $c->stash->{'navigation'} = $new_nav;

    # cleanup
    $Thruk::Utils::Menu::c = undef;

    return;
}

##############################################

=head2 _get_menu_target

  _get_menu_target()

returns the current prefered target

=cut
sub _get_menu_target {
    my $c = $Thruk::Request::c;

    return($c->{'_menu_target'} ||= _set_menu_target($c));
}
sub _set_menu_target {
    my($c) = @_;
    return $c->stash->{'target'} if defined $c->stash->{'target'} and $c->stash->{'target'} ne '';
    if($c->stash->{'use_frames'}) {
        return('main');
    }
    return('_self');
}

##############################################

=head2 _get_menu_link

  _get_menu_link()

returns the link with prefix

=cut
sub _get_menu_link {
    my($link) = @_;
    return '' unless defined $link;
    my $c = $Thruk::Request::c;
    my $product = $c->config->{'product_prefix'};
    if($link =~ s|^\Q/thruk/\E||mx || $link =~ s|^\Q$product\E/||mx) {
        return $c->stash->{'url_prefix'}.$link;
    }
    return $link;
}


##############################################

=head2 _get_section_by_name

  _get_section_by_name()

returns a section by name

=cut
sub _get_section_by_name {
    my($name, $create) = @_;

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

##############################################

=head2 _uri_with

  _uri_with($baseurl, $additions)

returns link expanded with additional parameters

=cut

sub _uri_with {
    my($base, $add) = @_;
    my $uri = $base;
    for my $key (keys %{$add}) {
        my $concat = $base =~ m/\?/mx ? '&amp;' : '?';
        $uri .= $concat.$key.'='.Thruk::Utils::Filter::as_url_arg($add->{$key});
    }
    return $uri;
}

##############################################

=head2 _remove_item_from_links

  _remove_item_from_links($links, $name)

returns links list with items by name removed

=cut

sub _remove_item_from_links {
    my($links, $name) = @_;
    my $new_links = [];
    for my $link (@{$links}) {
        push @{$new_links}, $link if(!defined $link->{'name'} || $link->{'name'} ne $name);
    }
    return($new_links);
}

1;
