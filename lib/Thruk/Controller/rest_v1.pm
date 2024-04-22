package Thruk::Controller::rest_v1;

use warnings;
use strict;
use Carp;
use Cpanel::JSON::XS ();
use Module::Load qw/load/;
use Time::HiRes ();
use URI::Escape qw/uri_unescape/;

use Thruk::Action::AddDefaults ();
use Thruk::Authentication::User ();
use Thruk::Backend::Manager ();
use Thruk::Backend::Provider::Livestatus ();
use Thruk::Constants ':backend_handling';
use Thruk::Utils::Auth ();
use Thruk::Utils::CookieAuth ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::Status ();

=head1 NAME

Thruk::Controller::rest_v1 - Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=head2 index

=cut


our $VERSION = 1;
our $rest_paths = [];

my $reserved_query_parameters  = [qw/limit offset sort columns headers backend backends q CSRFtoken/];
my $aggregation_function_names = [qw/count sum avg min max/];
my $op_translation_words       = {
    'eq'     => '=',
    'ne'     => '!=',
    'regex'  => '~~',
    'nregex' => '!~~',
    'gt'     => '>',
    'gte'    => '>=',
    'lt'     => '<',
    'lte'    => '<=',
    'notin'  => '!>=',
};

use constant {
    PRE_STATS    =>  1,
    POST_STATS   =>  2,

    ALIAS        =>  1,
    RAW          =>  2,
    NAMES        =>  3,
};

##########################################################
sub index {
    my($c, $path_info) = @_;

    $path_info =~ s#^/thruk/r/?##gmx;   # trim rest prefix
    $path_info =~ s#^v1/?##gmx;         # trim v1 prefix
    $path_info =~ s#^/*#/#gmx;          # replace multiple slashes
    $path_info =~ s#/+$##gmx;           # trim trailing slashed
    $path_info =~ s#^.+/$##gmx;
    $path_info = '/' if $path_info eq '';

    # handle PUT requests like POST.
    if($c->req->method() eq 'PUT') {
        $c->req->env->{'REQUEST_METHOD'} = "POST";
    }

    # printing audit log breaks json output, ex. for commands
    local $ENV{'THRUK_QUIET'} = 1 unless Thruk::Base->verbose;

    $c->stash->{'backend_errors_handling'} = DIE;

    my $format   = 'json';
    my $backends = [];
    # strip known path prefixes
    while($path_info =~ m%^/(csv|text|human|xls|sites?|backends?)(/.*)$%mx) {
        my $prefix = $1;
        $path_info = $2;
        if($prefix eq 'csv') {
            $format = 'csv';
        }
        elsif($prefix eq 'xls') {
            $format = 'xls';
        }
        elsif($prefix eq 'human' || $prefix eq 'text') {
            $format = 'human';
        }
        elsif($prefix eq 'sites' || $prefix eq 'backend') {
            if($path_info =~ m%^/([^/]+)(/.*)$%mx) {
                $path_info = $2;
                my @sites = split(/\s*,\s*/mx, $1);
                push @{$backends}, @sites;
            }
        }
    }
    Thruk::Action::AddDefaults::set_processinfo($c, Thruk::Constants::ADD_CACHED_DEFAULTS) if $ENV{'THRUK_USE_LMD'}; # required for the first request on federated backends
    if(scalar @{$backends} > 0) {
        Thruk::Action::AddDefaults::set_enabled_backends($c, $backends);
    }
    elsif($c->req->parameters->{'backend'}) {
        Thruk::Action::AddDefaults::set_enabled_backends($c, $c->req->parameters->{'backend'});
        delete $c->req->parameters->{'backend'};
    }
    elsif($c->req->parameters->{'backends'}) {
        Thruk::Action::AddDefaults::set_enabled_backends($c, $c->req->parameters->{'backends'});
        delete $c->req->parameters->{'backends'};
    } else {
        my($disabled_backends) = Thruk::Action::AddDefaults::set_enabled_backends($c);
        Thruk::Action::AddDefaults::set_possible_backends($c, $disabled_backends);
    }

    # refresh dynamic roles and groups
    if($c->user && (!$c->user->{'timestamp'} || $c->user->{'timestamp'} < (time() - 600))) {
        $c->user->set_dynamic_attributes($c);
    }

    my $data;
    if($c->user->{'readonly'} && $c->req->method ne 'GET') {
        $data = {
            'message'     => 'only GET requests allowed for readonly api keys.',
            'code'        => 400,
            'failed'      => Cpanel::JSON::XS::true,
         };
    } elsif($c->config->{'demo_mode'} && $c->req->method ne 'GET') {
        $data = {
            'message'     => 'only GET requests allowed in demo_mode.',
            'code'        => 400,
            'failed'      => Cpanel::JSON::XS::true,
         };
    } elsif($path_info =~ m/\.cgi$/mx) {
        my $uri = $c->env->{'thruk.request.url'} // $c->req->url();
        $uri =~ s/^.*?\/r\/(v1\/|)/\/cgi-bin\//gmx;
        my $sub_c = $c->sub_request($uri, $c->req->env->{'REQUEST_METHOD'}, $c->req->parameters, 1, 7);
        $c->res->status($sub_c->res->code);
        $c->res->headers($sub_c->res->headers);
        $c->res->body($sub_c->res->content);
        $c->{'rendered'} = 1;
        $c->stash->{'inject_stats'} = 0;
        return;
    } else {
        $data = process_rest_request($c, $path_info);
    }
    return $data if $c->{'rendered'};

    if($format eq 'csv') {
        return(_format_csv_output($c, $data));
    }
    if($format eq 'xls') {
        return(_format_xls_output($c, $data));
    }
    if($format eq 'human') {
        return(_format_human_output($c, $data));
    }
    return($c->render(json => $data));
}

##########################################################

=head2 process_rest_request

  process_rest_request($c, $path_info, [$method])

returns json response

=cut
sub process_rest_request {
    my($c, $path_info, $method) = @_;

    my $data;
    my $raw_body = $c->req->raw_body;
    if(ref $raw_body eq '' && $raw_body =~ m/^\{.*\}$/mxs) {
        if(!$c->req->content_type || $c->req->content_type !~ m%^application/json%mx) {
            $data = { 'message' => sprintf("got json request data but content type is not application/json"), code => 400 };
        }
    }

    if(!$data) {
        eval {
            $data = _fetch($c, $path_info, $method);

            # generic post processing
            $data = _post_processing($c, $data);
        };
        my $err = $@;
        if($err) {
            if($err =~ m/bad\ request:\s*(.*)\s+at\s+.*\.pm\s+line\s+\d+\.$/mx) {
                $data = { 'message' => 'error during request', description => $1, code => 400 };
            } else {
                $data = { 'message' => 'error during request', description => $err, code => 500 };
            }
            if($c->{"detached"}) {
                _debug($err);
            } else {
                _error($err);
            }
        }
    }

    # add columns meta data, ex.: used in the thruk grafana datasource
    my $wrapped;
    $wrapped = 1 if($c->req->header("x-thruk-outputformat") && $c->req->header("x-thruk-outputformat") eq 'wrapped_json');
    $wrapped = 1 if(defined $c->req->parameters->{'headers'} && $c->req->parameters->{'headers'} eq 'wrapped_json');
    if($wrapped) {
        # wrap data along with column meta data
        my $request_method = $method || $c->req->method;
        my $columns        = _get_columns_meta_for_path($c, $path_info, $request_method, $data);
        my $meta           = {};
        $meta->{"columns"} = $columns if $columns;
        $data = {
            'meta' => $meta,
            'data' => $data,
        };
    }

    if(!$data) {
        $data = { 'message' => sprintf("unknown rest path %s '%s'", $c->req->method, $path_info), code => 404 };
    }
    if(ref $data eq 'HASH') {
        $c->res->code($data->{'code'}) if $data->{'code'};
        if($data->{'code'} && $data->{'code'} ne 200) {
            my($style, $message) = Thruk::Utils::Filter::get_message($c, 1);
            if($message && $style eq 'fail_message') {
                $data->{'description'} .= $message;
            }
            if($data->{'code'} > 400) {
                $data->{'failed'} = Cpanel::JSON::XS::true;
            }
            if($data->{'code'} == 400) {
                my $help = _get_help_for_path($c, $path_info);
                if($help) {
                    if($help->{uc($c->req->method)}) {
                        $help = join("\n", @{$help->{uc($c->req->method)}});
                    }
                    $data->{'help'} = $help;
                }
            }
        }
        return($data);
    }
    if(ref $data eq 'ARRAY') {
        return($data);
    }
    return({ 'message' => 'error during request', 'description' => "returned data is of type '".(ref $data || 'text')."'", 'code' => 500 });
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
        $data = $list;
    }

    my $encoder = Cpanel::JSON::XS->new->ascii->canonical->allow_blessed->allow_nonref;

    my $output = "";
    if(ref $data eq 'ARRAY') {
        my $columns = $hash_columns || get_request_columns($c, ALIAS) || ($data->[0] ? [sort keys %{$data->[0]}] : []);
        if(!defined $c->req->parameters->{'headers'} || $c->req->parameters->{'headers'}) {
            $output = '#'.join(';', @{$columns})."\n";
        }
        for my $d (@{$data}) {
            my $x = 0;
            for my $col (@{$columns}) {
                $output .= ';' unless $x == 0;
                if(ref($d->{$col}) eq 'ARRAY') {
                    # try to create a csv list for lists of simple scalars
                    if(scalar @{$d->{$col}} == 0 || ref $d->{$col}->[0] eq '') {
                        $output .= join(",", @{$d->{$col}});
                    } else {
                        # fallback to json encode
                        $output .= _escape_newlines($encoder->encode($d->{$col}));
                    }
                }
                elsif(ref($d->{$col}) ne '') {
                    $output .= _escape_newlines($encoder->encode($d->{$col}));
                } else {
                    $output .= _escape_newlines($d->{$col} // '');
                }
                $x++;
            }
            $output .= "\n";
        }
    }
    if($output eq '' && scalar @{$data} > 0) {
        $output .= "ERROR: failed to generate output, rerun with -v to get more details.\n";
    }

    $output = Thruk::Utils::Encode::encode_utf8($output);
    return $c->render('text' => $output);
}

##########################################################
sub _escape_newlines {
    my($str) = @_;
    return $str unless $str;
    $str =~ s/\n/\\n/gmx;
    $str =~ s/\r//gmx;
    return $str;
}

