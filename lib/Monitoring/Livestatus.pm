package Monitoring::Livestatus;

use 5.006;
use strict;
use warnings;
use Data::Dumper qw/Dumper/;
use Carp qw/carp confess/;
use Cpanel::JSON::XS ();
use Storable qw/dclone/;
use IO::Select ();

use Monitoring::Livestatus::INET ();
use Monitoring::Livestatus::UNIX ();

our $VERSION = '0.82';


# list of allowed options
my $allowed_options = {
        'addpeer'       => 1,
        'backend'       => 1,
        'columns'       => 1,
        'deepcopy'      => 1,
        'header'        => 1,
        'limit'         => 1,
        'limit_start'   => 1,
        'limit_length'  => 1,
        'rename'        => 1,
        'slice'         => 1,
        'sum'           => 1,
        'callbacks'     => 1,
        'wrapped_json'  => 1,
        'sort'          => 1,
        'offset'        => 1,
};

=head1 NAME

Monitoring::Livestatus - Perl API for check_mk livestatus to access runtime
data from Nagios and Icinga

=head1 SYNOPSIS

    use Monitoring::Livestatus;
    my $ml = Monitoring::Livestatus->new(
      socket => '/var/lib/livestatus/livestatus.sock'
    );
    my $hosts = $ml->selectall_arrayref("GET hosts");

=head1 DESCRIPTION

This module connects via socket/tcp to the livestatus addon for Naemon, Nagios,
Icinga and Shinken. You first have to install and activate the livestatus addon
in your monitoring installation.

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an C<Monitoring::Livestatus> object. C<new> takes at least the
socketpath. Arguments are in key-value pairs.

=over 4

=item socket

path to the UNIX socket of check_mk livestatus

=item server

uses this server for a TCP connection

=item peer

alternative way to set socket or server, if value contains ':' server is used,
else socket

=item name

human readable name for this connection, defaults to the the socket/server
address

=item verbose

verbose mode

=item line_separator

ascii code of the line separator, defaults to 10, (newline)

=item column_separator

ascii code of the column separator, defaults to 0 (null byte)

=item list_separator

ascii code of the list separator, defaults to 44 (comma)

=item host_service_separator

ascii code of the host/service separator, defaults to 124 (pipe)

=item keepalive

enable keepalive. Default is off

=item errors_are_fatal

errors will die with an error message. Default: on

=item warnings

show warnings
currently only querys without Columns: Header will result in a warning

=item timeout

set a general timeout. Used for connect and querys, no default

=item query_timeout

set a query timeout. Used for retrieving querys, Default 60sec

=item connect_timeout

set a connect timeout. Used for initial connections, default 5sec

=back

If the constructor is only passed a single argument, it is assumed to
be a the C<peer> specification. Use either socker OR server.

=cut

sub new {
    my($class,@args) = @_;
    unshift(@args, 'peer') if scalar @args == 1;
    my(%options) = @args;

    my $self = {
      'verbose'                     => 0,       # enable verbose output
      'socket'                      => undef,   # use unix sockets
      'server'                      => undef,   # use tcp connections
      'peer'                        => undef,   # use for socket / server connections
      'name'                        => undef,   # human readable name
      'line_separator'              => 10,      # defaults to newline
      'column_separator'            => 0,       # defaults to null byte
      'list_separator'              => 44,      # defaults to comma
      'host_service_separator'      => 124,     # defaults to pipe
      'keepalive'                   => 0,       # enable keepalive?
      'errors_are_fatal'            => 1,       # die on errors
      'backend'                     => undef,   # should be keept undef, used internally
      'timeout'                     => undef,   # timeout for tcp connections
      'query_timeout'               => 60,      # query timeout for tcp connections
      'connect_timeout'             => 5,       # connect timeout for tcp connections
      'warnings'                    => 1,       # show warnings, for example on querys without Column: Header
      'logger'                      => undef,   # logger object used for statistical informations and errors / warnings
      'deepcopy'                    => undef,   # copy result set to avoid errors with tied structures
      'retries_on_connection_error' => 3,       # retry x times to connect
      'retry_interval'              => 1,       # retry after x seconds
    # tls options
      'cert'                        => undef,
      'key'                         => undef,
      'ca_file'                     => undef,
      'verify'                      => undef,
    };

    my %old_key = (
                    line_seperator         => 'line_separator',
                    column_seperator       => 'column_separator',
                    list_seperator         => 'list_separator',
                    host_service_seperator => 'host_service_separator',
                  );

    # previous versions had spelling errors in the key name
    for my $opt_key (keys %old_key) {
        if(exists $options{$opt_key}) {
            my $value = $options{$opt_key};
            $options{ $old_key{$opt_key} } = $value;
            delete $options{$opt_key};
        }
    }

    for my $opt_key (keys %options) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options{$opt_key};
        }
        else {
            confess("unknown option: $opt_key");
        }
    }

    if($self->{'verbose'} && !defined $self->{'logger'}) {
        confess('please specify a logger object when using verbose mode');
    }

    # setting a general timeout?
    if(defined $self->{'timeout'}) {
        $self->{'query_timeout'}   = $self->{'timeout'};
        $self->{'connect_timeout'} = $self->{'timeout'};
    }

    bless $self, $class;

    # set our peer(s) from the options
    my $peer = $self->_get_peer();

    if(!defined $self->{'backend'}) {
        $options{'name'} = $peer->{'name'};
        $options{'peer'} = $peer->{'peer'};
        if($peer->{'type'} eq 'UNIX') {
            $self->{'CONNECTOR'} = Monitoring::Livestatus::UNIX->new(%options);
        }
        elsif($peer->{'type'} eq 'INET') {
            $self->{'CONNECTOR'} = Monitoring::Livestatus::INET->new(%options);
        }
        $self->{'peer'} = $peer->{'peer'};
    }

    # set names and peer for non multi backends
    if(defined $self->{'CONNECTOR'}->{'name'} && !defined $self->{'name'}) {
        $self->{'name'} = $self->{'CONNECTOR'}->{'name'};
    }
    if(defined $self->{'CONNECTOR'}->{'peer'} && !defined $self->{'peer'}) {
        $self->{'peer'} = $self->{'CONNECTOR'}->{'peer'};
    }

    return $self;
}


