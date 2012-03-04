package Thruk::Utils::CLI;

=head1 NAME

Thruk::Utils::CLI - Utilities Collection for CLI Tool

=head1 DESCRIPTION

Utilities Collection for CLI Tool

=cut

use warnings;
use strict;
use Carp;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Catalyst::ScriptRunner;

##############################################

=head1 METHODS

=head2 new

  new()

create CLI Tool object

=cut
sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    $ENV{'THRUK_SRC'} = 'CLI';
    return $self;
}

##############################################
sub _run {
    my($self) = @_;

    $self->_get_options();

    if(defined $self->{'opt'}->{'listbackends'}) {
        return $self->_listbackends();
    }

    if(defined $self->{'opt'}->{'url'}) {
        if($self->{'opt'}->{'url'} =~ m|^\w+\.cgi|gmx) {
            $self->{'opt'}->{'url'} = '/thruk/cgi-bin/'.$self->{'opt'}->{'url'};
        }
        return $self->_request_url($self->{'opt'}->{'url'})
    }

    pod2usage( { -verbose => 2 } );
    return 0;
}

##############################################
sub _listbackends {
    my($self) = @_;
    my $c = $self->_dummy_c();
    printf("%-4s %-10s %s\n", 'Def', 'Key', 'Name');
    printf("-------------------------\n");
    for my $key (keys %{$c->stash->{'backend_detail'}}) {
        printf("%-4s %-10s %s\n",
                $c->stash->{'backend_detail'}->{$key}->{'disabled'} == 0 ? ' * ' : '',
                $key,
                $c->stash->{'backend_detail'}->{$key}->{'name'}
        );
    }
    printf("-------------------------\n");
    return 0;
}

##############################################
sub _request_url {
    my($self,$url) = @_;

    $ENV{'REQUEST_URI'}      = $url;
    $ENV{'SCRIPT_NAME'}      = $url;
    $ENV{'SCRIPT_NAME'}      =~ s/\?(.*)$//gmx;
    $ENV{'QUERY_STRING'}     = $1 if defined $1;
    $ENV{'SERVER_PROTOCOL'}  = 'HTTP/1.0'  unless defined $ENV{'SERVER_PROTOCOL'};
    $ENV{'REQUEST_METHOD'}   = 'GET'       unless defined $ENV{'REQUEST_METHOD'};
    $ENV{'HTTP_HOST'}        = '127.0.0.1' unless defined $ENV{'HTTP_HOST'};
    $ENV{'REMOTE_ADDR'}      = '127.0.0.1' unless defined $ENV{'REMOTE_ADDR'};
    $ENV{'SERVER_PORT'}      = '80'        unless defined $ENV{'SERVER_PORT'};
    $ENV{'NO_EXTERNAL_JOBS'} = 1;

    Catalyst::ScriptRunner->run('Thruk', 'Thrukembedded');

    if($ENV{'HTTP_CODE'} != 200) {
        print "\n";
        return 1;
    }
    return 0;
}

##############################################
sub _get_options {
    my($self) = @_;

    $self->{'opt'} = {
        'verbose'  => 0,
        'backends' => [],
    };
    Getopt::Long::Configure('no_ignore_case');
    GetOptions (
       "h|help"             => \$self->{'opt'}->{'help'},
       "v|verbose"          => \$self->{'opt'}->{'verbose'},
       "l|list-backends"    => \$self->{'opt'}->{'listbackends'},
       "b|backend=s"        =>  $self->{'opt'}->{'backends'},
       "u|url=s"            => \$self->{'opt'}->{'url'},
       "a|auth=s"           => \$self->{'opt'}->{'auth'},
    ) or pod2usage( { -verbose => 2, -message => 'error in options' } );

    $ENV{'REMOTE_USER'}    = $self->{'opt'}->{'auth'} if defined $self->{'opt'}->{'auth'};
    $ENV{'THRUK_BACKENDS'} = join(',', @{$self->{'opt'}->{'backends'}}) if scalar @{$self->{'opt'}->{'backends'}} > 0;

    return;
}

##############################################
sub _dummy_c {
    my($self) = @_;
    my $olduser = $ENV{'REMOTE_USER'};
    $ENV{'REMOTE_USER'} = 'dummy';
    require Catalyst::Test;
    Catalyst::Test->import('Thruk');
    my($res, $c) = ctx_request('/thruk/dummy');
    $ENV{'REMOTE_USER'} = $olduser;
    die('dummy request failed with status: '.$res->code) unless $res->code == 200;
    return $c;
}

1;
