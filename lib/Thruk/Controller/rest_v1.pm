package Thruk::Controller::rest_v1;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::rest_v1 - Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=head2 index

=cut

use Module::Load qw/load/;
use File::Slurp qw/read_file/;
use Cpanel::JSON::XS ();
use Thruk::Backend::Manager ();

our $VERSION = 1;
our $rest_paths = [];

##########################################################
sub index {
    my($c, $path_info) = @_;

    $path_info =~ s#^/thruk/r/?##gmx;
    $path_info =~ s#^v1/?##gmx;
    $path_info =~ s#^/*#/#gmx;
    $path_info =~ s#^.+/$##gmx;

    my $format = 'json';
    if($path_info =~ m%^/csv(/.*)$%mx) {
        $path_info = $1;
        $format    = 'csv';
    }

    my $data = _process_rest_request($c, $path_info);
    return $data if $c->{'rendered'};

    if($format eq 'csv') {
        return(_format_csv_output($c, $data));
    }
    return($c->render(json => $data));
}

##########################################################
sub _process_rest_request {
    my($c, $path_info) = @_;

    my $data = _fetch($c, $path_info);

    # generic post processing
    eval {
        $data = _post_processing($c, $data);
    };
    if($@) {
        $data = { 'message' => 'error during request', description => $@, code => 500 };
    }

    if(!$data) {
        $data = { 'message' => sprintf("unknown rest path %s '%s'", $c->req->method, $path_info), code => 404 };
    }
    if(ref $data eq 'HASH') {
        $c->res->code($data->{'code'}) if $data->{'code'};
        if($data->{'code'}) {
            if($data->{'code'} > 400) {
                $data->{'failed'} = Cpanel::JSON::XS::true;
            }
        }
        return($data);
    }
    if(ref $data eq 'ARRAY') {
        return($data);
    }
    return({ 'message' => 'error during request', description => "returned data is of type '".(ref $data || 'text')."'", code => 500 });
}

##########################################################
sub _format_csv_output {
    my($c, $data) = @_;

    my $hash_columns;
    if(ref $data eq 'HASH') {
        $hash_columns = [qw/key value/];
        my $list = [];
        my $columns = [sort keys %{$data}];
        for my $col (@{$columns}) {
            push @{$list}, { key => $col, value => $data->{$col} };
        }
    }

    my $output;
    if(ref $data eq 'ARRAY') {
        my $columns = _get_request_columns($c) || ($data->[0] ? [sort keys %{$data->[0]}] : []);
        $output = "";
        for my $d (@{$data}) {
            my $x = 0;
            for my $col (@{$columns}) {
                $output .= ';' unless $x == 0;
                if(ref($d->{$col}) eq 'ARRAY') {
                    $output .= join(',', @{$d->{$col}});
                } else {
                    $output .= $d->{$col} // '';
                }
                $x++;
            }
            $output .= "\n";
        }
    }

    if(!defined $output) {
        $output .= "ERROR: failed to generate output, rerun with -v to get more details.\n";
    }

    $c->res->headers->content_type('text/plain');
    $c->stash->{'template'} = 'passthrough.tt';
    $c->stash->{'text'}     = $output;

    return;
}