########################################

=head1 METHODS

=head2 do

 do($statement)
 do($statement, %opts)

Send a single statement without fetching the result.
Always returns true.

=cut

sub do {
    my($self, $statement, $opt) = @_;
    $self->_send($statement, $opt);
    return(1);
}


########################################

=head2 selectall_arrayref

 selectall_arrayref($statement)
 selectall_arrayref($statement, %opts)
 selectall_arrayref($statement, %opts, $limit )

Sends a query and returns an array reference of arrays

    my $arr_refs = $ml->selectall_arrayref("GET hosts");

to get an array of hash references do something like

    my $hash_refs = $ml->selectall_arrayref(
      "GET hosts", { Slice => {} }
    );

to get an array of hash references from the first 2 returned rows only

    my $hash_refs = $ml->selectall_arrayref(
      "GET hosts", { Slice => {} }, 2
    );

you may use limit to limit the result to this number of rows

column aliases can be defined with a rename hash

    my $hash_refs = $ml->selectall_arrayref(
      "GET hosts", {
        Slice => {},
        rename => {
          'name' => 'host_name'
        }
      }
    );

=cut

sub selectall_arrayref {
    my($self, $statement, $opt, $limit, $result) = @_;
    $limit = 0 unless defined $limit;

    # make opt hash keys lowercase
    $opt = &_lowercase_and_verify_options($self, $opt) unless $result;

    $self->_log_statement($statement, $opt, $limit) if !$result && $self->{'verbose'};

    if(!defined $result) {
        $result = &_send($self, $statement, $opt);

        if(!defined $result) {
            return unless $self->{'errors_are_fatal'};
            confess("got undef result for: $statement");
        }
    }

    # trim result set down to excepted row count
    if(!$opt->{'offset'} && defined $limit && $limit >= 1) {
        if(scalar @{$result->{'result'}} > $limit) {
            @{$result->{'result'}} = @{$result->{'result'}}[0..$limit-1];
        }
    }

    if($opt->{'slice'}) {
        my $callbacks = $opt->{'callbacks'};
        # make an array of hashes, inplace to safe memory
        my $keys = $result->{'keys'};
        # renamed columns
        if($opt->{'rename'}) {
            $keys = dclone($result->{'keys'});
            my $keysize = scalar @{$keys};
            for(my $x=0; $x<$keysize;$x++) {
                my $old = $keys->[$x];
                if($opt->{'rename'}->{$old}) {
                    $keys->[$x] = $opt->{'rename'}->{$old};
                }
            }
        }
        $result  = $result->{'result'};
        my $rnum = scalar @{$result};
        for(my $x=0;$x<$rnum;$x++) {
            # sort array into hash slices
            my %hash;
            @hash{@{$keys}} = @{$result->[$x]};
            # add callbacks
            if($callbacks) {
                for my $key (keys %{$callbacks}) {
                    $hash{$key} = $callbacks->{$key}->(\%hash);
                }
            }
            $result->[$x] = \%hash;
        }
        return($result);
    }

    if(exists $opt->{'callbacks'}) {
        for my $res (@{$result->{'result'}}) {
            # add callbacks
            if(exists $opt->{'callbacks'}) {
                for my $key (keys %{$opt->{'callbacks'}}) {
                    push @{$res}, $opt->{'callbacks'}->{$key}->($res);
                }
            }
        }

        for my $key (keys %{$opt->{'callbacks'}}) {
            push @{$result->{'keys'}}, $key;
        }
    }
    return($result->{'result'});
}


########################################

=head2 selectall_hashref

 selectall_hashref($statement, $key_field)
 selectall_hashref($statement, $key_field, %opts)

Sends a query and returns a hashref with the given key

    my $hashrefs = $ml->selectall_hashref("GET hosts", "name");

=cut

sub selectall_hashref {
    my($self, $statement, $key_field, $opt) = @_;

    $opt = &_lowercase_and_verify_options($self, $opt);

    $opt->{'slice'} = 1;

    confess('key is required for selectall_hashref') if !defined $key_field;

    my $result = $self->selectall_arrayref($statement, $opt);

    my %indexed;
    for my $row (@{$result}) {
        if($key_field eq '$peername') {
            $indexed{$self->peer_name} = $row;
        }
        elsif(!defined $row->{$key_field}) {
            my %possible_keys = keys %{$row};
            confess("key $key_field not found in result set, possible keys are: ".join(', ', sort keys %possible_keys));
        } else {
            $indexed{$row->{$key_field}} = $row;
        }
    }
    return(\%indexed);
}


########################################

=head2 selectcol_arrayref

 selectcol_arrayref($statement)
 selectcol_arrayref($statement, %opt )