##########################################################
sub _format_human_output {
    my($c, $data) = @_;

    my $hash_columns;
    if(ref $data eq 'HASH') {
        $hash_columns = [qw/key value/];
        my $list = [];
        my $columns = [sort keys %{$data}];
        for my $col (@{$columns}) {
            push @{$list}, { key => $col, value => $data->{$col} };
        }
        $data = $list;
    }

    my $columns;
    if(ref $data eq 'ARRAY') {
        $columns = $hash_columns || get_request_columns($c, ALIAS);
    }

    return $c->render('text' => Thruk::Utils::text_table(keys => $columns, data => $data));
}

##########################################################
sub _format_xls_output {
    my($c, $data) = @_;

    my $hash_columns;
    if(ref $data eq 'HASH') {
        $hash_columns = [qw/key value/];
        my $list = [];
        my $columns = [sort keys %{$data}];
        for my $col (@{$columns}) {
            push @{$list}, { key => $col, value => $data->{$col} };
        }
        $data = $list;
    }

    my $columns = [];
    if(ref $data eq 'ARRAY') {
        $columns = $hash_columns || get_request_columns($c, ALIAS) || ($data->[0] ? [sort keys %{$data->[0]}] : []);
        for my $row (@{$data}) {
            for my $key (keys %{$row}) {
                $row->{$key} = Thruk::Utils::Filter::escape_xml(join(", ", @{Thruk::Base::list($row->{$key})}));
            }
        }
    }

    $c->req->parameters->{'columns'} = $columns;
    Thruk::Utils::Status::set_selected_columns($c, [''], 'host', $columns);
    $c->res->headers->header( 'Content-Disposition', qq[attachment; filename="] . "rest.xls" . q["] );
    $c->stash->{'name'}      = "data";
    $c->stash->{'data'}      = $data;
    $c->stash->{'col_tr'}    = {};
    $c->stash->{'template'}  = 'excel/generic.tt';
    return $c->render_excel();
}