##########################################################
sub _fetch {
    my($c, $path_info) = @_;
    $c->stats->profile(begin => "_fetch");

    # load plugin paths
    if(!$c->{config}->{'_rest_paths_loaded'}) {
        $c->{config}->{'_rest_paths_loaded'} = 1;
        my $input_files = [glob(join(" ", (
                            $c->config->{'plugin_path'}."/plugins-enabled/*/lib/Thruk/Controller/Rest/V1/*.pm",
                            $c->config->{'project_root'}."/lib/Thruk/Controller/Rest/V1/*.pm",
                        )))];
        for my $file (@{$input_files}) {
            my $pkg_name = $file;
            $pkg_name =~ s%^.*/lib/Thruk/Controller/Rest/V1/(.*?)\.pm%Thruk::Controller::Rest::V1::$1%gmx;
            eval {
                load $pkg_name;
            };
            if($@) {
                $c->log->error($@);
                return({ 'message' => 'error loading rest submodule', code => 500, 'description' => $@ });
            }

        }
    }

    my $data;
    my $found = 0;
    my $request_method = $c->req->method;
    my $protos = [];
    for my $r (@{$rest_paths}) {
        my($proto, $path, $function, $roles) = @{$r};
        if((ref $path eq '' && $path eq $path_info) || (ref $path eq 'Regexp' && $path_info =~ $path))  {
            if($proto ne $request_method) {
                push @{$protos}, $proto;
                next;
            }
            if($roles && !$c->user->check_user_roles($roles)) {
                $data = { 'message' => 'not authorized', 'description' => 'this path requires certain roles: '.join(', ', @{$roles}), code => 403 };
            } else {
                $data = &{$function}($c, $path_info, $1, $2, $3);
            }
            $found = 1;
            last;
        }
    }

    if($found) {
        if(!$data) {
            $data = { 'message' => 'rest path: '.$path_info.' did not return any data.', code => 500 };
        }
    } else {
        if(scalar @{$protos} > 0) {
            $data = { 'message' => 'bad request', description => 'available methods for '.$path_info.' are: '.join(', ', @{$protos}), code => 400 };
        } else {
            $data = { 'message' => 'unknown rest path: '.$path_info, code => 404 };
        }
    }

    $c->stats->profile(end => "_fetch");
    return $data;
}

##########################################################
sub _post_processing {
    my($c, $data) = @_;
    return unless $data;

    $c->stats->profile(begin => "_post_processing");

    # errors should not be post-processed
    if(ref $data eq 'HASH' && $data->{'code'} && $data->{'message'}) {
        return($data);
    }

    if(ref $data eq 'ARRAY') {
        # Filtering
        $data = _apply_filter($c, $data);

        # Sorting
        $data = _apply_sort($c, $data);

        # Offset
        my $offset = $c->req->parameters->{'offset'} || 0;
        if($offset) {
            if(scalar @{$data} <= $offset) { return([]); }
            splice(@{$data}, 0, $offset);
        }

        # Limit
        my $limit  = $c->req->parameters->{'limit'};
        if($limit && scalar @{$data} > $limit) {
            @{$data} = @{$data}[ 0 .. ($limit-1) ];
        }

        # Columns
        $data = _apply_columns($c, $data);
    }

    if(ref $data eq 'HASH') {
        # Columns
        $data = shift @{_apply_columns($c, [$data])};
    }

    $c->stats->profile(end => "_post_processing");
    return $data;
}

##########################################################
sub _get_filter {
    my($c) = @_;
    my $filter = [];

    for my $key (keys %{$c->req->parameters}) {
        next if $key eq 'limit';
        next if $key eq 'offset';
        next if $key eq 'sort';
        next if $key eq 'columns';
        my $op   = '=';
        my @vals = @{Thruk::Utils::list($c->req->parameters->{$key})};
        if($key =~ m/^(.+)\[(.*?)\]$/mx) {
            $key = $1;
            $op  = $2;
        }
        if(   $op eq 'eq')     { $op = '=';  }
        elsif($op eq 'ne')     { $op = '!='; }
        elsif($op eq 'regex')  { $op = '~';  }
        elsif($op eq 'nregex') { $op = '!~'; }
        elsif($op eq 'gt')     { $op = '>';  }
        elsif($op eq 'gte')    { $op = '>='; }
        elsif($op eq 'lt')     { $op = '<';  }
        elsif($op eq 'lte')    { $op = '<='; }
        for my $val (@vals) {
            $val = lc($val);
            push @{$filter}, [$key, $op, $val];
        }
    }
    return $filter;
}