Sends a query an returns an arrayref for the first columns

    my $array_ref = $ml->selectcol_arrayref("GET hosts\nColumns: name");

    $VAR1 = [
              'localhost',
              'gateway',
            ];

returns an empty array if nothing was found

to get a different column use this

    my $array_ref = $ml->selectcol_arrayref(
       "GET hosts\nColumns: name contacts",
       { Columns => [2] }
    );

 you can link 2 columns in a hash result set

    my %hash = @{
      $ml->selectcol_arrayref(
        "GET hosts\nColumns: name contacts",
        { Columns => [1,2] }
      )
    };

produces a hash with host the contact assosiation

    $VAR1 = {
              'localhost' => 'user1',
              'gateway'   => 'user2'
            };

=cut

sub selectcol_arrayref {
    my($self, $statement, $opt) = @_;

    # make opt hash keys lowercase
    $opt = &_lowercase_and_verify_options($self, $opt);

    # if now colums are set, use just the first one
    if(!defined $opt->{'columns'} || ref $opt->{'columns'} ne 'ARRAY') {
        @{$opt->{'columns'}} = qw{1};
    }

    my $result = $self->selectall_arrayref($statement);

    my @column;
    for my $row (@{$result}) {
        for my $nr (@{$opt->{'columns'}}) {
            push @column, $row->[$nr-1];
        }
    }
    return(\@column);
}


########################################

=head2 selectrow_array

 selectrow_array($statement)
 selectrow_array($statement, %opts)

Sends a query and returns an array for the first row

    my @array = $ml->selectrow_array("GET hosts");

returns undef if nothing was found

=cut
sub selectrow_array {
    my($self, $statement, $opt) = @_;

    # make opt hash keys lowercase
    $opt = &_lowercase_and_verify_options($self, $opt);

    my @result = @{$self->selectall_arrayref($statement, $opt, 1)};
    return @{$result[0]} if scalar @result > 0;
    return;
}


########################################

=head2 selectrow_arrayref

 selectrow_arrayref($statement)
 selectrow_arrayref($statement, %opts)

Sends a query and returns an array reference for the first row

    my $arrayref = $ml->selectrow_arrayref("GET hosts");

returns undef if nothing was found

=cut
sub selectrow_arrayref {
    my($self, $statement, $opt) = @_;

    # make opt hash keys lowercase
    $opt = &_lowercase_and_verify_options($self, $opt);

    my $result = $self->selectall_arrayref($statement, $opt, 1);
    return if !defined $result;
    return $result->[0] if scalar @{$result} > 0;
    return;
}


########################################

=head2 selectrow_hashref

 selectrow_hashref($statement)
 selectrow_hashref($statement, %opt)

Sends a query and returns a hash reference for the first row

    my $hashref = $ml->selectrow_hashref("GET hosts");

returns undef if nothing was found

=cut
sub selectrow_hashref {
    my($self, $statement, $opt) = @_;

    # make opt hash keys lowercase
    $opt = &_lowercase_and_verify_options($self, $opt);
    $opt->{slice} = 1;

    my $result = $self->selectall_arrayref($statement, $opt, 1);
    return if !defined $result;
    return $result->[0] if scalar @{$result} > 0;
    return;
}


########################################

=head2 selectscalar_value

 selectscalar_value($statement)
 selectscalar_value($statement, %opt)

Sends a query and returns a single scalar

    my $count = $ml->selectscalar_value("GET hosts\nStats: state = 0");

returns undef if nothing was found

=cut
sub selectscalar_value {
    my($self, $statement, $opt) = @_;

    # make opt hash keys lowercase
    $opt = &_lowercase_and_verify_options($self, $opt);

    my $row = $self->selectrow_arrayref($statement);
    return if !defined $row;
    return $row->[0] if scalar @{$row} > 0;
    return;
}

########################################

=head2 errors_are_fatal

 errors_are_fatal()
 errors_are_fatal($value)

Enable or disable fatal errors. When enabled the module will confess on any error.

returns the current setting if called without new value

=cut
sub errors_are_fatal {
    my($self, $value) = @_;
    my $old   = $self->{'errors_are_fatal'};

    $self->{'errors_are_fatal'}                = $value;
    $self->{'CONNECTOR'}->{'errors_are_fatal'} = $value if defined $self->{'CONNECTOR'};

    return $old;
}

########################################

=head2 warnings

 warnings()
 warnings($value)

Enable or disable warnings. When enabled the module will carp on warnings.

returns the current setting if called without new value

=cut
sub warnings {
    my($self, $value) = @_;
    my $old   = $self->{'warnings'};

    $self->{'warnings'}                = $value;
    $self->{'CONNECTOR'}->{'warnings'} = $value if defined $self->{'CONNECTOR'};

    return $old;
}



########################################

=head2 verbose

 verbose()
 verbose($values)

Enable or disable verbose output. When enabled the module will dump out debug output

returns the current setting if called without new value

=cut
sub verbose {
    my($self, $value) = @_;
    my $old   = $self->{'verbose'};

    $self->{'verbose'}                = $value;
    $self->{'CONNECTOR'}->{'verbose'} = $value if defined $self->{'CONNECTOR'};

    return $old;
}


########################################

=head2 peer_addr

 $ml->peer_addr()

returns the current peer address

when using multiple backends, a list of all addresses is returned in list context

=cut
sub peer_addr {
    my($self) = @_;
    return ''.$self->{'peer'};
}


########################################

=head2 peer_name

 $ml->peer_name()
 $ml->peer_name($string)

if new value is set, name is set to this value

always returns the current peer name