##########################################################
sub _fetch {
    my($c, $path_info, $method) = @_;
    $c->stats->profile(begin => "_fetch");

    # load plugin paths
    if(!$c->config->{'_rest_paths_loaded'}) {
        $c->config->{'_rest_paths_loaded'} = 1;
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
            my $err = $@;
            if($err) {
                _error($err);
                return({ 'message' => 'error loading '.$pkg_name.' rest submodule', code => 500, 'description' => $@ });
            }

        }
    }

    my $data;
    my $found = 0;
    my $request_method = $method || $c->req->method;
    my $protos = [];
    for my $r (@{$rest_paths}) {
        my @matches;
        my($proto, $path, $function, $roles) = @{$r};
        if((ref $path eq '' && $path eq $path_info) || (ref $path eq 'Regexp' && (@matches = $path_info =~ $path)))  {
            if(ref $path eq 'Regexp' && "$path" !~ m/^.*:.*\(.*\)/mx) {
                # if regex does not contain any matching (), @matches will contain a single value instead of empty args
                @matches = ();
            }
            if($proto ne $request_method) {
                # matching path, but wrong protocol
                push @{$protos}, $proto;
                next;
            }
            if($request_method ne 'GET' && !Thruk::Utils::check_csrf($c, 1)) {
                # make csrf protection mandatory for anything other than GET requests
                return({
                    'message'     => 'invalid or no csfr token',
                    'code'        => 403,
                    'failed'      => Cpanel::JSON::XS::true,
                });
            }
            delete $c->req->parameters->{'CSRFtoken'};
            delete $c->req->body_parameters->{'CSRFtoken'};
            @matches = map { uri_unescape($_, ) } @matches;
            $c->stats->profile(comment => $path);
            my $sub_name = Thruk::Base->verbose ? Thruk::Utils::code2name($function) : '';
            if($roles && !$c->user->check_user_roles($roles)) {
                $data = { 'message' => 'not authorized', 'description' => 'this path requires certain roles: '.join(', ', @{$roles}), code => 403 };
            } else {
                $c->stats->profile(begin => "rest: $sub_name");
                $data = &{$function}($c, $path_info, @matches);
                $c->stats->profile(end => "rest: $sub_name");
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
            # make GET paths available via POST as well
            if($request_method eq 'POST' && grep(/^GET$/mx, @{$protos})) {
                $c->req->{'_method'} = 'GET';
                $c->req->{'env'}->{'REQUEST_METHOD'} = 'GET';
                $data = _fetch($c, $path_info, 'GET');
            } else {
                $data = { 'message' => 'bad request', description => 'available methods for '.$path_info.' are: '.join(', ', @{$protos}), code => 400 };
            }
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
    return($data) if _is_failed($data);

    if(ref $data eq 'ARRAY') {
        if($c->req->method eq 'GET') {
            # Filtering
            $data = _apply_filter($c, $data, PRE_STATS);
            return($data) if _is_failed($data);

            # calculate statistics
            $data = _apply_stats($c, $data);
        }
    }

    if(ref $data eq 'ARRAY') {
        # Sorting
        $data = _apply_sort($c, $data);
        return($data) if _is_failed($data);

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

    return($data) if _is_failed($data);
    if(ref $data eq 'HASH') {
        # Columns
        $data = shift @{_apply_columns($c, [$data])};
    }

    return($data) if _is_failed($data);

    $c->stats->profile(end => "_post_processing");
    return $data;
}

##########################################################
sub _get_filter {
    my($c, $stage) = @_;
    my $filter = [];

    my $reserved = Thruk::Base::array2hash($reserved_query_parameters);

    for my $key (keys %{$c->req->parameters}) {
        next if $reserved->{$key};
        next if $key =~ m/^\s*$/mx; # skip empty keys
        my $op   = '=';
        my @vals = @{Thruk::Base::list($c->req->parameters->{$key})};
        if($key =~ m/^(.+)\[(.*?)\]$/mx) {
            $key = $1;
            $op  = lc($2);
        }
        if($stage == PRE_STATS) {
            next if $key =~ m/\([^)]+\)$/mx;
        } elsif($stage == POST_STATS) {
            next if $key !~ m/\([^)]+\)$/mx;
        }
        $op = $op_translation_words->{$op} if $op_translation_words->{$op};
        for my $val (@vals) {
            # expand relative time filter for some operators
            $val = Thruk::Utils::expand_relative_timefilter($key, $op, $val);
            push @{$filter}, { $key => { $op =>  $val }};
        }
    }

    if($stage == PRE_STATS) {
        _append_lexical_filter($filter, $c->req->parameters->{'q'}) if $c->req->parameters->{'q'};
    }

    return $filter;
}

##########################################################
sub _append_lexical_filter {
    my($filter, $string) = @_;
    return unless $string;
    push @{$filter}, Thruk::Utils::Status::parse_lexical_filter($string, 1);
    return;
}

##########################################################
sub _apply_filter {
    my($c, $data, $stage) = @_;

    my @filtered;
    my $filter = _get_filter($c, $stage);
    if(scalar @{$filter} == 0) {
        _debug("skipping empty %s filter", $stage == POST_STATS ? 'post-stats' : 'data');
        return($data);
    }
    my $nr     = 1;
    my $missed = {};
    for my $d (@{$data}) {
        if(_match_complex_filter($d, $filter, $missed, $nr)) {
            push @filtered, $d;
        }
        $nr++;
    }
    if(Thruk::Base->debug) {
        if(scalar @{$filter} > 0) {
            _debug("applying %s filter", $stage == POST_STATS ? 'post-stats' : 'data');
            _debug($filter);
        }
    }

    # did we have filter for not existing keys
    my $missing_keys = [];
    for my $key (keys %{$missed}) {
        next if $key =~ m/^_/mx; # skip custom vars here
        if(scalar keys %{$missed->{$key}} == scalar @{$data}) {
            push @{$missing_keys}, $key;
        }
    }
    if(scalar @{$missing_keys} > 0) {
        my $alias_columns = get_aliased_columns($c);
        for my $missing (@{$missing_keys}) {
            if(defined $alias_columns->{$missing}) {
                return({
                    'message'     => 'alias column name used in filter',
                    'description' => sprintf("alias column names cannot be used in filter, use '%s' instead of '%s'", $alias_columns->{$missing}, $missing),
                    'code'        => 400,
                    'failed'      => Cpanel::JSON::XS::true,
                });
            }
        }
        return({
            'message'     => 'possible typo in filter',
            'description' => "no datarow has attribute(s) named: ".join(", ", @{$missing_keys}),
            'code'        => 400,
            'failed'      => Cpanel::JSON::XS::true,
        });
    }
    if(Thruk::Base->trace) {
        _trace("filtered data:");
        _trace(\@filtered);
    }
    return \@filtered;
}

##########################################################
sub _apply_stats {
    my($c, $data) = @_;
    return($data) unless $c->req->parameters->{'columns'};

    my $aggregation_functions = Thruk::Base::array2hash($aggregation_function_names);
    my $new_columns   = [];
    my $stats_columns = [];
    my $group_columns = [];
    my $all_columns   = _parse_columns_data(get_request_columns($c, RAW));
    for my $col (@{$all_columns}) {
        # check for aggregation function which must be the outer most one
        if(scalar @{$col->{'func'}} > 0 && $aggregation_functions->{$col->{'func'}->[0]->[0]}) {
            push @{$stats_columns}, { op => $col->{'func'}->[0]->[0], col => $col->{'column'} };
            push @{$new_columns}, $col;
            next;
        }

        push @{$group_columns}, $col;
    }

    my $group_column_name = "";
    return($data) unless scalar @{$stats_columns} > 0;
    # grouped columns go first, so we need to update the columns request header
    if(scalar @{$group_columns} > 0) {
        my $combined = [];
        for my $col (@{$group_columns}, @{$new_columns}) {
            push @{$combined}, sprintf("%s as %s", $col->{'orig'}, $col->{'alias'});
        }
        $c->req->parameters->{'columns'} = join(",", @{$combined});

        # build key for grouped stats
        my $group_names = [];
        for my $col (@{$group_columns}) {
            push @{$group_names}, $col->{'alias'} // $col->{'column'};
        }
        $group_column_name = join(";", @{$group_names});
    }

    my $result = {};
    my $num_stats = scalar @{$stats_columns};
    # initialize result
    if(scalar @{$group_columns} == 0) {
        my $key = "";
        my $entry = {
            count   => 0,
            columns => [],
        };
        for my $col (@{$stats_columns}) {
            if($col->{'op'} eq 'sum') {
                push @{$entry->{'columns'}}, 0;
            } else {
                push @{$entry->{'columns'}}, undef;
            }
        }
        $result->{$key} = $entry;
    }
    for my $d (@{$data}) {
        my $key = "";
        for my $col (@{$group_columns}) {
            $key .= ';'.($d->{$col->{'column'}} // '');
        }
        my $entry = $result->{$key};
        if(!$entry) {
            $entry = {
                count   => 0,
                columns => [],
            };
            for my $col (@{$stats_columns}) {
                if($col->{'op'} eq 'sum') {
                    push @{$entry->{'columns'}}, 0;
                } else {
                    push @{$entry->{'columns'}}, undef;
                }
            }
            $result->{$key} = $entry;
        }
        $entry->{'count'}++;
        for(my $x = 0; $x < $num_stats; $x++) {
            my $col = $stats_columns->[$x];
            my $val = $d->{$col->{'col'}};
            if(!Thruk::Backend::Manager::looks_like_number($val)) {
                next;
            }
            if($col->{'op'} eq 'sum' || $col->{'op'} eq 'avg') {
                $entry->{'columns'}->[$x] += $val;
            }
            elsif($col->{'op'} eq 'min') {
                if(!defined $entry->{'columns'}->[$x] || $entry->{'columns'}->[$x] > $val) {
                    $entry->{'columns'}->[$x] = $val;
                }
            }
            elsif($col->{'op'} eq 'max') {
                if(!defined $entry->{'columns'}->[$x] || $entry->{'columns'}->[$x] < $val) {
                    $entry->{'columns'}->[$x] = $val;
                }
            }
        }
    }
    $data = [];
    for my $key (sort keys %{$result}) {
        my $result_row = $result->{$key};
        my $row = {};
        $key =~ s/^;//gmx;
        $row->{$group_column_name} = $key;
        for(my $x = 0; $x < $num_stats; $x++) {
            my $col = $stats_columns->[$x];
            my $result_key = $col->{'op'}.'('.$col->{'col'}.')';
            my $val;
            if($col->{'op'} eq 'avg') {
                if($result_row->{'count'} > 0 && defined $result_row->{'columns'}->[$x]) {
                    $val = $result_row->{'columns'}->[$x] / $result_row->{'count'};
                }
            }
            elsif($col->{'op'} eq 'count') {
                $val = $result_row->{'count'};
            }
            else {
                $val = $result_row->{'columns'}->[$x];
            }
            $row->{$result_key} = $val;
        }
        delete $row->{''} if defined $row->{''} && $row->{''} eq '';
        push @{$data}, $row;
    }

    $data = _apply_filter($c, $data, POST_STATS);

    if(scalar @{$group_columns} == 0) {
        $data = $data->[0];
    }
    return($data);
}

##########################################################

=head2 get_request_columns

    get_request_columns($c, $type)

    $type can be:
        - RAW   - returns columsn as is, alias definitions untouched
        - NAMES - returns column name
        - ALIAS - returns column alias or the name if none specified

returns list of requested columns or undef

=cut
sub get_request_columns {
    my($c, $type) = @_;

    return unless $c->req->parameters->{'columns'};

    my $columns = _split_columns($c->req->parameters->{'columns'});

    $columns = Thruk::Base::array_uniq($columns);
    if($type == ALIAS) {
        for(@{$columns}) {
            if($_ =~ m/\s+as\s+([^\s]+)\s*$/mx) {
                $_ =~ s/^.*?\s+as\s+([^\s]+)\s*$/$1/mx; # strip "as alias" from column
            } else {
                $_ =~ s/^[^:]+:(.*?)$/$1/gmx; # strip alias
            }
        }
    }
    if($type == NAMES) {
        for(@{$columns}) {
            if($_ =~ m/\s+as\s+([^\s]+)\s*$/mx) {
                $_ =~ s/\s+as\s+([^\s]+)\s*$//mx; # strip "as alias" from column
            } else {
                $_ =~ s/^([^:]+):.*?$/$1/gmx; # strip alias
            }
            $_ =~ s/^.*\(([^)]+)\)$/$1/gmx; # extract column name from aggregation function
        }
    }
    return($columns);
}

##########################################################

=head2 get_aliased_columns

    get_aliased_columns($c)

returns hash of columns with their alias

=cut
sub get_aliased_columns {
    my($c) = @_;

    my $alias_columns = {};
    my $columns = get_request_columns($c, RAW);
    if($columns) {
        for my $col (@{$columns}) {
            if($col =~ m/^([^:]+)\s+as\s+(.*)$/mx) {
                $alias_columns->{$2} = $1;
            }
            elsif($col =~ m/^([^:]+):(.*)$/mx) {
                $alias_columns->{$2} = $1;
            }
        }
    }
    return($alias_columns);
}

##########################################################

=head2 get_filter_columns

    get_filter_columns($c)

returns list of columns required for filtering

=cut
sub get_filter_columns {
    my($c) = @_;

    my $columns = {};
    my $filter = _get_filter($c, PRE_STATS);
    _set_filter_keys($filter, $columns);

    return([sort keys %{$columns}]);
}

##########################################################
sub _set_filter_keys {
    my($f, $columns) = @_;
    if(ref $f eq 'ARRAY') {
        for my $f2 (@{$f}) {
            _set_filter_keys($f2, $columns);
        }
    }
    elsif(ref $f eq 'HASH') {
        for my $f2 (keys %{$f}) {
            if($f2 eq '-and' || $f2 eq '-or') {
                _set_filter_keys($f->{$f2}, $columns);
            } else {
                $columns->{$f2} = 1;
            }
        }
    } else {
        require Data::Dumper;
        confess("unsupported _set_filter_keys: ".Data::Dumper::Dumper($f));
    }
    return;
}

##########################################################

=head2 column_required

    column_required($c, $column_name)

Can be used to exclude expensive columns from beeing generated.

returns true if column is required, ex. for sorting, filtering, etc...

=cut
sub column_required {
    my($c, $col) = @_;

    # from filter ?$col=...
    for my $p (sort keys %{$c->req->parameters}) {
        if($p =~ m/^(.+)\[(.*?)\]$/mx) {
            $p = $1;
        }
        return 1 if $p eq $col;
    }

    # from ?columns=...
    my $req_col = get_request_columns($c, NAMES);
    if(defined $req_col && scalar @{$req_col} >= 0 && grep(/^$col$/mx, @{$req_col})) {
        return 1;
    }

    # from ?sort=...
    for my $sort (@{Thruk::Base::list($c->req->parameters->{'sort'})}) {
        for my $s (split(/\s*,\s*/mx, $sort)) {
            $s =~ s/^[\-\+]+//gmx;
            return 1 if $col eq $s;
        }
    }

    my $filter_cols = get_filter_columns($c);
    if(defined $filter_cols && scalar @{$filter_cols} >= 0 && grep(/^$col$/mx, @{$filter_cols})) {
        return 1;
    }

    return;
}
##########################################################
sub _apply_columns {
    my($c, $data) = @_;

    return $data unless $c->req->parameters->{'columns'};
    my $columns = _parse_columns_data(get_request_columns($c, RAW));

    # remove aggregation functions
    my $aggregation_functions = Thruk::Base::array2hash($aggregation_function_names);
    for my $col (@{$columns}) {
        if(scalar @{$col->{'func'}} > 0 && $aggregation_functions->{$col->{'func'}->[0]->[0]}) {
            $col->{'func'} = [];
        }
    }

    my $res = [];
    for my $d (@{$data}) {
        my $row = {};
        for my $c (@{$columns}) {
            my $val = $d->{$c->{'orig'}} // $d->{$c->{'column'}};
            for my $f (@{$c->{'func'}}) {
                $val = _apply_data_function($f, $val);
            }
            $row->{$c->{'alias'}} = $val;
        }
        push @{$res}, $row;
    }

    return $res;
}

##########################################################
sub _apply_data_function {
    my($f, $val) = @_;
    my($name, $args) = @{$f};
    if($name eq 'lower' || $name eq 'lc') {
        return lc($val // '');
    }
    if($name eq 'upper' || $name eq 'uc') {
        return uc($val // '');
    }
    if($name eq 'substr' || $name eq 'substring') {
        if(defined $args->[1]) {
            return(substr($val // '', $args->[0], $args->[1]));
        }
        if(defined $args->[0]) {
            return(substr($val // '', $args->[0]));
        }
        die("usage: substr(value, start[, length])");
    }

    die("unknown function: ".$name);
}

##########################################################
sub _apply_sort {
    my($c, $data) = @_;

    return $data unless $c->req->parameters->{'sort'};
    return $data if scalar @{$data} == 0;
    my $sort = [];
    for my $s (@{Thruk::Base::list($c->req->parameters->{'sort'})}) {
        push @{$sort}, split(/\s*,\s*/mx, $s);
    }

    my $alias_columns = get_aliased_columns($c);

    my @compares;
    for my $key (@{$sort}) {
        my $order = 'asc';
        if($key =~ m/^\-/mx) {
            $order = 'desc';
            $key =~ s/^\-//mx;
        } else {
            $key =~ s/^\+//mx;
        }

        $key = $alias_columns->{$key} if defined $alias_columns->{$key};

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
sub _livestatus_options {
    my($c, $type) = @_;
    my $options = {};
    if($c->req->parameters->{'limit'} && !$c->stash->{'filter_fixed_up'}) {
        $options->{'options'}->{'limit'} = $c->req->parameters->{'limit'};
        if($c->req->parameters->{'offset'}) {
            $options->{'options'}->{'limit'} += $c->req->parameters->{'offset'};
        }
    }

    # try to reduce the number of requested columns
    if($type) {
        my $columns = get_request_columns($c, NAMES) || [];
        if(scalar @{$columns} > 0) {
            push @{$columns}, @{get_filter_columns($c)};
            $columns = Thruk::Base::array_uniq($columns);
            my $ref_columns;
            if($type eq 'hosts') {
                $ref_columns = Thruk::Base::array2hash([@{$Thruk::Backend::Provider::Livestatus::default_host_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_host_columns}]);
            }
            elsif($type eq 'services') {
                $ref_columns = Thruk::Base::array2hash([@{$Thruk::Backend::Provider::Livestatus::default_service_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_service_columns}]);
            }
            elsif($type eq 'contacts') {
                $ref_columns = Thruk::Base::array2hash($Thruk::Backend::Provider::Livestatus::default_contact_columns);
            }
            elsif($type eq 'logs') {
                $ref_columns = Thruk::Base::array2hash($Thruk::Backend::Provider::Livestatus::default_logs_columns);
            }
            elsif($type eq 'comments') {
                $ref_columns = Thruk::Base::array2hash([@{$Thruk::Backend::Provider::Livestatus::default_comments_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_comments_columns}]);
            }
            elsif($type eq 'downtimes') {
                $ref_columns = Thruk::Base::array2hash([@{$Thruk::Backend::Provider::Livestatus::default_downtimes_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_downtimes_columns}]);
            }

            if($ref_columns) {
                # if all requested columns are default columns, we can pass the columns to livestatus
                my $found = 1;
                for my $col (@{$columns}) {
                    $col = "comments_with_info"  if $col eq 'comments_info';
                    $col = "downtimes_with_info" if $col eq 'downtimes_info';
                    if(!$ref_columns->{$col}) {
                        $found = 0;
                        last;
                    }
                }
                if($found) {
                    $options->{'columns'} = $columns;
                }
            }
        }

        if(!$options->{'columns'}) {
            if($type eq 'hosts') {
                $options->{'extra_columns'} = $Thruk::Backend::Provider::Livestatus::extra_host_columns;
            }
            elsif($type eq 'hostgroups') {
                $options->{'extra_columns'} = $Thruk::Backend::Provider::Livestatus::extra_hostgroup_columns;
            }
            elsif($type eq 'services') {
                $options->{'extra_columns'} = $Thruk::Backend::Provider::Livestatus::extra_service_columns;
            }
            elsif($type eq 'servicegroups') {
                $options->{'extra_columns'} = $Thruk::Backend::Provider::Livestatus::extra_servicegroup_columns;
            }
            elsif($type eq 'contacts') {
                $options->{'extra_columns'} = $Thruk::Backend::Provider::Livestatus::extra_contact_columns;
            }
        }
    }

    return $options;
}

##########################################################
sub _livestatus_filter {
    my($c, $ref_columns) = @_;
    if($ref_columns && ref $ref_columns eq '') {
        if($ref_columns eq 'hosts') {
            $ref_columns = Thruk::Base::array2hash([@{$Thruk::Backend::Provider::Livestatus::default_host_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_host_columns}]);
        }
        elsif($ref_columns eq 'services') {
            $ref_columns = Thruk::Base::array2hash([@{$Thruk::Backend::Provider::Livestatus::default_service_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_service_columns}]);
        }
        elsif($ref_columns eq 'contacts') {
            $ref_columns = Thruk::Base::array2hash($Thruk::Backend::Provider::Livestatus::default_contact_columns);
        }
        elsif($ref_columns eq 'logs') {
            $ref_columns = Thruk::Base::array2hash($Thruk::Backend::Provider::Livestatus::default_logs_columns);
            # logcache has no plugin_output column
            delete $ref_columns->{"plugin_output"};
        } else {
            confess("unsupported type: ".$ref_columns);
        }
    }
    my $filter = _get_filter($c, PRE_STATS);
    $c->stash->{'filter_fixed_up'} = 0;
    _fixup_livestatus_filter($c, $filter, $ref_columns);
    return $filter;
}

##########################################################
sub _fixup_livestatus_filter {
    my($c, $filter, $ref_columns) = @_;

    if(ref $filter eq 'ARRAY') {
        for my $f (@{$filter}) {
            _fixup_livestatus_filter($c, $f, $ref_columns);
        }
    }
    elsif(ref $filter eq 'HASH') {
        for my $f (keys %{$filter}) {
            if($f eq '-and' || $f eq '-or') {
                _fixup_livestatus_filter($c, $filter->{$f}, $ref_columns);
            } else {
                if($ref_columns && !$ref_columns->{$f}) {
                    # normalize filter
                    if(ref $filter->{$f} ne 'HASH') {
                        my $val = $filter->{$f};
                        $filter->{$f} = { '=' => $val };
                    }
                    my @ops = keys %{$filter->{$f}};
                    if(scalar @ops != 1) {
                        require Data::Dumper;
                        confess("unsupported _fixup_livestatus_filter: ".Data::Dumper::Dumper([$filter, $f]));
                    }
                    my $op  = $ops[0];
                    my $val = $filter->{$f}->{$op};
                    delete $filter->{$f};

                    # add flag, so we cannot use limit to optimize query result
                    $c->stash->{'filter_fixed_up'} = 1;

                    if($f =~ m/^_/mx) {
                        # convert custom variable filter
                        $f =~ s/^_//mx;
                        $val = $f.' '.$val;
                        if($f =~ m/^host/mxi) {
                            $f = 'host_custom_variables';
                            $val =~ s/^HOST//mxi;
                        } else {
                            $f = 'custom_variables';
                        }
                        $filter->{$f} = { $op => $val };
                    } else {
                        # replace filter with something that always matches
                        # because this is probably performance a data filter
                        if($ref_columns->{'state'}) {
                            $filter->{'state'} = { '!=' => -17 };
                        }
                        elsif($ref_columns->{'name'}) {
                            $filter->{'name'} = { '!=' => '' };
                        } else {
                            die("no idea how to replace column: ".$f);
                        }
                    }
                }
            }
        }
    } else {
        require Data::Dumper;
        confess("unsupported _fixup_livestatus_filter: ".Data::Dumper::Dumper($filter));
    }

    return;
}

##########################################################
sub _expand_perfdata_and_custom_vars {
    my($c, $data, $type) = @_;
    return $data unless ref $data eq 'ARRAY';

    # check wether user is allowed to see all custom variables
    my $allowed      = $c->check_user_roles("authorized_for_configuration_information");
    my $allowed_list = Thruk::Utils::get_exposed_custom_vars($c->config);

    # since expanding takes some time, only do it if we have no columns specified or if none-standard columns were requested
    my $columns = get_request_columns($c, NAMES) || [];
    if($columns && scalar @{$columns} > 0) {
        push @{$columns}, @{get_filter_columns($c)};
        my $ref_columns;
        if($type eq 'hosts') {
            $ref_columns = Thruk::Base::array2hash([@{$Thruk::Backend::Provider::Livestatus::default_host_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_host_columns}]);
        }
        elsif($type eq 'services') {
            $ref_columns = Thruk::Base::array2hash([@{$Thruk::Backend::Provider::Livestatus::default_service_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_service_columns}]);
        }
        elsif($type eq 'contacts') {
            $ref_columns = Thruk::Base::array2hash($Thruk::Backend::Provider::Livestatus::default_contact_columns);
        } else {
            confess("unsupported type: ".$type);
        }
        # if all requested columns are default columns, simply return our data, no expanding required
        my $found = 1;
        for my $col (@{$columns}) {
            if(!$ref_columns->{$col}) {
                $found = 0;
                last;
            }
            if($col =~ m/^(custom_var|check_command)/mx) {
                $found = 0;
                last;
            }
        }
        return($data) if $found;
    }

    my $show_full_commandline = $c->config->{'show_full_commandline'};
    for my $row (@{$data}) {
        Thruk::Utils::set_allowed_rows_data($row, $allowed, $allowed_list, $show_full_commandline);

        if($row->{'perf_data'}) {
            my $perfdata = (Thruk::Utils::Filter::split_perfdata($row->{'perf_data'}))[0];
            for my $p (@{$perfdata}) {
                my $name = $p->{'name'};
                if($p->{'parent'}) {
                    $name = $p->{'parent'}.'::'.$p->{'name'};
                }
                next if $row->{$name}; # don't overwrite existing values
                $row->{$name} = $p->{'value'};
                $row->{$name.'_unit'} = $p->{'unit'};
            }
            $row->{'perf_data_expanded'} = $perfdata;
        }
        if($row->{'host_perf_data'}) {
            my $perfdata = (Thruk::Utils::Filter::split_perfdata($row->{'host_perf_data'}))[0];
            for my $p (@{$perfdata}) {
                my $name = 'host_'.$p->{'name'};
                if($p->{'parent'}) {
                    $name = 'host_'.$p->{'parent'}.'::'.$p->{'name'};
                }
                next if $row->{$name}; # don't overwrite existing values
                $row->{$name} = $p->{'value'};
                $row->{$name.'_unit'} = $p->{'unit'};
            }
            $row->{'host_perf_data_expanded'} = $perfdata;
        }
        if($row->{'comments_with_info'}) {
            _add_comment_downtimes($row, 'comments_info', $row->{'comments_with_info'});
        }
        if($row->{'downtimes_with_info'}) {
            _add_comment_downtimes($row, 'downtimes_info', $row->{'downtimes_with_info'});
        }
    }
    return($data);
}

##########################################################
sub _get_help_for_path {
    my($c, $path_info) = @_;
    my(undef, undef, $docs) = get_rest_paths($c);
    for my $path (reverse sort { length $a <=> length $b } keys %{$docs}) {
        my $p = $path;
        $p =~ s%<[^>]+>%[^/]*%gmx;
        if($path_info =~ qr/$p/mx) {
            return($docs->{$path});
        }
    }
    return;
}

##########################################################
sub _get_columns_meta_for_path {
    my($c, $path_info, $method, $data) = @_;
    require Thruk::Controller::Rest::V1::docs;
    my $keys = Thruk::Controller::Rest::V1::docs::keys();
    my $alias_columns = get_aliased_columns($c);
    my $req_columns   = get_request_columns($c, ALIAS) || ((ref $data eq 'ARRAY' && $data->[0]) ? [sort keys %{$data->[0]}] : []);
    my $columns = {};
    for my $path (reverse sort { length $a <=> length $b } keys %{$keys}) {
        my $p = $path;
        $p =~ s%<[^>]+>%[^/]*%gmx;
        if($path_info !~ qr/$p/mx) {
            next;
        }
        next unless ($keys->{$path}->{$method});

        for my $d (@{$keys->{$path}->{$method}->{'columns'}}) {
            my $col = { 'name' => $d->{'name'} };
            $col->{'type'} = $d->{'type'} if $d->{'type'};
            $col->{'config'} = { 'unit' => $d->{'unit'} } if $d->{'unit'};
            $columns->{$d->{'name'}} = $col;
        }
        last;
    }

    return unless scalar keys %{$columns} > 0;

    my $meta = [];
    for my $d (@{$req_columns}) {
        my $col = $columns->{$alias_columns->{$d} // $d} // {};
        $col->{'name'} = $d;
        push @{$meta}, $col;
    }
    return $meta;
}

##########################################################

=head2 register_rest_path_v1

    register_rest_path_v1($protocol, $path|$regex, $function, [$roles], [$first])

register rest path.

returns nothing

=cut
sub register_rest_path_v1 {
    my($proto, $path, $function, $roles, $first) = @_;
    for my $prot (@{Thruk::Base::list($proto)}) {
        if($first) {
            unshift @{$rest_paths}, [$prot, $path, $function, $roles];
        } else {
            push @{$rest_paths}, [$prot, $path, $function, $roles];
        }
    }
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
                            $c->config->{'project_root'}."/lib/Thruk/Controller/Rest/V1/*.pm",
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
        for my $line (Thruk::Utils::IO::read_as_list($file)) {
            if($line =~ m%REST\ PATH:\ (\w+)\ (.*?)$%mxo) {
                $last_path  = $2;
                $last_proto = $1;
                $paths->{$last_path}->{$last_proto} = 1;
                $in_comment = 1;
            }
            elsif($in_comment && $line =~ m%^\s*\#\s?(.*?)$%mxo) {
                $docs->{$last_path}->{$last_proto} = [] unless $docs->{$last_path}->{$last_proto};
                push @{$docs->{$last_path}->{$last_proto}}, $1;
            }
            elsif($last_path && $line =~ m%([\w\_]+)\s+=>\s+.*\#\s+(.*)$%mxo) {
                $keys->{$last_path}->{$last_proto} = [] unless $keys->{$last_path}->{$last_proto};
                push @{$keys->{$last_path}->{$last_proto}}, [$1,'', '', $2];
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

    return if($c->req->parameters->{'q'} && $c->req->parameters->{'q'} =~ m/time/mx);
    for my $f (@{$filter}) {
        if(ref $f eq 'HASH' && $f->{'time'}) {
            return;
        }
        if(ref $f eq 'ARRAY') {
            for my $f2 (@{$f}) {
                if(ref $f2 eq 'HASH' && $f2->{'time'}) {
                    return;
                }
            }
        }
    }
    push @{$filter}, { time => { '>=' => time() - 86400 } };
    return;
}

##########################################################

=head2 load_json_files

    load_json_files($c, {
        files                   => $files,
       [ pre_process_callback   => &code_ref ],
       [ authorization_callback => &code_ref ],
       [ post_process_callback  => &code_ref ],
    });

generic function to expose json files

returns list of authorized loaded files

=cut
sub load_json_files {
    my($c, $options) = @_;
    my $list = [];
    for my $file (@{$options->{'files'}}) {
        next unless -e $file;
        my $data = Thruk::Utils::IO::json_lock_retrieve($file);
        $data->{'file'} = $file;
        $data->{'file'} =~ s%.*?([^/]+)\.\w+$%$1%mx;
        if($options->{'pre_process_callback'}) {
            $data = &{$options->{'pre_process_callback'}}($c, $data);
        }
        if($options->{'authorization_callback'}) {
            next unless &{$options->{'authorization_callback'}}($c, $data);
        }
        if($options->{'post_process_callback'}) {
            $data = &{$options->{'post_process_callback'}}($c, $data);
        }
        push @{$list}, $data;
    }
    return $list;
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
        for my $proto (sort _sort_by_proto (keys %{$paths->{$path}})) {
            push @{$data}, {
                url         => $path,
                protocol    => $proto,
                description => $docs->{$path}->{$proto}->[0] || '',
            };
        }
    }
    return($data);
}

################################################################################
sub _sort_by_proto {
    my $weight = {
        'GET'    => 1,
        'POST'   => 2,
        'PATCH'  => 3,
        'DELETE' => 4,
    };
    return(($weight->{$a}//99) <=> ($weight->{$b}//99));
}

##########################################################
# REST PATH: GET /thruk
# hash of basic information about this thruk instance
register_rest_path_v1('GET', '/thruk', \&_rest_get_thruk);
sub _rest_get_thruk {
    my($c) = @_;
    return({
        rest_version        => $VERSION,                                # rest api version
        thruk_version       => $c->config->{'thrukversion'},            # thruk version
        thruk_release_date  => $c->config->{'released'},                # thruk release date
        localtime           => Time::HiRes::time(),                     # current server unix timestamp / epoch
        project_root        => $c->config->{'project_root'},            # thruk root folder
        etc_path            => $c->config->{'etc_path'},                # configuration folder
        var_path            => $c->config->{'var_path'},                # variable data folder
        extra_version       => $c->config->{'extra_version'}//'',       # might contain omd version
        extra_link          => $c->config->{'extra_version_link'}//'',  # contains link from extra_versions product
    });
}

##########################################################
# REST PATH: GET /thruk/config
# lists configuration information
register_rest_path_v1('GET', '/thruk/config', \&_rest_get_thruk_config, ['admin']);
sub _rest_get_thruk_config {
    my($c) = @_;
    my $data = {};
    for my $key (keys %{$c->config}) {
        next if $key eq 'secret_key';
        if($key eq 'logcache') {
            my $val = $c->config->{$key};
            $val =~ s|//.*?@|//...:...@|gmx if defined $val;
            $data->{$key} = $val;
        } else {
            $data->{$key} = $c->config->{$key};
        }
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
# REST PATH: GET /thruk/sessions
# lists thruk sessions.
register_rest_path_v1('GET', qr%^/thruk/sessions?$%mx, \&_rest_get_thruk_sessions);
sub _rest_get_thruk_sessions {
    my($c, undef, $id) = @_;
    $c->stats->profile(begin => "_rest_get_thruk_sessions");
    my $is_admin = 0;
    if($c->check_user_roles('admin')) {
        $is_admin = 1;
    }

    my $data = [];
    my $total_number = 0;
    my $total_5min   = 0;
    my $min5 = time() - (5*60);
    my $uniq = {};
    my $uniq5min = {};
    for my $file (sort glob($c->config->{'var_path'}."/sessions/*")) {
        $total_number++;
        my $session_data = Thruk::Utils::CookieAuth::retrieve_session(config => $c->config, file => $file);
        next unless $session_data;
        if($session_data->{'active'} > $min5) {
            $total_5min++;
            $uniq5min->{$session_data->{'username'}} = 1;
        }
        $uniq->{$session_data->{'username'}} = 1;

        next unless($is_admin || $session_data->{'username'} eq $c->stash->{'remote_user'});
        if($id) {
            next unless($session_data->{'hashed_key'} eq $id);
        }
        delete $session_data->{'hash'};       # basic auth token is never public
        delete $session_data->{'csrf_token'}; # also not public
        delete $session_data->{'current_roles'}; # for internal use
        push @{$data}, $session_data;
    }
    $c->stats->profile(end => "_rest_get_thruk_sessions");
    if($id) {
        if(!$data->[0]) {
            return({ 'message' => 'no such session', code => 404 });
        }
        $data = $data->[0];
        return($data);
    }
    $c->metrics->set('sessions_total', $total_number, "total number of thruk sessions");
    $c->metrics->set('sessions_uniq_user_total', scalar keys %{$uniq}, "total number of uniq users");
    $c->metrics->set('sessions_active_5min_total', $total_5min, "total number of active thruk sessions (active during the last 5 minutes)");
    $c->metrics->set('sessions_uniq_user_5min_total', scalar keys %{$uniq5min}, "total number of uniq users active during the last 5 minutes");
    return($data);
}

##########################################################
# REST PATH: GET /thruk/sessions/<id>
# get thruk sessions status for given id.
# alias for /thruk/sessions?id=<id>
register_rest_path_v1('GET', qr%^/thruk/sessions?/([^/]+)$%mx, \&_rest_get_thruk_sessions);

##########################################################
# REST PATH: GET /thruk/users
# lists thruk user profiles.
register_rest_path_v1('GET', qr%^/thruk/users?$%mx, \&_rest_get_thruk_users);
sub _rest_get_thruk_users {
    my($c, undef, $id, $statsonly) = @_;
    $c->stats->profile(begin => "_rest_get_thruk_users");
    my $is_admin = 0;
    if($c->check_user_roles('admin')) {
        $is_admin = 1;
    }
    if(!$c->config->{'use_feature_configtool'}) {
        return({ 'message' => 'config tool plugin is disabled', code => 400 });
    }

    if(!defined $id && !$statsonly) {
        # prefill contacts / groups cache
        $c->db->fill_get_can_submit_commands_cache();
        $c->db->fill_get_contactgroups_by_contact_cache();
    }
    my $locked_users = {};
    if($statsonly) {
        $locked_users = _fill_locked_users($c);
    }

    my $total_number = 0;
    my $total_locked = 0;
    require Thruk::Utils::Conf;
    my $users = Thruk::Utils::Conf::get_cgi_user_list($c);
    $users = [sort keys %{$users}];
    my $data = [];
    for my $name (@{$users}) {
        next if $name =~ m/\*/gmx;
        next unless($is_admin || $name eq $c->stash->{"remote_user"});
        next if(defined $id && $id ne $name);
        if($statsonly) {
            $total_locked++ if $locked_users->{$name};
            $total_number++;
            next;
        }
        my $userdata = _get_userdata($c, $name);
        $total_locked++ if $userdata->{'locked'} == Cpanel::JSON::XS::true;
        $total_number++;
        push @{$data}, $userdata;
    }
    $c->stats->profile(end => "_rest_get_thruk_users");

    if($id) {
        if(!$data->[0]) {
            return({ 'message' => 'no such user', code => 404 });
        }
        $data = $data->[0];
        return($data);
    }

    $c->metrics->set('users_total', $total_number, "total number of thruk users");
    $c->metrics->set('users_locked_total', $total_locked, "total number of locked thruk users");
    return($data);
}

##########################################################
sub _get_userdata {
    my($c, $name) = @_;
    my $profile;
    if($name) {
        $profile = Thruk::Authentication::User->new($c, $name)->set_dynamic_attributes($c, 1);
    } else {
        $profile = $c->user;
        $name    = $c->user->{'username'};
    }
    my $userdata = {
        'id'                => $name,
        'tz'                => undef,
        'has_thruk_profile' => Cpanel::JSON::XS::false,
        'locked'            => Cpanel::JSON::XS::false,
    };
    if($profile) {
        if($profile->{'settings'} && scalar keys %{$profile->{'settings'}} > 0) {
            $userdata->{'has_thruk_profile'} = Cpanel::JSON::XS::true;
            for my $key (qw/tz/) {
                $userdata->{$key} = $profile->{'settings'}->{$key};
            }
            $userdata->{'locked'} = $profile->{'settings'}->{'login'}->{'locked'} ? Cpanel::JSON::XS::true : Cpanel::JSON::XS::false;
            $userdata->{'last_login'} = $profile->{'settings'}->{'login'}->{'last_success'}->{'time'};
        }
        for my $key (qw/groups roles email alias can_submit_commands/) {
            $userdata->{$key} = $profile->{$key};
        }
    }
    return($userdata);
}

##########################################################
sub _fill_locked_users {
    my($c) = @_;
    my $locked = {};
    my $out = Thruk::Utils::IO::cmd($c, 'grep -lr \'"locked" : 1\' "'.$c->config->{'var_path'}.'/users/" 2>/dev/null');
    for my $row (split/\n/mx, $out) {
        next unless $row;
        my $name     = Thruk::Base::basename($row);
        my $profile  = Thruk::Utils::get_user_data($c, $name);
        $locked->{$name} = 1 if $profile->{'login'}->{'locked'};
    }
    return($locked);
}

##########################################################
# REST PATH: GET /thruk/users/<id>
# get thruk profile for given user.
# alias for /thruk/users?id=<id>
register_rest_path_v1('GET', qr%^/thruk/users?/([^/]+)$%mx, \&_rest_get_thruk_users);

##########################################################
# REST PATH: GET /thruk/stats
# lists thruk statistics.
register_rest_path_v1('GET', qr%^/thruk/stats$%mx, \&_rest_get_thruk_stats, ['authorized_for_system_information']);
sub _rest_get_thruk_stats {
    my($c, undef) = @_;

    my $cache = $c->cache->get("global");
    if(!$cache->{'last_metrics_update'} || $cache->{'last_metrics_update'} < time() -30) {
        $cache->{'last_metrics_update'} = time();
        $c->cache->set("global", $cache);

        # gather session metrics
        &_rest_get_thruk_sessions($c);

        # gather user metrics
        &_rest_get_thruk_users($c, undef, undef, 1);
    }

    my $data = $c->metrics->get_all();
    return($data);
}

##########################################################
# REST PATH: GET /thruk/metrics
# alias for /thruk/stats
register_rest_path_v1('GET', qr%^/thruk/metrics$%mx, \&_rest_get_thruk_stats, ['authorized_for_system_information']);

##########################################################
# REST PATH: GET /thruk/whoami
# show current profile information.
# alias for /thruk/users?id=<id>
register_rest_path_v1('GET', qr%^/thruk/whoami$%mx, \&_rest_get_thruk_whoami);
sub _rest_get_thruk_whoami {
    my($c) = @_;
    my $profile = _get_userdata($c);
    $profile->{'auth_src'}          = $c->user->{'auth_src'}          if $c->user->{'auth_src'};
    $profile->{'original_username'} = $c->user->{'original_username'} if $c->user->{'original_username'};
    return($profile);
}

##########################################################
# REST PATH: GET /sites
# lists configured backends
register_rest_path_v1('GET', qr%^/sites?$%mx, \&_rest_get_sites);
sub _rest_get_sites {
    my($c) = @_;
    my $data = [];
    $c->db->enable_backends();
    eval {
        $c->db->get_processinfo();
    };
    Thruk::Action::AddDefaults::set_possible_backends($c, {});
    my $time = time();
    for my $key (@{$c->stash->{'backends'}}) {
        my $addr  = $c->stash->{'backend_detail'}->{$key}->{'addr'};
        my $error = defined $c->stash->{'backend_detail'}->{$key}->{'last_error'} ? $c->stash->{'backend_detail'}->{$key}->{'last_error'} : '';
        chomp($error);
        my $peer = $c->db->get_peer_by_key($key);
        $error = '' if($error && $error eq 'OK');
        push @{$data}, {
            addr             => $addr,
            id               => $key,
            name             => $c->stash->{'backend_detail'}->{$key}->{'name'},
            section          => $c->stash->{'backend_detail'}->{$key}->{'section'},
            type             => $c->stash->{'backend_detail'}->{$key}->{'type'},
            status           => $error ? 1 : 0,
            last_error       => $error,
            connected        => $error ? 0 : 1,
            federation_key   => $peer->{'fed_info'}->{'key'}  || [ $peer->{'key'} ],
            federation_name  => $peer->{'fed_info'}->{'name'} || [ $peer->{'name'} ],
            federation_addr  => $peer->{'fed_info'}->{'addr'} || [ $peer->{'addr'} ],
            federation_type  => $peer->{'fed_info'}->{'type'} || [ $peer->{'type'} ],
            localtime        => $time,
        };
    }
    return($data);
}

##########################################################
# REST PATH: GET /hosts
# lists livestatus hosts.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#hosts for details.
register_rest_path_v1('GET', qr%^/hosts?$%mx, \&_rest_get_livestatus_hosts);
sub _rest_get_livestatus_hosts {
    my($c) = @_;
    my $data = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), _livestatus_filter($c, 'hosts') ], %{_livestatus_options($c, "hosts")});
    _expand_perfdata_and_custom_vars($c, $data, "hosts");
    return($data);
}

##########################################################
# REST PATH: GET /hosts/stats
# hash of livestatus host statistics.
register_rest_path_v1('GET', qr%^/hosts?/stats$%mx, \&_rest_get_livestatus_hosts_stats);
sub _rest_get_livestatus_hosts_stats {
    my($c) = @_;
    return($c->db->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /hosts/totals
# hash of livestatus host totals statistics.
# its basically a reduced set of /hosts/stats.
register_rest_path_v1('GET', qr%^/hosts?/totals$%mx, \&_rest_get_livestatus_hosts_totals);
sub _rest_get_livestatus_hosts_totals {
    my($c) = @_;
    return($c->db->get_host_totals_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /hosts/<name>/services
# lists services for given host.
# alias for /services?host_name=<name>
register_rest_path_v1('GET', qr%^/hosts?/([^/]+)/services?$%mx, \&_rest_get_livestatus_hosts_services);
sub _rest_get_livestatus_hosts_services {
    my($c, undef, $host) = @_;
    my $data = $c->db->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), { 'host_name' => $host }, _livestatus_filter($c, 'services') ], %{_livestatus_options($c, "services")});
    _expand_perfdata_and_custom_vars($c, $data, "services");
    return($data);
}

##########################################################
# REST PATH: GET /hosts/<name>/commandline
# displays commandline for check command of given hosts.
register_rest_path_v1('GET', qr%^/hosts?/([^/]+)/commandline?$%mx, \&_rest_get_livestatus_hosts_commandline);
sub _rest_get_livestatus_hosts_commandline {
    my($c, undef, $host) = @_;
    unless($c->config->{'show_full_commandline'} == 2 || ($c->config->{'show_full_commandline'} == 1 && $c->check_user_roles( "authorized_for_configuration_information" ))) {
        return({ 'message' => 'not authorized', 'description' => 'you are not authorized to view the command line', code => 403 });
    }
    my $data = [];
    my $all_commands = Thruk::Base::array2hash(\@{$c->db->get_commands()}, 'peer_key', 'name');
    my $hosts = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), { "name" => $host }, _livestatus_filter($c, 'hosts') ], %{_livestatus_options($c, "hosts")});
    for my $hst (@{$hosts}) {
        my $command = $c->db->expand_command('host' => $hst, commands => $all_commands, 'source' => $c->config->{'show_full_commandline_source'} );
        push @{$data}, {
            'command_line'  => $command->{'line_expanded'},
            'check_command' => $command->{'line'},
            'error'         => $command->{'note'},
            'host_name'     => $hst->{'name'},
            'peer_key'      => $hst->{'peer_key'},
        };
    }
    return($data);
}

##########################################################
# REST PATH: GET /hosts/<name>
# lists hosts for given name.
# alias for /hosts?name=<name>
register_rest_path_v1('GET', qr%^/hosts?/([^/]+)$%mx, \&_rest_get_livestatus_hosts_by_name);
sub _rest_get_livestatus_hosts_by_name {
    my($c, undef, $host) = @_;
    my $data = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), { "name" => $host }, _livestatus_filter($c, 'hosts') ], %{_livestatus_options($c, "hosts")});
    _expand_perfdata_and_custom_vars($c, $data, "hosts");
    return($data);
}

##########################################################
# REST PATH: GET /hostgroups
# lists livestatus hostgroups.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#hostgroups for details.
register_rest_path_v1('GET', qr%^/hostgroups?$%mx, \&_rest_get_livestatus_hostgroups);
sub _rest_get_livestatus_hostgroups {
    my($c) = @_;
    return($c->db->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups'), _livestatus_filter($c)  ], %{_livestatus_options($c, "hostgroups")}));
}

##########################################################
# REST PATH: GET /hostgroups/<name>
# lists hostgroups for given name.
# alias for /hostgroups?name=<name>
register_rest_path_v1('GET', qr%^/hostgroups?/([^/]+)$%mx, \&_rest_get_livestatus_hostgroups_by_name);
sub _rest_get_livestatus_hostgroups_by_name {
    my($c, undef, $hostgroup) = @_;
    my $data = $c->db->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups'), { "name" => $hostgroup }, _livestatus_filter($c) ], %{_livestatus_options($c, "hostgroups")});
    return($data);
}

##########################################################
# REST PATH: GET /hostgroups/<name>/stats
# hash of livestatus hostgroup statistics.
# alias for /hosts/stats?groups[gte]=<name>
register_rest_path_v1('GET', qr%^/hostgroups?/([^/]+)/stats$%mx, \&_rest_get_livestatus_hostgroup_stats);
sub _rest_get_livestatus_hostgroup_stats {
    my($c, undef, $group) = @_;
    return($c->db->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), [{ 'groups' => { '>=' => $group } }], _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /services
# lists livestatus services.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#services for details.
# there is an alias /services.
register_rest_path_v1('GET', qr%^/services?$%mx, \&_rest_get_livestatus_services);
sub _rest_get_livestatus_services {
    my($c) = @_;
    my $data = $c->db->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), _livestatus_filter($c, 'services')  ], %{_livestatus_options($c, "services")});
    _expand_perfdata_and_custom_vars($c, $data, "services");
    return($data);
}

##########################################################
# REST PATH: GET /services/<host>/<service>
# lists services for given host and name.
# alias for /services?host_name=<host_name>&description=<service>
register_rest_path_v1('GET', qr%^/services?/([^/]+)/([^/]+)$%mx, \&_rest_get_livestatus_services_by_name);
sub _rest_get_livestatus_services_by_name {
    my($c, undef, $host, $service) = @_;
    my $data = $c->db->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), { "host_name" => $host, description => $service }, _livestatus_filter($c, 'hosts') ], %{_livestatus_options($c, "services")});
    _expand_perfdata_and_custom_vars($c, $data, "services");
    return($data);
}

##########################################################
# REST PATH: GET /services/<host>/<service>/commandline
# displays commandline for check command of given services.
register_rest_path_v1('GET', qr%^/services?/([^/]+)/([^/]+)/commandline$%mx, \&_rest_get_livestatus_services_commandline);
sub _rest_get_livestatus_services_commandline {
    my($c, undef, $host, $service) = @_;
    unless($c->config->{'show_full_commandline'} == 2 || ($c->config->{'show_full_commandline'} == 1 && $c->check_user_roles( "authorized_for_configuration_information" ))) {
        return({'message' => 'not authorized', 'description' => 'you are not authorized to view the command line', code => 403 });
    }
    my $data = [];
    my $all_commands = Thruk::Base::array2hash(\@{$c->db->get_commands()}, 'peer_key', 'name');
    my $services = $c->db->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), { "host_name" => $host, description => $service }, _livestatus_filter($c, 'hosts') ], %{_livestatus_options($c, "services")});
    for my $svc (@{$services}) {
        my $command = $c->db->expand_command('host' => $svc, 'service' => $svc, commands => $all_commands, 'source' => $c->config->{'show_full_commandline_source'} );
        push @{$data}, {
            'command_line'        => $command->{'line_expanded'},
            'check_command'       => $command->{'line'},
            'error'               => $command->{'note'},
            'host_name'           => $svc->{'host_name'},
            'service_description' => $svc->{'description'},
            'peer_key'            => $svc->{'peer_key'},
        };
    }
    return($data);
}