##########################################################
sub _apply_filter {
    my($c, $data) = @_;

    for my $filter (@{_get_filter($c)}) {
        my($key, $op, $val) = @{$filter};

        ## no critic
        no warnings;
        ## use critic
        my @filtered;
        if($op eq '=') {
            for my $d (@{$data}) {
                next unless lc($d->{$key}) eq $val;
                push @filtered, $d;
            }
        }
        elsif($op eq '!=') {
            for my $d (@{$data}) {
                next unless lc($d->{$key}) ne $val;
                push @filtered, $d;
            }
        }
        elsif($op eq '~') {
            for my $d (@{$data}) {
                ## no critic
                next unless $d->{$key} =~ m/$val/i;
                ## use critic
                push @filtered, $d;
            }
        }
        elsif($op eq '!~') {
            for my $d (@{$data}) {
                ## no critic
                next unless $d->{$key} !~ m/$val/i;
                ## use critic
                push @filtered, $d;
            }
        }
        elsif($op eq '>') {
            for my $d (@{$data}) {
                next unless $d->{$key} > $val;
                push @filtered, $d;
            }
        }
        elsif($op eq '<') {
            for my $d (@{$data}) {
                next unless $d->{$key} < $val;
                push @filtered, $d;
            }
        }
        elsif($op eq '>=') {
            for my $d (@{$data}) {
                if(ref $d->{$key} eq 'ARRAY') {
                    my $found = 0;
                    for my $v (@{$d->{$key}}) {
                        if($v eq $val) {
                            $found = 1;
                            last;
                        }
                    }
                    if($found) {
                        push @filtered, $d;
                    }
                } else {
                    next unless $d->{$key} >= $val;
                    push @filtered, $d;
                }
            }
        }
        elsif($op eq '<=') {
            for my $d (@{$data}) {
                if(ref $d->{$key} eq 'ARRAY') {
                    my $found = 0;
                    for my $v (@{$d->{$key}}) {
                        if($v eq $val) {
                            $found = 1;
                        }
                    }
                    if(!$found) {
                        push @filtered, $d;
                    }
                } else {
                    next unless $d->{$key} <= $val;
                    push @filtered, $d;
                }
            }
        } else {
            die("unsupported operator: ".$op);
        }
        use warnings;

        $data = \@filtered;
    }

    return $data;
}

##########################################################
sub _get_request_columns {
    my($c) = @_;

    return unless $c->req->parameters->{'columns'};

    my $columns = [];
    for my $col (@{Thruk::Utils::list($c->req->parameters->{'columns'})}) {
        push @{$columns}, split(/\s*,\s*/mx, $col);
    }
    return($columns);
}

##########################################################
sub _apply_columns {
    my($c, $data) = @_;

    return $data unless $c->req->parameters->{'columns'};
    my $columns = _get_request_columns($c);

    my $res = [];
    for my $d (@{$data}) {
        my $row = {};
        for my $c (@{$columns}) {
            $row->{$c} = $d->{$c};
        }
        push @{$res}, $row;
    }

    return $res;
}

##########################################################
sub _apply_sort {
    my($c, $data) = @_;

    return $data unless $c->req->parameters->{'sort'};
    my $sort = [];
    for my $s (@{Thruk::Utils::list($c->req->parameters->{'sort'})}) {
        push @{$sort}, split(/\s*,\s*/mx, $s);
    }

    my @compares;
    for my $key (@{$sort}) {
        my $order = 'asc';
        if($key =~ m/^\-/mx) {
            $order = 'desc';
            $key =~ s/^\-//mx;
        }
        # sort numeric
        if( defined $data->[0]->{$key} and Thruk::Backend::Manager::looks_like_number($data->[0]->{$key}) ) {
            if($order eq 'asc') {
                push @compares, '$a->{"'.$key.'"} <=> $b->{"'.$key.'"}';
            } else {
                push @compares, '$b->{"'.$key.'"} <=> $a->{"'.$key.'"}';
            }
        }

        # sort alphanumeric
        else {
            if($order eq 'asc') {
                push @compares, '$a->{"'.$key.'"} cmp $b->{"'.$key.'"}';
            } else {
                push @compares, '$b->{"'.$key.'"} cmp $a->{"'.$key.'"}';
            }
        }
    }
    my $sortstring = join( ' || ', @compares );

    my @sorted;
    ## no critic
    no warnings;    # sorting by undef values generates lots of errors
    eval '@sorted = sort {'.$sortstring.'} @{$data};';
    use warnings;
    ## use critic

    if(scalar @sorted == 0 && $@) {
        confess($@);
    }

    return \@sorted;
}

##########################################################
sub _livestatus_filter {
    my($c) = @_;
    my $filter = [];
    # TODO: support ?limit=...
    for my $f (@{_get_filter($c)}) {
        my($key, $op, $val) = @{$f};
        push @{$filter}, { $key => { $op => $val }};
    }

    return $filter;
}