when using multiple backends, a list of all names is returned in list context

=cut
sub peer_name {
    my($self, $value) = @_;

    if(defined $value and $value ne '') {
        $self->{'name'} = $value;
    }

    return ''.$self->{'name'};
}


########################################

=head2 peer_key

 $ml->peer_key()

returns a uniq key for this peer

=cut
sub peer_key {
    my($self) = @_;
    return $self->{'key'};
}

########################################
# INTERNAL SUBS
########################################
sub _send {
    my($self, $statement, $opt) = @_;

    confess('duplicate data') if $opt->{'data'};

    delete $self->{'meta_data'};

    my $header = '';
    my $keys;

    $Monitoring::Livestatus::ErrorCode = 0;
    undef $Monitoring::Livestatus::ErrorMessage;

    return(490, $self->_get_error(490), undef) if !defined $statement;
    chomp($statement);

    my($status,$msg,$body);
    if($statement =~ m/^Separators:/mx) {
        $status = 492;
        $msg    = $self->_get_error($status);
    }

    elsif($statement =~ m/^KeepAlive:/mx) {
        $status = 496;
        $msg    = $self->_get_error($status);
    }

    elsif($statement =~ m/^ResponseHeader:/mx) {
        $status = 495;
        $msg    = $self->_get_error($status);
    }

    elsif($statement =~ m/^ColumnHeaders:/mx) {
        $status = 494;
        $msg    = $self->_get_error($status);
    }

    elsif($statement =~ m/^OuputFormat:/mx) {
        $status = 493;
        $msg    = $self->_get_error($status);
    }

    # should be cought in mlivestatus directly
    elsif($statement =~ m/^Limit:\ (.*)$/mx and $1 !~ m/^\d+$/mx) {
        $status = 403;
        $msg    = $self->_get_error($status);
    }
    elsif($statement =~ m/^GET\ (.*)$/mx and $1 =~ m/^\s*$/mx) {
        $status = 403;
        $msg    = $self->_get_error($status);
    }

    elsif($statement =~ m/^Columns:\ (.*)$/mx and ($1 =~ m/,/mx or $1 =~ /^\s*$/mx)) {
        $status = 405;
        $msg    = $self->_get_error($status);
    }
    elsif($statement !~ m/^GET\ /mx and $statement !~ m/^COMMAND\ /mx) {
        $status = 401;
        $msg    = $self->_get_error($status);
    }

    else {

        # Add Limits header
        if(defined $opt->{'limit_start'}) {
            $statement .= "\nLimit: ".($opt->{'limit_start'} + $opt->{'limit_length'});
        }

        # for querys with column header, no seperate columns will be returned
        if($statement =~ m/^Columns:\ (.*)$/mx) {
            ($statement,$keys) = $self->_extract_keys_from_columns_header($statement);
        } elsif($statement =~ m/^Stats:\ (.*)$/mx or $statement =~ m/^StatsGroupBy:\ (.*)$/mx) {
            ($statement,$keys) = extract_keys_from_stats_statement($statement);
        }

        # Offset header (currently naemon only)
        if(defined $opt->{'offset'}) {
            $statement .= "\nOffset: ".$opt->{'offset'};
        }

        # Sort header (currently naemon only)
        if(defined $opt->{'sort'}) {
            for my $sort (@{$opt->{'sort'}}) {
                $statement .= "\nSort: ".$sort;
            }
        }

        # Commands need no additional header
        if($statement !~ m/^COMMAND/mx) {
            if($opt->{'wrapped_json'}) {
                $header .= "OutputFormat: wrapped_json\n";
            } else {
                $header .= "OutputFormat: json\n";
            }
            $header .= "ResponseHeader: fixed16\n";
            if($self->{'keepalive'}) {
                $header .= "KeepAlive: on\n";
            }
            # remove empty lines from statement
            $statement =~ s/\n+/\n/gmx;
        }

        # add additional headers
        if(defined $opt->{'header'} and ref $opt->{'header'} eq 'HASH') {
            for my $key ( keys %{$opt->{'header'}}) {
                $header .= $key.': '.$opt->{'header'}->{$key}."\n";
            }
        }

        chomp($statement);
        my $send = "$statement\n$header";
        $self->{'logger'}->debug('> '.Dumper($send)) if $self->{'verbose'};
        ($status,$msg,$body) = &_send_socket($self, $send);
        if($self->{'verbose'}) {
            #$self->{'logger'}->debug("got:");
            #$self->{'logger'}->debug(Dumper(\@erg));
            $self->{'logger'}->debug('status: '.Dumper($status));
            $self->{'logger'}->debug('msg:    '.Dumper($msg));
            $self->{'logger'}->debug('< '.Dumper($body));
        }
    }

    if(!$status || $status >= 300) {
        $body   = ''  if !defined $body;
        $status = 300 if !defined $status;
        chomp($body);
        $Monitoring::Livestatus::ErrorCode    = $status;
        if(defined $body and $body ne '') {
            $Monitoring::Livestatus::ErrorMessage = $body;
        } else {
            $Monitoring::Livestatus::ErrorMessage = $msg;
        }
        $self->{'logger'}->error($status.' - '.$Monitoring::Livestatus::ErrorMessage." in query:\n".$statement) if $self->{'verbose'};
        if($self->{'errors_are_fatal'}) {
            confess('ERROR '.$status.' - '.$Monitoring::Livestatus::ErrorMessage." in query:\n".$statement."\n");
        }
        return;
    }

    # return a empty result set if nothing found
    return({ keys => [], result => []}) if !defined $body;

    my $limit_start = 0;
    if(defined $opt->{'limit_start'}) { $limit_start = $opt->{'limit_start'}; }
    # body is already parsed
    my $result;
    if($status == 200) {
        $result = $body;
    } else {
        my $json_decoder = Cpanel::JSON::XS->new->utf8->relaxed;
        # fix json output
        eval {
            $result = $json_decoder->decode($body);
        };
        # fix low/high surrogate errors
        # missing high surrogate character in surrogate pair
        # surrogate pair expected
        if($@) {
            # replace u+D800 to u+DFFF (reserved utf-16 low/high surrogates)
            $body =~ s/\\ud[89a-f]\w{2}/\\ufffd/gmxi;
            eval {
                $result = $json_decoder->decode($body);
            };
        }
        if($@) {
            my $message = 'ERROR '.$@." in text: '".$body."'\" for statement: '$statement'\n";
            $self->{'logger'}->error($message) if $self->{'verbose'};
            if($self->{'errors_are_fatal'}) {
                confess($message);
            }
            return({ keys => [], result => []});
        }
    }
    if(!defined $result) {
        my $message = "ERROR undef result for text: '".$body."'\" for statement: '$statement'\n";
        $self->{'logger'}->error($message) if $self->{'verbose'};
        if($self->{'errors_are_fatal'}) {
            confess($message);
        }
        return({ keys => [], result => []});
    }

    # for querys with column header, no separate columns will be returned
    if(!defined $keys) {
        $self->{'logger'}->warn('got statement without Columns: header!') if $self->{'verbose'};
        if($self->{'warnings'}) {
            carp('got statement without Columns: header! -> '.$statement);
        }
        $keys = shift @{$result};
    }

    return(&post_processing($self, $result, $opt, $keys));
}

