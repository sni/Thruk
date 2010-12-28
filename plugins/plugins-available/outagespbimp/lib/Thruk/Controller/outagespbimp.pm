package Thruk::Controller::outagespbimp;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::outagespbimp - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

######################################

=head2 statusmap_cgi

page: /thruk/cgi-bin/statusmap.cgi

=cut
sub outagespbimp_cgi : Regex('thruk\/cgi\-bin\/outagespbimp\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/outagespbimp/index');
}



##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # We want root problems only
    my $hst_pbs = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
						    is_problem => 1
                                                  ]);

    if(defined $hst_pbs and scalar @{$hst_pbs} > 0) {
        my $hostcomments = {};
        my $tmp = $c->{'db'}->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), service_description => undef ]);
        for my $com (@{$tmp}) {
            $hostcomments->{$com->{'host_name'}} = 0 unless defined $hostcomments->{$com->{'host_name'}};
            $hostcomments->{$com->{'host_name'}}++;

        }

        my $tmp2 = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts') ] );
        my $all_hosts = Thruk::Utils::array2hash($tmp2, 'name');
        for my $host (@{$hst_pbs}) {

            # get number of comments
            $host->{'comment_count'} = 0;
            $host->{'comment_count'} = $hostcomments->{$host->{'name'}} if defined $hostcomments->{$host->{'name'}};

            # count number of impacted hosts / services
            my($affected_hosts,$affected_services) = $self->_count_hosts_and_services_impacts($c, $host->{'name'}, $all_hosts);

            $host->{'affected_hosts'}    = $affected_hosts;
            $host->{'affected_services'} = $affected_services;

        }
    }

    # sort by criticity
    my $sortedhst_pbs = Thruk::Backend::Manager::_sort($c, $hst_pbs, { 'DESC' => 'criticity' });

    $c->stash->{hst_pbs}        = $sortedhst_pbs;
    $c->stash->{title}          = 'Problems and impacts';
    $c->stash->{infoBoxTitle}   = 'Problems and impacts';
    $c->stash->{page}           = 'outagespbimp';
    $c->stash->{template}       = 'outagespbimp.tt';

    Thruk::Utils::ssi_include($c);

    return 1;
}


##########################################################
# Count the impacts for an host
sub _count_hosts_and_services_impacts {
    my($self, $c, $host, $all_hosts ) = @_;

    my $affected_hosts    = 0;
    my $affected_services = 0;

    return(0,0) if !defined $all_hosts->{$host};

    use Data::Dumper;
    #print STDERR "Impact";
    #print STDERR Dumper($all_hosts->{$host}->{'childs'});
    #print STDERR Dumper($all_hosts->{$host}->{'impacts'});

    if(defined $all_hosts->{$host}->{'impacts'} and $all_hosts->{$host}->{'impacts'} ne '') {
        for my $child (@{$all_hosts->{$host}->{'impacts'}}) {
	    # Look at if we match an host or a service here
	    # a service will have a /, not for hosts
	    if($child =~ /\//){
		$affected_services += 1;
	    }else{
		$affected_hosts += 1;
	    }
        }
    }

    return($affected_hosts, $affected_services);
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