##########################################################
# REST PATH: GET /services/stats
# livestatus service statistics.
register_rest_path_v1('GET', qr%^/services?/stats$%mx, \&_rest_get_livestatus_services_stats);
sub _rest_get_livestatus_services_stats {
    my($c) = @_;
    return($c->db->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /services/totals
# livestatus service totals statistics.
# its basically a reduced set of /services/stats.
register_rest_path_v1('GET', qr%^/services?/totals$%mx, \&_rest_get_livestatus_services_totals);
sub _rest_get_livestatus_services_totals {
    my($c) = @_;
    return($c->db->get_service_totals_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /servicegroups
# lists livestatus servicegroups.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#servicegroups for details.
register_rest_path_v1('GET', qr%^/servicegroups?$%mx, \&_rest_get_livestatus_servicegroups);
sub _rest_get_livestatus_servicegroups {
    my($c) = @_;
    return($c->db->get_servicegroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups'), _livestatus_filter($c)  ], %{_livestatus_options($c, "servicegroups")}));
}

##########################################################
# REST PATH: GET /servicegroups/<name>
# lists servicegroups for given name.
# alias for /servicegroups?name=<name>
register_rest_path_v1('GET', qr%^/servicegroups?/([^/]+)$%mx, \&_rest_get_livestatus_servicegroups_by_name);
sub _rest_get_livestatus_servicegroups_by_name {
    my($c, undef, $servicegroup) = @_;
    my $data = $c->db->get_servicegroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups'), { "name" => $servicegroup }, _livestatus_filter($c) ], %{_livestatus_options($c, "servicegroups")});
    return($data);
}

##########################################################
# REST PATH: GET /servicegroups/<name>/stats
# hash of livestatus servicegroup statistics.
# alias for /services/stats?service_groups[gte]=<name>
register_rest_path_v1('GET', qr%^/servicegroups?/([^/]+)/stats$%mx, \&_rest_get_livestatus_servicegroup_stats);
sub _rest_get_livestatus_servicegroup_stats {
    my($c, undef, $group) = @_;
    return($c->db->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), [{ 'service_groups' => { '>=' => $group } }], _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /contacts
# lists livestatus contacts.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#contacts for details.
register_rest_path_v1('GET', qr%^/contacts?$%mx, \&_rest_get_livestatus_contacts);
sub _rest_get_livestatus_contacts {
    my($c) = @_;
    my $data = $c->db->get_contacts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'contact'), _livestatus_filter($c, 'contacts')  ], %{_livestatus_options($c, "contacts")});
    _expand_perfdata_and_custom_vars($c, $data, "contacts");
    return($data);
}

##########################################################
# REST PATH: GET /contacts/<name>
# lists contacts for given name.
# alias for /contacts?name=<name>
register_rest_path_v1('GET', qr%^/contacts?/([^/]+)$%mx, \&_rest_get_livestatus_contacts_by_name);
sub _rest_get_livestatus_contacts_by_name {
    my($c, undef, $contact) = @_;
    my $data = $c->db->get_contacts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'contacts'), { "name" => $contact }, _livestatus_filter($c) ], %{_livestatus_options($c)});
    return($data);
}