########################################

=head2 post_processing

 $ml->post_processing($result, $options, $keys)

returns postprocessed result.

Useful when using select based io.

=cut
sub post_processing {
    my($self, $result, $opt, $keys) = @_;

    my $orig_result;
    if($opt->{'wrapped_json'}) {
        $orig_result = $result;
        $result = $result->{'data'};
    }

    # add peer information?
    my $with_peers = 0;
    if(defined $opt->{'addpeer'} and $opt->{'addpeer'}) {
        $with_peers = 1;
    }

    if(defined $with_peers and $with_peers == 1) {
        my $peer_name = $self->peer_name;
        my $peer_addr = $self->peer_addr;
        my $peer_key  = $self->peer_key;

        unshift @{$keys}, 'peer_name';
        unshift @{$keys}, 'peer_addr';
        unshift @{$keys}, 'peer_key';

        for my $row (@{$result}) {
            unshift @{$row}, $peer_name;
            unshift @{$row}, $peer_addr;
            unshift @{$row}, $peer_key;
        }
    }

    # set some metadata
    $self->{'meta_data'} = {
        'result_count' => scalar @{$result},
    };
    if($opt->{'wrapped_json'}) {
        for my $key (keys %{$orig_result}) {
            next if $key eq 'data';
            $self->{'meta_data'}->{$key} = $orig_result->{$key};
        }
    }

    return({ keys => $keys, result => $result });
}

########################################
sub _open {
    my($self) = @_;

    # return the current socket in keep alive mode
    if($self->{'keepalive'} and defined $self->{'sock'} and $self->{'sock'}->connected) {
        $self->{'logger'}->debug('reusing old connection') if $self->{'verbose'};
        return($self->{'sock'});
    }

    my $sock = $self->{'CONNECTOR'}->_open();

    # store socket for later retrieval
    if($self->{'keepalive'}) {
        $self->{'sock'} = $sock;
    }

    $self->{'logger'}->debug('using new connection') if $self->{'verbose'};
    return($sock);
}

########################################
sub _close {
    my($self) = @_;
    my $sock = delete $self->{'sock'};
    return($self->{'CONNECTOR'}->_close($sock));
}

########################################

=head1 QUERY OPTIONS

In addition to the normal query syntax from the livestatus addon, it is
possible to set column aliases in various ways.

=head2 AddPeer

adds the peers name, addr and key to the result set:

 my $hosts = $ml->selectall_hashref(
   "GET hosts\nColumns: name alias state",
   "name",
   { AddPeer => 1 }
 );

=head2 Backend

send the query only to some specific backends. Only
useful when using multiple backends.

 my $hosts = $ml->selectall_arrayref(
   "GET hosts\nColumns: name alias state",
   { Backends => [ 'key1', 'key4' ] }
 );

=head2 Columns

    only return the given column indexes

    my $array_ref = $ml->selectcol_arrayref(
       "GET hosts\nColumns: name contacts",
       { Columns => [2] }
    );

  see L<selectcol_arrayref> for more examples

=head2 Deepcopy

    deep copy/clone the result set.

    Only effective when using multiple backends and threads.
    This can be safely turned off if you don't change the
    result set.
    If you get an error like "Invalid value for shared scalar" error" this
    should be turned on.

    my $array_ref = $ml->selectcol_arrayref(
       "GET hosts\nColumns: name contacts",
       { Deepcopy => 1 }
    );