##########################################################

=head2 register_rest_path_v1

    register_rest_path_v1($protocol, $path|$regex, $function)

register rest path.

returns nothing

=cut
sub register_rest_path_v1 {
    my($proto, $path, $function, $roles) = @_;
    push @{$rest_paths}, [$proto, $path, $function, $roles];
    return;
}

##########################################################

=head2 get_rest_paths

    get_rest_paths([$c])

gather list of available rest paths. If $c is supplied, only enabled plugins
will be returned.

returns (path_hash, keys_hash, docs_hash)

=cut
sub get_rest_paths {
    my($c, $input_files) = @_;

    if($input_files) {
        # already set
    } elsif($c) {
        $input_files = [glob(join(" ", (
                            $c->config->{'project_root'}."/lib/Thruk/Controller/rest_v1.pm",
                            $c->config->{'plugin_path'}."/plugins-enabled/*/lib/Thruk/Controller/Rest/V1/*.pm",
                            $c->config->{'project_root'}."lib/Thruk/Controller/Rest/V1/*.pm",
                        )))];
    } else {
        $input_files = [glob("lib/Thruk/Controller/rest_v1.pm
                             plugins/plugins-available/*/lib/Thruk/Controller/Rest/V1/*.pm
                             lib/Thruk/Controller/Rest/V1/*.pm")];
    }

    my $paths = {};
    my $keys  = {};
    my $docs  = {};
    my $last_path;
    my $last_proto;
    my $in_comment = 0;
    for my $file (@{$input_files}) {
        for my $line (read_file($file)) {
            if($line =~ m%REST\ PATH:\ (\w+)\ (.*?)$%mx) {
                $last_path  = $2;
                $last_proto = $1;
                $paths->{$last_path}->{$last_proto} = 1;
                $in_comment = 1;
            }
            elsif($in_comment && $line =~ m%^\s*\#\s*(.*?)$%mx) {
                $docs->{$last_path}->{$last_proto} = [] unless $docs->{$last_path}->{$last_proto};
                push @{$docs->{$last_path}->{$last_proto}}, $1;
            }
            elsif($last_path && $line =~ m%([\w\_]+)\s+=>\s+.*\#\s+(.*)$%mx) {
                $keys->{$last_path}->{$last_proto} = [] unless $keys->{$last_path}->{$last_proto};
                push @{$keys->{$last_path}->{$last_proto}}, [$1, $2];
                $in_comment = 0;
            } else {
                $in_comment = 0;
            }
        }
    }
    return($paths, $keys, $docs);
}

##########################################################
sub _append_time_filter {
    my($c, $filter) = @_;
    for my $f (@{$filter}) {
        if($f->{'time'}) {
            return;
        }
    }
    push @{$filter}, { time => { '>=' => time() - 86400 } };
    return;
}

##########################################################
# REST PATH: GET /
# lists all available rest urls.
# alias for /index
# REST PATH: GET /index
# lists all available rest urls.
register_rest_path_v1('GET', '/',      \&_rest_get_index);
register_rest_path_v1('GET', '/index', \&_rest_get_index);
sub _rest_get_index {
    my($c) = @_;
    my($paths, $keys, $docs) = get_rest_paths($c);
    my $data = [];
    for my $path (sort keys %{$paths}) {
        for my $proto (sort keys %{$paths->{$path}}) {
            push @{$data}, {
                url         => $path,
                protocol    => $proto,
                description => $docs->{$path}->{$proto}->[0] || '',
            };
        }
    }
    return($data);
}

##########################################################
# REST PATH: GET /thruk
# hash of basic information about this thruk instance
register_rest_path_v1('GET', '/thruk', \&_rest_get_thruk);
sub _rest_get_thruk {
    my($c) = @_;
    return({
        rest_version        => $VERSION,                            # rest api version
        thruk_version       => $c->config->{'version'},             # thruk version
        thruk_branch        => $c->config->{'branch'},              # thruk branch name
        thruk_release_date  => $c->config->{'released'},            # thruk release date
        localtime           => time(),                              # current server unix timestamp / epoch
        project_root        => $c->config->{'project_root'},        # thruk root folder
        etc_path            => $c->config->{'etc_path'},            # configuration folder
        var_path            => $c->config->{'var_path'},            # variable data folder
    });
}

##########################################################
# REST PATH: GET /thruk/config
# lists configuration information
register_rest_path_v1('GET', '/thruk/config', \&_rest_get_thruk_config);
register_rest_path_v1('GET', '/thruk/config', \&_rest_get_thruk_config);
sub _rest_get_thruk_config {
    my($c) = @_;
    my $data = {};
    for my $key (keys %{$c->config}) {
        next if $key eq 'View::TT';
        $data->{$key} = $c->config->{$key};
    }
    return($data);
}

##########################################################
# REST PATH: GET /thruk/jobs
# lists thruk jobs.
register_rest_path_v1('GET', qr%^/thruk/jobs?$%mx, \&_rest_get_thruk_jobs);
sub _rest_get_thruk_jobs {
    my($c, undef, $job) = @_;
    require Thruk::Utils::External;

    my $data = [];
    for my $dir (glob($c->config->{'var_path'}."/jobs/*/.")) {
        if($dir =~ m%/([^/]+)/\.$%mx) {
            my $id = $1;
            next if $job && $job ne $id;
            push @{$data}, Thruk::Utils::External::read_job($c, $id);
        }
    }
    if($job) {
        if(!$data->[0]) {
            return({ 'message' => 'no such job', code => 404 });
        }
        $data = $data->[0];
    }
    return($data);
}

##########################################################
# REST PATH: GET /thruk/jobs/<id>
# get thruk job status for given id.
# alias for /thruk/jobs?id=<id>
register_rest_path_v1('GET', qr%^/thruk/jobs?/([^/]+)$%mx, \&_rest_get_thruk_jobs);

##########################################################
# REST PATH: GET /hosts
# lists livestatus hosts.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#hosts for details.
# there is an shortcut /hosts available.
register_rest_path_v1('GET', qr%/hosts?$%mx, \&_rest_get_livestatus_hosts);
sub _rest_get_livestatus_hosts {
    my($c) = @_;
    return($c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), _livestatus_filter($c) ] ));
}