##########################################################
# REST PATH: GET /contactgroups
# lists livestatus contactgroups.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#contactgroups for details.
register_rest_path_v1('GET', qr%^/contactgroups?$%mx, \&_rest_get_livestatus_contactgroups);
sub _rest_get_livestatus_contactgroups {
    my($c) = @_;
    return($c->db->get_contactgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'contactgroups'), _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /contactgroups/<name>
# lists contactgroups for given name.
# alias for /contactgroups?name=<name>
register_rest_path_v1('GET', qr%^/contactgroups?/([^/]+)$%mx, \&_rest_get_livestatus_contactgroups_by_name);
sub _rest_get_livestatus_contactgroups_by_name {
    my($c, undef, $contactgroup) = @_;
    my $data = $c->db->get_contactgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'contactgroups'), { "name" => $contactgroup }, _livestatus_filter($c) ], %{_livestatus_options($c)});
    return($data);
}

##########################################################
# REST PATH: GET /timeperiods
# lists livestatus timeperiods.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#timeperiods for details.
register_rest_path_v1('GET', qr%^/timeperiods?$%mx, \&_rest_get_livestatus_timeperiods);
sub _rest_get_livestatus_timeperiods {
    my($c) = @_;
    return($c->db->get_timeperiods(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods'), _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /timeperiods/<name>
# lists timeperiods for given name.
# alias for /timeperiods?name=<name>
register_rest_path_v1('GET', qr%^/timeperiods?/([^/]+)$%mx, \&_rest_get_livestatus_timeperiods_by_name);
sub _rest_get_livestatus_timeperiods_by_name {
    my($c, undef, $timeperiod) = @_;
    my $data = $c->db->get_timeperiods(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods'), { "name" => $timeperiod }, _livestatus_filter($c) ], %{_livestatus_options($c)});
    return($data);
}

##########################################################
# REST PATH: GET /commands
# lists livestatus commands.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#commands for details.
register_rest_path_v1('GET', qr%^/commands?$%mx, \&_rest_get_livestatus_commands, ['admin']);
sub _rest_get_livestatus_commands {
    my($c) = @_;
    return($c->db->get_commands(filter => [_livestatus_filter($c)], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /commands/<name>
# lists commands for given name.
# alias for /commands?name=<name>
register_rest_path_v1('GET', qr%^/commands?/([^/]+)$%mx, \&_rest_get_livestatus_commands_by_name);
sub _rest_get_livestatus_commands_by_name {
    my($c, undef, $command) = @_;
    my $data = $c->db->get_commands(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'commands'), { "name" => $command }, _livestatus_filter($c) ], %{_livestatus_options($c)});
    return($data);
}

##########################################################
# REST PATH: GET /comments
# lists livestatus comments.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#comments for details.
register_rest_path_v1('GET', qr%^/comments?$%mx, \&_rest_get_livestatus_comments);
sub _rest_get_livestatus_comments {
    my($c) = @_;
    return($c->db->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), _livestatus_filter($c) ], %{_livestatus_options($c, "comments")}));
}

##########################################################
# REST PATH: GET /comments/<id>
# lists comments for given id.
# alias for /comments?id=<id>
register_rest_path_v1('GET', qr%^/comments?/([^/]+)$%mx, \&_rest_get_livestatus_comments_by_id);
sub _rest_get_livestatus_comments_by_id {
    my($c, undef, $id) = @_;
    my $data = $c->db->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), { "id" => $id }, _livestatus_filter($c) ], %{_livestatus_options($c, "comments")});
    return($data);
}