=head2 Limit

    Just like the Limit: <nr> option from livestatus itself.
    In addition you can add a start,length limit.

    my $array_ref = $ml->selectcol_arrayref(
       "GET hosts\nColumns: name contacts",
       { Limit => "10,20" }
    );

    This example will return 20 rows starting at row 10. You will
    get row 10-30.

    Cannot be combined with a Limit inside the query
    because a Limit will be added automatically.

    Adding a limit this way will greatly increase performance and
    reduce memory usage.

    This option is multibackend safe contrary to the "Limit: " part of a statement.
    Sending a statement like "GET...Limit: 10" with 3 backends will result in 30 rows.
    Using this options, you will receive only the first 10 rows.

=head2 Rename

  see L<COLUMN ALIAS> for detailed explainaton

=head2 Slice

  see L<selectall_arrayref> for detailed explainaton

=head2 Sum

The Sum option only applies when using multiple backends.
The values from all backends with be summed up to a total.

 my $stats = $ml->selectrow_hashref(
   "GET hosts\nStats: state = 0\nStats: state = 1",
   { Sum => 1 }
 );

=cut


########################################
# wrapper around _send_socket_do
sub _send_socket {
    my($self, $statement) = @_;

    my $retries = 0;
    my($status, $msg, $recv, $sock);

    # closing a socket sends SIGPIPE to reader
    # https://riptutorial.com/posix/example/17424/handle-sigpipe-generated-by-write---in-a-thread-safe-manner
    local $SIG{PIPE} = 'IGNORE';

    # try to avoid connection errors
    eval {
        if($self->{'retries_on_connection_error'} <= 0) {
            ($sock, $msg, $recv) = &_send_socket_do($self, $statement);
            return($sock, $msg, $recv) if $msg;
            ($status, $msg, $recv) = &_read_socket_do($self, $sock, $statement);
            return($status, $msg, $recv);
        }

        while((!defined $status || ($status == 491 || $status == 497 || $status == 500)) && $retries < $self->{'retries_on_connection_error'}) {
            $retries++;
            ($sock, $msg, $recv) = &_send_socket_do($self, $statement);
            return($status, $msg, $recv) if $msg;
            ($status, $msg, $recv) = &_read_socket_do($self, $sock, $statement);
            $self->{'logger'}->debug('query status '.$status) if $self->{'verbose'};
            if($status == 491 or $status == 497 or $status == 500) {
                $self->{'logger'}->debug('got status '.$status.' retrying in '.$self->{'retry_interval'}.' seconds') if $self->{'verbose'};
                $self->_close();
                sleep($self->{'retry_interval'}) if $retries < $self->{'retries_on_connection_error'};
            }
        }
    };
    if($@) {
        $self->{'logger'}->debug("try 1 failed: $@") if $self->{'verbose'};
        if(defined $@ and $@ =~ /broken\ pipe/mx) {
            ($sock, $msg, $recv) = &_send_socket_do($self, $statement);
            return($status, $msg, $recv) if $msg;
            return(&_read_socket_do($self, $sock, $statement));
        }
        confess($@) if $self->{'errors_are_fatal'};
    }

    $status = $sock unless $status;
    $msg =~ s/^$status:\s+//gmx;
    confess($status.": ".$msg) if($status >= 400 and $self->{'errors_are_fatal'});

    return($status, $msg, $recv);
}

########################################
sub _send_socket_do {
    my($self, $statement) = @_;
    my $sock = $self->_open() or return(491, $self->_get_error(491, $@ || $!), $@ || $!);
    utf8::decode($statement);
    utf8::encode($statement);
    print $sock $statement or return($self->_socket_error($statement, $sock, 'write to socket failed: '.($@ || $!)));
    print $sock "\n";
    return $sock;
}

########################################
sub _read_socket_do {
    my($self, $sock, $statement) = @_;
    my($recv,$header);

    # COMMAND statements might return a error message
    if($statement && $statement =~ m/^COMMAND/mx) {
        shutdown($sock, 1);
        my $s = IO::Select->new();
        $s->add($sock);
        if($s->can_read(0.5)) {
            $recv = <$sock>;
        }
        if($recv) {
            chomp($recv);
            if($recv =~ m/^(\d+):\s*(.*)$/mx) {
                return($1, $recv, undef);
            }
            return('400', $self->_get_error(400), $recv);
        }
        return('200', $self->_get_error(200), undef);
    }

    $sock->read($header, 16) or return($self->_socket_error($statement, $sock, 'reading header from socket failed, check your livestatus logfile: '.$!));
    $self->{'logger'}->debug("header: $header") if $self->{'verbose'};
    my($status, $msg, $content_length) = &_parse_header($self, $header, $sock);
    return($status, $msg, undef) if !defined $content_length;
    our $json_decoder;
    if($json_decoder) {
        $json_decoder->incr_reset;
    } else {
        $json_decoder = Cpanel::JSON::XS->new->utf8->relaxed;
    }
    if($content_length > 0) {
        if($status == 200) {
            my $remaining = $content_length;
            my $length    = 32768;
            if($remaining < $length) { $length = $remaining; }
            while($length > 0 && $sock->read(my $buf, $length)) {
                # replace u+D800 to u+DFFF (reserved utf-16 low/high surrogates)
                $buf =~ s/\\ud[89a-f]\w{2}/\\ufffd/gmxio;
                $json_decoder->incr_parse($buf);
                $remaining = $remaining -$length;
                if($remaining < $length) { $length = $remaining; }
            }
            $recv = $json_decoder->incr_parse or return($self->_socket_error($statement, $sock, 'reading remaining '.$length.' bytes from socket failed: '.$!));
            $json_decoder->incr_reset;
        } else {
            $sock->read($recv, $content_length) or return($self->_socket_error($statement, $sock, 'reading body from socket failed'));
        }
    }

    $self->_close() unless $self->{'keepalive'};
    if($status >= 400 && $recv) {
        $msg .= ' - '.$recv;
    }
    return($status, $msg, $recv);
}