##########################################################
# REST PATH: GET /hosts/stats
# hash of livestatus host statistics.
register_rest_path_v1('GET', qr%/hosts?/stats$%mx, \&_rest_get_livestatus_hosts_stats);
sub _rest_get_livestatus_hosts_stats {
    my($c) = @_;
    return($c->{'db'}->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), _livestatus_filter($c) ] ));
}

##########################################################
# REST PATH: GET /hosts/totals
# hash of livestatus host totals statistics.
# its basically a reduced set of /hosts/stats.
register_rest_path_v1('GET', qr%^/hosts?/totals$%mx, \&_rest_get_livestatus_hosts_totals);
sub _rest_get_livestatus_hosts_totals {
    my($c) = @_;
    return($c->{'db'}->get_host_totals_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), _livestatus_filter($c) ] ));
}

##########################################################
# REST PATH: GET /hosts/<name>/services
# lists services for given host.
# alias for /services?host_name=<name>
register_rest_path_v1('GET', qr%/hosts?/([^/]+)/services?$%mx, \&_rest_get_livestatus_hosts_services);
sub _rest_get_livestatus_hosts_services {
    my($c, undef, $host) = @_;
    return($c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), { 'host_name' => $host }, _livestatus_filter($c)  ] ));
}

##########################################################
# REST PATH: GET /hosts/<name>
# lists hosts for given name.
# alias for /hosts?name=<name>
register_rest_path_v1('GET', qr%/hosts?/([^/]+)/?$%mx, \&_rest_get_livestatus_hosts_by_name);
sub _rest_get_livestatus_hosts_by_name {
    my($c, undef, $host) = @_;
    return($c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), { "name" => $host }, _livestatus_filter($c) ] ));
}