##########################################################
# REST PATH: GET /downtimes
# lists livestatus downtimes.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#downtimes for details.
register_rest_path_v1('GET', qr%^/downtimes?$%mx, \&_rest_get_livestatus_downtimes);
sub _rest_get_livestatus_downtimes {
    my($c) = @_;
    return($c->db->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'downtimes'), _livestatus_filter($c) ], %{_livestatus_options($c, "downtimes")}));
}

##########################################################
# REST PATH: GET /downtimes/<id>
# lists downtimes for given id.
# alias for /downtimes?id=<id>
register_rest_path_v1('GET', qr%^/downtimes?/([^/]+)$%mx, \&_rest_get_livestatus_downtimes_by_id);
sub _rest_get_livestatus_downtimes_by_id {
    my($c, undef, $id) = @_;
    my $data = $c->db->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'downtimes'), { "id" => $id }, _livestatus_filter($c) ], %{_livestatus_options($c, "downtimes")});
    return($data);
}

##########################################################
# REST PATH: GET /logs
# lists livestatus logs.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#log for details.
register_rest_path_v1('GET', qr%^/logs?$%mx, \&_rest_get_livestatus_logs);
sub _rest_get_livestatus_logs {
    my($c) = @_;
    my $filter = _livestatus_filter($c, 'logs');
    _append_time_filter($c, $filter);
    return(_post_process_logs($c, $c->db->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), $filter ], %{_livestatus_options($c)}, extra_columns => ['command_name'])));
}

