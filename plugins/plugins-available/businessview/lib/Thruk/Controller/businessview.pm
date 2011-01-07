package Thruk::Controller::businessview;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::businessview - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

######################################

=head2 businessview_cgi

page: /thruk/cgi-bin/businessview.cgi

=cut
sub businessview_cgi : Regex('thruk\/cgi\-bin\/businessview\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/businessview/index');
}



##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # We want root problems only
    my $hst_pbs = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                                    got_business_rule => 1
                                                  ]);
    my $srv_pbs = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                                    got_business_rule => 1
                                                  ]);

    # Main data given for the criticities level, and know
    # if we have elements in it or not
    my @criticities = (
        {value => 5, text => 'Top production',  nb => 0},
        {value => 4, text => 'Production',      nb => 0},
        {value => 3, text => 'Standard',        nb => 0},
        {value => 2, text => 'Qualification',   nb => 0},
        {value => 1, text => 'Devel',           nb => 0},
        {value => 0, text => 'Nearly nothing',  nb => 0});

    #use Data::Dumper;
    #print STDERR "Service pb";
    #print STDERR Dumper($srv_pbs);

    # First for hosts
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
            my($affected_hosts,$affected_services) = $self->_count_hosts_and_services_impacts($host);

            $host->{'affected_hosts'}    = $affected_hosts;
            $host->{'affected_services'} = $affected_services;

            # add a criticity to this crit level
            my $crit = $host->{'criticity'};
            #print STDERR "ADD crit $crit for\n";
            $criticities[5 - $crit]{"nb"}++;


        }
    }

    # Then for services
    if(defined $srv_pbs and scalar @{$srv_pbs} > 0) {
        my $srvcomments = {};
#        my $tmp = $c->{'db'}->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), service_description => undef ]);
#        for my $com (@{$tmp}) {
#            $hostcomments->{$com->{'host_name'}} = 0 unless defined $hostcomments->{$com->{'host_name'}};
#            $hostcomments->{$com->{'host_name'}}++;
#
#        }

        #print STDERR "POULET";
        for my $srv (@{$srv_pbs}) {

            # get number of comments
            $srv->{'comment_count'} = 0;
            #$srv->{'comment_count'} = $hostcomments->{$host->{'name'}} if defined $hostcomments->{$host->{'name'}};

            # count number of impacted hosts / services
            my($affected_hosts,$affected_services) = $self->_count_hosts_and_services_impacts($srv);

            $srv->{'affected_hosts'}    = $affected_hosts;
            $srv->{'affected_services'} = $affected_services;

            # add a criticity to this crit level
            my $crit = $srv->{'criticity'};
            #print STDERR "ADD crit $crit for service\n";
            $criticities[5 - $crit]{"nb"}++;

        }
    }

    # sort by criticity
    my $sortedhst_pbs = Thruk::Backend::Manager::_sort($c, $hst_pbs, { 'DESC' => 'criticity' });
    my $sortedsrv_pbs = Thruk::Backend::Manager::_sort($c, $srv_pbs, { 'DESC' => 'criticity' });


    use Data::Dumper;
    print STDERR "Impact";
    print STDERR Dumper(@criticities); #$all_hosts->{$host}->{'childs'});


    $c->stash->{hst_pbs}        = $sortedhst_pbs;
    $c->stash->{srv_pbs}        = $sortedsrv_pbs;
    $c->stash->{criticities}    = \@criticities;
    $c->stash->{title}          = 'Business elements';
    $c->stash->{infoBoxTitle}   = 'Business elements';
    $c->stash->{page}           = 'businessview';
    $c->stash->{template}       = 'businessview.tt';

    Thruk::Utils::ssi_include($c);

    return 1;
}


##########################################################
# Count the impacts for an host
sub _count_hosts_and_services_impacts {
    my($self, $host ) = @_;

    my $affected_hosts    = 0;
    my $affected_services = 0;

#    use Data::Dumper;
#    print STDERR "Impact sum for".Dumper($host);
    return(0,0) if !defined $host;

#    use Data::Dumper;
#    print STDERR "Impact";
#    print STDERR Dumper($host); #$all_hosts->{$host}->{'childs'});
    #print STDERR Dumper($all_hosts->{$host}->{'impacts'});

    if(defined $host->{'impacts'} and $host->{'impacts'} ne '') {
        for my $child (@{$host->{'impacts'}}) {
            # Look at if we match an host or a service here
            # a service will have a /, not for hosts
            if($child =~ /\//mx){
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