##########################################################
# REST PATH: GET /hostgroups
# lists livestatus hostgroups.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#hostgroups for details.
register_rest_path_v1('GET', qr%^/hostgroups?$%mx, \&_rest_get_livestatus_hostgroups);
sub _rest_get_livestatus_hostgroups {
    my($c) = @_;
    return($c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups'), _livestatus_filter($c)  ] ));
}

##########################################################
# REST PATH: GET /services
# lists livestatus services.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#services for details.
# there is an alias /services.
register_rest_path_v1('GET', qr%^/services?$%mx, \&_rest_get_livestatus_services);
sub _rest_get_livestatus_services {
    my($c) = @_;
    return($c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), _livestatus_filter($c)  ] ));
}

##########################################################
# REST PATH: GET /services/stats
# livestatus service statistics.
register_rest_path_v1('GET', qr%^/services?/stats$%mx, \&_rest_get_livestatus_services_stats);
sub _rest_get_livestatus_services_stats {
    my($c) = @_;
    return($c->{'db'}->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), _livestatus_filter($c) ] ));
}

##########################################################
# REST PATH: GET /services/totals
# livestatus service totals statistics.
# its basically a reduced set of /services/stats.
register_rest_path_v1('GET', qr%^/services?/totals$%mx, \&_rest_get_livestatus_services_totals);
sub _rest_get_livestatus_services_totals {
    my($c) = @_;
    return($c->{'db'}->get_service_totals_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), _livestatus_filter($c) ] ));
}

##########################################################
# REST PATH: GET /servicegroups
# lists livestatus servicegroups.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#servicegroups for details.
register_rest_path_v1('GET', qr%^/servicegroups?$%mx, \&_rest_get_livestatus_servicegroups);
sub _rest_get_livestatus_servicegroups {
    my($c) = @_;
    return($c->{'db'}->get_servicegroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups'), _livestatus_filter($c)  ] ));
}

##########################################################
# REST PATH: GET /contacts
# lists livestatus contacts.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#contacts for details.
register_rest_path_v1('GET', qr%^/contacts?$%mx, \&_rest_get_livestatus_contacts);
sub _rest_get_livestatus_contacts {
    my($c) = @_;
    return($c->{'db'}->get_contacts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'contact'), _livestatus_filter($c)  ] ));
}

##########################################################
# REST PATH: GET /contactgroups
# lists livestatus contactgroups.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#contactgroups for details.
register_rest_path_v1('GET', qr%^/contactgroups?$%mx, \&_rest_get_livestatus_contactgroups);
sub _rest_get_livestatus_contactgroups {
    my($c) = @_;
    return($c->{'db'}->get_contactgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'contactgroups'), _livestatus_filter($c)  ] ));
}

##########################################################
# REST PATH: GET /timeperiods
# lists livestatus timeperiods.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#timeperiods for details.
register_rest_path_v1('GET', qr%^/timeperiods?$%mx, \&_rest_get_livestatus_timeperiods);
sub _rest_get_livestatus_timeperiods {
    my($c) = @_;
    return($c->{'db'}->get_timeperiods(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods'), _livestatus_filter($c)  ] ));
}

##########################################################
# REST PATH: GET /commands
# lists livestatus commands.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#commands for details.
register_rest_path_v1('GET', qr%^/commands?$%mx, \&_rest_get_livestatus_commands, ['admin']);
sub _rest_get_livestatus_commands {
    my($c) = @_;
    return($c->{'db'}->get_commands(filter => [_livestatus_filter($c)] ));
}

##########################################################
# REST PATH: GET /comments
# lists livestatus comments.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#comments for details.
register_rest_path_v1('GET', qr%^/comments?$%mx, \&_rest_get_livestatus_comments);
sub _rest_get_livestatus_comments {
    my($c) = @_;
    return($c->{'db'}->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), _livestatus_filter($c)  ] ));
}

##########################################################
# REST PATH: GET /downtimes
# lists livestatus downtimes.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#downtimes for details.
register_rest_path_v1('GET', qr%^/downtimes?$%mx, \&_rest_get_livestatus_downtimes);
sub _rest_get_livestatus_downtimes {
    my($c) = @_;
    return($c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'downtimes'), _livestatus_filter($c)  ] ));
}

##########################################################
# REST PATH: GET /logs
# lists livestatus logs.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#log for details.
register_rest_path_v1('GET', qr%^/logs?$%mx, \&_rest_get_livestatus_logs);
sub _rest_get_livestatus_logs {
    my($c) = @_;
    my $filter = _livestatus_filter($c);
    _append_time_filter($c, $filter);
    return($c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), $filter ] ));
}