##########################################################
# REST PATH: GET /notifications
# lists notifications based on logfiles.
# alias for /logs?class=3
register_rest_path_v1('GET', qr%^/notifications?$%mx, \&_rest_get_livestatus_notifications);
sub _rest_get_livestatus_notifications {
    my($c) = @_;
    my $filter = _livestatus_filter($c, 'logs');
    _append_time_filter($c, $filter);
    return(_post_process_logs($c, $c->db->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), { class => 3 }, $filter ], %{_livestatus_options($c)}, extra_columns => ['command_name'])));
}

##########################################################
# REST PATH: GET /hosts/<name>/notifications
# lists notifications for given host.
# alias for /logs?class=3&host_name=<name>
register_rest_path_v1('GET', qr%^/hosts?/([^/]+)/notifications?$%mx, \&_rest_get_livestatus_host_notifications);
sub _rest_get_livestatus_host_notifications {
    my($c, undef, $host) = @_;
    my $filter = _livestatus_filter($c, 'logs');
    _append_time_filter($c, $filter);
    return(_post_process_logs($c, $c->db->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), { class => 3, host_name => $host }, $filter ], %{_livestatus_options($c)}, extra_columns => ['command_name'])));
}

##########################################################
# REST PATH: GET /alerts
# lists alerts based on logfiles.
# alias for /logs?type[~]=^(HOST|SERVICE) ALERT
register_rest_path_v1('GET', qr%^/alerts?$%mx, \&_rest_get_livestatus_alerts);
sub _rest_get_livestatus_alerts {
    my($c) = @_;
    my $filter = _livestatus_filter($c, 'logs');
    _append_time_filter($c, $filter);
    return(_post_process_logs($c, $c->db->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), { type => { '~' => '^(HOST|SERVICE) ALERT$' } }, $filter ], %{_livestatus_options($c)})));
}

