package Thruk::Utils::Conf::Tools::SuggestPossibleTemplates;

use strict;
use warnings;
use Storable qw/dclone/;
use Thruk::Utils::Conf;

=head1 NAME

Thruk::Utils::Conf::Tools::SuggestPossibleTemplates.pm - Tool to cleanup duplicate template attributes

=head1 DESCRIPTION

Tool to suggest possible useful templates

=head1 METHODS

=cut

##########################################################

=head2 new($c)

returns new instance of this tool

=cut
sub new {
    my($class) = @_;
    my $self = {
        category    => 'Templates',
        link        => 'Suggest Useful Templates',
        title       => 'Suggest Useful Templates',
        description => 'Suggest useful templates which could be used',
        fixlink     => 'fix',
    };
    bless($self, $class);
    return($self);
}

##########################################################

=head2 get_list($c, $ignores)

returns list of potential objects to cleanup

=cut
sub get_list {
    my($self, $c, $ignores) = @_;

    my $result    = [];
    for my $type (qw/host service contact/) {
        my $templates = {};
        for my $tmp (@{$c->{'obj_db'}->get_templates_by_type($type)}) {
            my $resolved = dclone($tmp->get_resolved_config($c->{'obj_db'}));
            delete $resolved->{'register'};
            delete $resolved->{'name'};
            $templates->{$tmp->get_template_name()} = {
                resolved => $resolved,
                obj      => $tmp,
            };
        }
        for my $obj (@{$c->{'obj_db'}->get_objects_by_type($type)}) {
            for my $tmp (keys %{$templates}) {
                next if($obj->{'conf'}->{'use'} && grep(/^\Q$tmp\E$/mx, @{$obj->{'conf'}->{'use'}}));
                my $resolved = $templates->{$tmp}->{'resolved'};
                my $template = $templates->{$tmp}->{'obj'};
                my($total, $identical, $ok, $removeable) = (0, 0, 1, []);
                for my $attr (keys %{$resolved}) {
                    $total++;
                    my $rc = _could_use_template_attr($resolved->{$attr}, $obj->{'conf'}->{$attr});
                    if($rc == 1) {
                        $identical++;
                        push @{$removeable}, $attr;
                    }
                    if($rc == 0) {
                        $ok = 0;
                        last;
                    }
                }
                next unless $ok;
                next unless $identical > 1;
                push $result, {
                    ident      => $obj->get_id(),
                    id         => $obj->get_id(),
                    name       => $obj->get_name(),
                    type       => $obj->get_type(),
                    obj        => $obj,
                    message    => 'could save '.$identical.' attributes by using <a href="conf.cgi?sub=objects&amp;data.id='.$template->get_id().'">'.$tmp.'</a> template',
                    cleanable  => 1,
                    removeable => $removeable,
                    template   => $tmp,
                };
            }
        }
    }
    return(Thruk::Utils::Conf::clean_from_tool_ignores($result, $ignores));
}

##########################################################

=head2 cleanup

cleanup this object

=cut
sub cleanup {
    my($self, $c, $ident, $ignores) = @_;
    my $list = $self->get_list($c, $ignores);
    my $data;
    for my $data (@{$list}) {
        if($ident eq 'all' || $data->{'ident'} eq $ident) {
            for my $attr (@{$data->{'removeable'}}) {
                delete $data->{'obj'}->{'conf'}->{$attr};
            }
            $data->{'obj'}->{'conf'}->{'use'} = [] unless defined $data->{'obj'}->{'conf'}->{'use'};
            if(!grep(/\Q$data->{'template'}\E/mx, @{$data->{'obj'}->{'conf'}->{'use'}})) {
                push @{$data->{'obj'}->{'conf'}->{'use'}}, $data->{'template'};
            }
            $c->{'obj_db'}->update_object($data->{'obj'}, dclone($data->{'obj'}->{'conf'}), join("\n", @{$data->{'obj'}->{'comments'}}));
        }
    }
    return;
}


##########################################################
sub _could_use_template_attr {
    my($tval, $oval) = @_;
    return 0 if !defined $oval;
    if(ref $tval eq '') {
        return 1 if ($tval eq $oval);
    } else {
        return 1 if (join(',', @{$tval}) eq join(',', @{$oval}));
    }
    return 2;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