########################################
sub _socket_error {
    #my($self, $statement, $sock, $body)...
    my($self, $statement, undef, $body) = @_;

    my $message = "\n";
    $message   .= "peer                ".Dumper($self->peer_name);
    $message   .= "statement           ".Dumper($statement);
    $message   .= "message             ".Dumper($body);

    $self->{'logger'}->error($message) if $self->{'verbose'};

    if($self->{'retries_on_connection_error'} <= 0) {
        if($self->{'errors_are_fatal'}) {
            confess($message);
        }
        else {
            carp($message);
        }
    }
    $self->_close();
    return(500, $self->_get_error(500), $message);
}

########################################
sub _parse_header {
    my($self, $header, $sock) = @_;

    if(!defined $header) {
        return(497, $self->_get_error(497), undef);
    }

    my $headerlength = length($header);
    if($headerlength != 16) {
        return(498, $self->_get_error(498)."\ngot: ".$header.<$sock>, undef);
    }
    chomp($header);

    my $status         = substr($header,0,3);
    my $content_length = substr($header,5);
    if($content_length !~ m/^\s*(\d+)$/mx) {
        return(499, $self->_get_error(499)."\ngot: ".$header.<$sock>, undef);
    } else {
        $content_length = $1;
    }

    return($status, $self->_get_error($status), $content_length);
}

########################################

=head1 COLUMN ALIAS

In addition to the normal query syntax from the livestatus addon, it is
possible to set column aliases in various ways.

A valid Columns: Header could look like this:

 my $hosts = $ml->selectall_arrayref(
   "GET hosts\nColumns: state as status"
 );

Stats queries could be aliased too:

 my $stats = $ml->selectall_arrayref(
   "GET hosts\nStats: state = 0 as up"
 );

This syntax is available for: Stats, StatsAnd, StatsOr and StatsGroupBy


An alternative way to set column aliases is to define rename option key/value
pairs:

 my $hosts = $ml->selectall_arrayref(
   "GET hosts\nColumns: name", {
     rename => { 'name' => 'hostname' }
   }
 );

=cut

########################################

=head2 extract_keys_from_stats_statement

 extract_keys_from_stats_statement($statement)

Extract column keys from statement.

=cut
sub extract_keys_from_stats_statement {
    my($statement) = @_;

    my(@header, $new_statement);

    for my $line (split/\n/mx, $statement) {
        if(substr($line, 0, 5) ne 'Stats') { # faster shortcut for non-stats lines
            $new_statement .= $line."\n";
            next;
        }
        if($line =~ m/^Stats:\ (.*)\s+as\s+(.*?)$/mxo) {
            push @header, $2;
            $line = 'Stats: '.$1;
        }
        elsif($line =~ m/^Stats:\ (.*)$/mxo) {
            push @header, $1;
        }

        elsif($line =~ m/^StatsAnd:\ (\d+)\s+as\s+(.*?)$/mxo) {
            for(my $x = 0; $x < $1; $x++) {
                pop @header;
            }
            $line = 'StatsAnd: '.$1;
            push @header, $2;
        }
        elsif($line =~ m/^StatsAnd:\ (\d+)$/mxo) {
            my @to_join;
            for(my $x = 0; $x < $1; $x++) {
                unshift @to_join, pop @header;
            }
            push @header, join(' && ', @to_join);
        }

        elsif($line =~ m/^StatsOr:\ (\d+)\s+as\s+(.*?)$/mxo) {
            for(my $x = 0; $x < $1; $x++) {
                pop @header;
            }
            $line = 'StatsOr: '.$1;
            push @header, $2;
        }
        elsif($line =~ m/^StatsOr:\ (\d+)$/mxo) {
            my @to_join;
            for(my $x = 0; $x < $1; $x++) {
                unshift @to_join, pop @header;
            }
            push @header, join(' || ', @to_join);
        }

        # StatsGroupBy header are always sent first
        elsif($line =~ m/^StatsGroupBy:\ (.*)\s+as\s+(.*?)$/mxo) {
            unshift @header, $2;
            $line = 'StatsGroupBy: '.$1;
        }
        elsif($line =~ m/^StatsGroupBy:\ (.*)$/mxo) {
            unshift @header, $1;
        }
        $new_statement .= $line."\n";
    }

    return($new_statement, \@header);
}

########################################
sub _extract_keys_from_columns_header {
    my($self, $statement) = @_;

    my(@header, $new_statement);
    for my $line (split/\n/mx, $statement) {
        if($line =~ m/^Columns:\s+(.*)$/mx) {
            for my $column (split/\s+/mx, $1) {
                if($column eq 'as') {
                    pop @header;
                } else {
                    push @header, $column;
                }
            }
            $line =~ s/\s+as\s+([^\s]+)/\ /gmx;
        }
        $new_statement .= $line."\n";
    }

    return($new_statement, \@header);
}

########################################

=head1 ERROR HANDLING

Errorhandling can be done like this:

    use Monitoring::Livestatus;
    my $ml = Monitoring::Livestatus->new(
      socket => '/var/lib/livestatus/livestatus.sock'
    );
    $ml->errors_are_fatal(0);
    my $hosts = $ml->selectall_arrayref("GET hosts");
    if($Monitoring::Livestatus::ErrorCode) {
        confess($Monitoring::Livestatus::ErrorMessage);
    }