##########################################################
# REST PATH: GET /hosts/<name>/alerts
# lists alerts for given host.
# alias for /logs?type[~]=^(HOST|SERVICE) ALERT&host_name=<name>
register_rest_path_v1('GET', qr%^/hosts?/([^/]+)/alerts?$%mx, \&_rest_get_livestatus_host_alerts);
sub _rest_get_livestatus_host_alerts {
    my($c, undef, $host) = @_;
    my $filter = _livestatus_filter($c, 'logs');
    _append_time_filter($c, $filter);
    return(_post_process_logs($c, $c->db->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), { host_name => $host, type => { '~' => '^(HOST|SERVICE) ALERT$' } }, $filter ], %{_livestatus_options($c)})));
}

##########################################################
# REST PATH: GET /processinfo
# lists livestatus sites status.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#status for details.
register_rest_path_v1('GET', qr%^/processinfos?$%mx, \&_rest_get_livestatus_processinfos);
sub _rest_get_livestatus_processinfos {
    my($c) = @_;
    my $data = $c->db->get_processinfo(filter => [ _livestatus_filter($c) ], %{_livestatus_options($c)});
    $data = [values(%{$data})] if ref $data eq 'HASH';
    return($data);
}

##########################################################
# REST PATH: GET /processinfo/stats
# lists livestatus sites statistics.
# see https://www.naemon.io/documentation/usersguide/livestatus.html#status for details.
register_rest_path_v1('GET', qr%^/processinfos?/stats$%mx, \&_rest_get_livestatus_processinfos_stats);
sub _rest_get_livestatus_processinfos_stats {
    my($c) = @_;
    return($c->db->get_extra_perf_stats(filter => [ _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /checks/stats
# lists host / service check statistics.
register_rest_path_v1('GET', qr%^/checks?/stats$%mx, \&_rest_get_livestatus_checks_stats);
sub _rest_get_livestatus_checks_stats {
    my($c) = @_;
    return($c->db->get_performance_stats(filter => [ _livestatus_filter($c) ], %{_livestatus_options($c)}));
}

##########################################################
# REST PATH: GET /lmd/sites
# lists connected sites. Only available if LMD (`use_lmd`) is enabled.
register_rest_path_v1('GET', qr%^/lmd/sites?$%mx, \&_rest_get_lmd_sites);
sub _rest_get_lmd_sites {
    my($c) = @_;
    my $data = [];
    if($c->config->{'use_lmd_core'}) {
        $data = $c->db->get_sites();
    }
    return($data);
}

##########################################################
sub _match_complex_filter {
    my($data, $filter, $missed, $nr) = @_;
    if(ref $filter eq 'ARRAY') {
        # simple and filter from list
        for my $f (@{$filter}) {
            return unless _match_complex_filter($data, $f, $missed, $nr);
        }
        return 1;
    }
    if(ref $filter eq 'HASH') {
        for my $key (sort keys %{$filter}) {
            # or filter from hash: { -or => [...] }
            if($key eq '-or') {
                for my $f (@{$filter->{$key}}) {
                    return 1 if _match_complex_filter($data, $f, $missed, $nr);
                }
                return;
            }
            # and filter from hash: { and => [...] }
            if($key eq '-and') {
                return _match_complex_filter($data, $filter->{$key}, $missed, $nr);
            }
            my $val = $filter->{$key};
            if(ref $val eq 'HASH') {
                for my $op (%{$val}) {
                    $missed->{$key}->{$nr} = 1 if !defined $data->{$key};
                    return(_compare($op, $data->{$key}, $val->{$op}));
                }
                return;
            }
        }
    }
    require Data::Dumper;
    confess("unknown filter: ".Data::Dumper::Dumper($filter));
}

##########################################################
sub _compare {
    my($op, $data, $val) = @_;

    ## no critic
    no warnings;
    ## use critic
    my @filtered;
    if($op eq '=') {
        if(ref $data eq 'ARRAY') {
            return 1 if(scalar @{$data} == 1 && lc($data->[0]) eq lc($val));
            return;
        }
        return 1 if lc($data) eq lc($val);
        return;
    }
    elsif($op eq '!=') {
        if(ref $data eq 'ARRAY') {
            return 1 if(scalar @{$data} != 1 || lc($data->[0]) ne lc($val));
            return;
        }
        return 1 if lc($data) ne lc($val);
        return;
    }
    elsif($op eq '~') {
        if(ref $data eq 'ARRAY') {
            my $found;
            for my $v (@{$data}) {
                ## no critic
                if($v =~ m/$val/) {
                    $found = 1;
                    last;
                }
                ## use critic
            }
            return $found;
        } else {
            ## no critic
            return 1 if $data =~ m/$val/;
            ## use critic
        }
        return;
    }
    elsif($op eq '~~') {
        if(ref $data eq 'ARRAY') {
            my $found;
            for my $v (@{$data}) {
                ## no critic
                if($v =~ m/$val/i) {
                    $found = 1;
                    last;
                }
                ## use critic
            }
            return $found;
        } else {
            ## no critic
            return 1 if $data =~ m/$val/i;
            ## use critic
        }
        return;
    }
    elsif($op eq '!~') {
        if(ref $data eq 'ARRAY') {
            my $found;
            for my $v (@{$data}) {
                ## no critic
                if($v =~ m/$val/) {
                    $found = 1;
                    last;
                }
                ## use critic
            }
            return !$found;
        } else {
            ## no critic
            return 1 if $data !~ m/$val/;
            ## use critic
            return;
        }
    }
    elsif($op eq '!~~') {
        if(ref $data eq 'ARRAY') {
            my $found;
            for my $v (@{$data}) {
                ## no critic
                if($v =~ m/$val/i) {
                    $found = 1;
                    last;
                }
                ## use critic
            }
            return !$found;
        } else {
            ## no critic
            return 1 if $data !~ m/$val/i;
            ## use critic
            return;
        }
    }
    elsif($op eq '>') {
        if(ref $data eq 'ARRAY') {
            die("operator '>' not implemented for lists, use '>=' to match list items.");
        }
        return 1 if $data > $val;
        return;
    }
    elsif($op eq '<') {
        if(ref $data eq 'ARRAY') {
            die("operator '>' not implemented for lists, use '>=' to match list items.");
        }
        return 1 if $data < $val;
    }
    elsif($op eq '>=') {
        if(ref $data eq 'ARRAY') {
            my $found;
            for my $v (@{$data}) {
                if(lc($v) eq lc($val)) {
                    $found = 1;
                    last;
                }
            }
            return $found;
        } else {
            return 1 if $data >= $val;
            return;
        }
    }
    elsif($op eq '<=' || $op eq '!>=') {
        if(ref $data eq 'ARRAY') {
            my $found = 0;
            for my $v (@{$data}) {
                if(lc($v) eq lc($val)) {
                    $found = 1;
                }
            }
            return !$found;
        } else {
            return 1 if $data <= $val;
            return;
        }
    } else {
        die("unsupported operator: ".$op);
    }
    return;
}

##########################################################
sub _is_failed {
    my($data) = @_;
    if(ref $data eq 'HASH' && $data->{'code'} && $data->{'message'}) {
        return 1;
    }
    return;
}

##########################################################
sub _add_comment_downtimes {
    my($row, $target_column, $list) = @_;
    $row->{$target_column} = "";
    return unless($list && ref $list eq 'ARRAY');
    my $res = [];
    for my $d (@{$list}) {
        push @{$res}, sprintf("id:%d author:%s: text:%s", $d->[0], $d->[1], $d->[2])
    }
    $row->{$target_column} = join(", ", @{$res});
    return;
}

##########################################################
sub _post_process_logs {
    my($c, $logs) = @_;

    if(!$logs || scalar @{$logs} == 0) {
        return($logs);
    }

    # when using logcache, there is no plugin_output, so add it here
    for my $l (@{$logs}) {
        my $output = Thruk::Utils::Filter::log_line_plugin_output($l);
        $l->{'plugin_output'} = $output;
    }

    return($logs);
}

##########################################################
sub _parse_columns_data {
    my($raw) = @_;
    my $columns = [];
    for my $c (@{$raw}) {
        my $name = $c;
        my $alias = $c;
        if($c =~ m/^(.+)\s+as\s+(.*?)$/gmx) {
            $name  = $1;
            $alias = $2;
        } elsif($c =~ m/^(.+):(.*?)$/gmx) {
            $name  = $1;
            $alias = $2;
        }
        my $orig = $name;

        # extract functions from name
        my $functions = [];
        while($name =~ m|^(\w+)\((.*)\)$|mx) {
            my $f = $1;
            $name = $2;
            my @arg = _split_by_comma($name);
            for (@arg) {
                $_ =~ s/^\s+//gmx;
                $_ =~ s/\s+$//gmx;
            }
            $name = shift @arg;
            push(@{$functions}, [$f, \@arg]);
        }
        # functions must be applied in reverse order
        @{$functions} = reverse @{$functions};
        push @{$columns}, {
            column => $name,
            alias  => $alias,
            orig   => $orig,
            func   => $functions,
        };
    }
    return $columns;
}

##########################################################
sub _split_columns {
    my($raw) = @_;
    my $columns = [];
    for my $col (@{Thruk::Base::list($raw)}) {
        push @{$columns}, _split_by_comma($col);
    }
    for (@{$columns}) {
        $_ =~ s/^\s+//gmx;
        $_ =~ s/\s+$//gmx;
    }
    return($columns);
}

##########################################################
# split columns by comma, but not when comma is in brackets or quotes
sub _split_by_comma {
    my($col) = @_;
    my @res;
    my $cur = "";
    my($inBracket, $inSingle, $inDbl) = (0,0,0);
    for my $chr (split//mx, $col) {
        if($chr eq '(') {
            $inBracket++;
            $cur .= $chr;
            next;
        }
        if($chr eq ')') {
            $inBracket--;
            $cur .= $chr;
            next;
        }
        if($chr eq '"') {
            $inDbl = !$inDbl;
            $cur .= $chr;
            next;
        }
        if($chr eq "'") {
            $inSingle = !$inSingle;
            $cur .= $chr;
            next;
        }
        if($chr eq "," && !$inBracket && !$inSingle && !$inDbl) {
            if($cur ne '') {
                push @res, $cur;
                $cur = '';
            }
            next;
        }
        $cur .= $chr;
    }
    if($cur ne '') {
        push @res, $cur;
    }
    return @res;
}

##########################################################

1;