##########################################################
# REST PATH: GET /notifications
# lists notifications based on logfiles.
# alias for /logs?class=3
register_rest_path_v1('GET', qr%^/notifications?$%mx, \&_rest_get_livestatus_notifications);
sub _rest_get_livestatus_notifications {
    my($c) = @_;
    my $filter = _livestatus_filter($c);
    _append_time_filter($c, $filter);
    return($c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), { class => 3 }, $filter ] ));
}

##########################################################
# REST PATH: GET /hosts/<name>/notifications
# lists notifications for given host.
# alias for /logs?class=3&host_name=<name>
register_rest_path_v1('GET', qr%^/hosts?/([^/]+)/notifications?$%mx, \&_rest_get_livestatus_host_notifications);
sub _rest_get_livestatus_host_notifications {
    my($c, undef, $host) = @_;
    my $filter = _livestatus_filter($c);
    _append_time_filter($c, $filter);
    return($c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), { class => 3, host_name => $host }, $filter ] ));
}

##########################################################
# REST PATH: GET /alerts
# lists alerts based on logfiles.
# alias for /logs?type[~]=^(HOST|SERVICE) ALERT
register_rest_path_v1('GET', qr%^/alerts?$%mx, \&_rest_get_livestatus_alerts);
sub _rest_get_livestatus_alerts {
    my($c) = @_;
    my $filter = _livestatus_filter($c);
    _append_time_filter($c, $filter);
    return($c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), { type => { '~' => '^(HOST|SERVICE) ALERT$' } }, $filter ] ));
}

##########################################################
# REST PATH: GET /hosts/<name>/alerts
# lists alerts for given host.
# alias for /logs?type[~]=^(HOST|SERVICE) ALERT&host_name=<name>
register_rest_path_v1('GET', qr%^/hosts?/([^/]+)/alerts?$%mx, \&_rest_get_livestatus_host_alerts);
sub _rest_get_livestatus_host_alerts {
    my($c, undef, $host) = @_;
    my $filter = _livestatus_filter($c);
    _append_time_filter($c, $filter);
    return($c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), { host_name => $host, type => { '~' => '^(HOST|SERVICE) ALERT$' } }, $filter ] ));
}

##########################################################
# REST PATH: GET /processinfo
# lists livestatus sites status.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#status for details.
register_rest_path_v1('GET', qr%^/processinfos?$%mx, \&_rest_get_livestatus_processinfos);
sub _rest_get_livestatus_processinfos {
    my($c) = @_;
    my $data = $c->{'db'}->get_processinfo(filter => [ _livestatus_filter($c) ] );
    $data = [values(%{$data})] if ref $data eq 'HASH';
    return($data);
}

##########################################################
# REST PATH: GET /processinfo/stats
# lists livestatus sites statistics.
# see https://www.naemon.org/documentation/usersguide/livestatus.html#status for details.
register_rest_path_v1('GET', qr%^/processinfos?/stats$%mx, \&_rest_get_livestatus_processinfos_stats);
sub _rest_get_livestatus_processinfos_stats {
    my($c) = @_;
    return($c->{'db'}->get_extra_perf_stats(filter => [ _livestatus_filter($c) ] ));
}

##########################################################
# REST PATH: GET /checks/stats
# lists host / service check statistics.
register_rest_path_v1('GET', qr%^/checks?/stats$%mx, \&_rest_get_livestatus_checks_stats);
sub _rest_get_livestatus_checks_stats {
    my($c) = @_;
    return($c->{'db'}->get_performance_stats(filter => [ _livestatus_filter($c) ] ));
}

##########################################################
# REST PATH: GET /lmd/sites
# lists connected sites. Only available if LMD (`use_lmd`) is enabled.
register_rest_path_v1('GET', qr%^/lmd/sites?$%mx, \&_rest_get_lmd_sites);
sub _rest_get_lmd_sites {
    my($c) = @_;
    my $data = [];
    if($c->config->{'use_lmd_core'}) {
        $data = $c->{'db'}->get_sites();
    }
    return($data);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