=cut
sub _get_error {
    my($self, $code, $append) = @_;

    my $codes = {
        '200' => 'OK. Reponse contains the queried data.',
        '201' => 'COMMANDs never return something',
        '400' => 'The request contains an invalid header.',
        '401' => 'The request contains an invalid header.',
        '402' => 'The request is completely invalid.',
        '403' => 'The request is incomplete.',
        '404' => 'The target of the GET has not been found (e.g. the table).',
        '405' => 'A non-existing column was being referred to',
        '413' => 'Maximum response size reached',
        '452' => 'internal livestatus error',
        '490' => 'no query',
        '491' => 'failed to connect',
        '492' => 'Separators not allowed in statement. Please use the separator options in new()',
        '493' => 'OuputFormat not allowed in statement. Header will be set automatically',
        '494' => 'ColumnHeaders not allowed in statement. Header will be set automatically',
        '495' => 'ResponseHeader not allowed in statement. Header will be set automatically',
        '496' => 'Keepalive not allowed in statement. Please use the keepalive option in new()',
        '497' => 'got no header',
        '498' => 'header is not exactly 16byte long',
        '499' => 'not a valid header (no content-length)',
        '500' => 'socket error',
        '502' => 'backend connection proxy error',
    };

    confess('non existant error code: '.$code) if !defined $codes->{$code};
    my $msg = $codes->{$code};
    $msg .= ' - '.$append if $append;

    return($msg);
}

########################################
sub _get_peer {
    my($self) = @_;

    # check if the supplied peer is a socket or a server address
    if(defined $self->{'peer'}) {
        if(ref $self->{'peer'} eq '') {
            my $name = $self->{'name'} || ''.$self->{'peer'};
            if(index($self->{'peer'}, ':') > 0) {
                return({ 'peer' => ''.$self->{'peer'}, type => 'INET', name => $name });
            } else {
                return({ 'peer' => ''.$self->{'peer'}, type => 'UNIX', name => $name });
            }
        }
        elsif(ref $self->{'peer'} eq 'ARRAY') {
            for my $peer (@{$self->{'peer'}}) {
                if(ref $peer eq 'HASH') {
                    next if !defined $peer->{'peer'};
                    $peer->{'name'} = ''.$peer->{'peer'} unless defined $peer->{'name'};
                    if(!defined $peer->{'type'}) {
                        $peer->{'type'} = 'UNIX';
                        if(index($peer->{'peer'}, ':') >= 0) {
                            $peer->{'type'} = 'INET';
                        }
                    }
                    return $peer;
                } else {
                    my $type = 'UNIX';
                    if(index($peer, ':') >= 0) {
                        $type = 'INET';
                    }
                    return({ 'peer' => ''.$peer, type => $type, name => ''.$peer });
                }
            }
        }
        elsif(ref $self->{'peer'} eq 'HASH') {
            for my $peer (keys %{$self->{'peer'}}) {
                my $name = $self->{'peer'}->{$peer};
                my $type = 'UNIX';
                if(index($peer, ':') >= 0) {
                    $type = 'INET';
                }
                return({ 'peer' => ''.$peer, type => $type, name => ''.$name });
            }
        } else {
            confess('type '.(ref $self->{'peer'}).' is not supported for peer option');
        }
    }
    if(defined $self->{'socket'}) {
        my $name = $self->{'name'} || ''.$self->{'socket'};
        return({ 'peer' => ''.$self->{'socket'}, type => 'UNIX', name => $name });
    }
    if(defined $self->{'server'}) {
        my $name = $self->{'name'} || ''.$self->{'server'};
        return({ 'peer' => ''.$self->{'server'}, type => 'INET', name => $name });
    }

    # check if we got a peer
    confess('please specify a peer');
}


########################################
sub _lowercase_and_verify_options {
    my($self, $opts) = @_;
    my $return = {};

    # make keys lowercase
    %{$return} = map { lc($_) => $opts->{$_} } keys %{$opts};

    if($self->{'warnings'}) {
        for my $key (keys %{$return}) {
            if(!defined $allowed_options->{$key}) {
                carp("unknown option used: $key - please use only: ".join(', ', keys %{$allowed_options}));
            }
        }
    }

    # set limits
    if(defined $return->{'limit'}) {
        if(index($return->{'limit'}, ',') != -1) {
            my($limit_start,$limit_length) = split /,/mx, $return->{'limit'};
            $return->{'limit_start'}  = $limit_start;
            $return->{'limit_length'} = $limit_length;
        }
        else {
            $return->{'limit_start'}  = 0;
            $return->{'limit_length'} = $return->{'limit'};
        }
        delete $return->{'limit'};
    }

    return($return);
}

########################################
sub _log_statement {
    my($self, $statement, $opt, $limit) = @_;
    my $d = Data::Dumper->new([$opt]);
    $d->Indent(0);
    my $optstring = $d->Dump;
    $optstring =~ s/^\$VAR1\s+=\s+//mx;
    $optstring =~ s/;$//mx;

    # remove empty lines from statement
    $statement =~ s/\n+/\n/gmx;

    my $cleanstatement = $statement;
    $cleanstatement =~ s/\n/\\n/gmx;
    $self->{'logger'}->debug('selectall_arrayref("'.$cleanstatement.'", '.$optstring.', '.$limit.')');
    return 1;
}

########################################

1;

=head1 SEE ALSO

For more information about the query syntax and the livestatus plugin installation
see the Livestatus page: http://mathias-kettner.de/checkmk_livestatus.html

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
