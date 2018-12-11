package Monitoring::Config::Object::Parent;

use strict;
use warnings;
use Carp;
use Digest::MD5 qw(md5_hex);
use Storable qw(dclone);
use Scalar::Util qw/weaken/;
use Monitoring::Config::Help;

=head1 NAME

Monitoring::Config::Object::Parent - Object Configuration Template

=head1 DESCRIPTION

Object Configuration Template

=head1 METHODS

=cut


##########################################################

=head2 parse

parse the object config

=cut
sub parse {
    my($self, $fields) = @_;
    $fields = $self->{'default'} unless defined $fields;
    my $parse_errors = [];

    delete $self->{'name'};

    for my $attr (keys %{$self->{'conf'}}) {
        my $value = $self->{'conf'}->{$attr};

        # empty values are valid
        $value = '' unless defined $value;

        if(defined $fields->{$attr}) {
            my $field = $fields->{$attr};

            # is it an alias?
            if($field->{'type'} eq 'ALIAS') {
                delete $self->{'conf'}->{$attr};

                $attr  = $field->{'name'};
                confess("alias does not exist: ".$attr." -> ".$field->{'name'}." ") unless defined $fields->{$attr}->{'type'};
                $field = $fields->{$attr};

                $self->{'conf'}->{$attr} = $value;
            }

            if($field->{'type'} eq 'LIST' or $field->{'type'} eq 'ENUM') {
                if(defined $value) {
                    my @list = split/\s*,\s*/mxo, $value;
                    # remove empty elements
                    @list = grep {!/^\s*$/mxo} @list;
                    $self->{'conf'}->{$attr} = \@list;
                } else {
                    $self->{'conf'}->{$attr} = [];
                }
            }
        } elsif(substr($attr, 0, 1) eq '_') {
            $self->{'conf'}->{$attr} = $value;
        } else {
            if($self->{'type'} eq 'timeperiod' and $value =~ m/^\d{1,2}:\d{1,2}\-\d{1,2}:\d{1,2}/gmx) {
                $self->{'conf'}->{$attr} = $value;
            } else {
                if($self->{'disabled'}) {
                    push @{$self->{'comments'}}, $attr.' '.$value;
                } else {
                    push @{$parse_errors}, "unknown attribute: $attr for object type ".$self->{'type'}." in ".Thruk::Utils::Conf::_link_obj($self);
                }
            }
        }
    }

    return $parse_errors;
}

##########################################################

=head2 disable

disable this object

=cut
sub disable {
    my($self, $val) = @_;
    $val = 1 unless defined $val;
    $self->{'file'}->{'changed'} = 1 if $self->{'disabled'} != $val;
    $self->{'disabled'} = $val;
    return;
}

##########################################################

=head2 as_text

in scalar context returns this object as text.

in list context, returns [$text, $nr_comment_lines, $nr_object_lines]

=cut
sub as_text {
    my($self) = @_;

    confess("uninitialized") unless $Monitoring::Config::format_values;
    my $disabled = $self->{'disabled'} ? '#' : '';

    my $cfg = $Monitoring::Config::save_options;

    # save comments
    my $nr_object_lines  = 0;
    my $text             = Monitoring::Config::Object::format_comments($self->{'comments'});
    my $nr_comment_lines = scalar @{$self->{'comments'}};

    # remove completly empty comments
    if(join('', @{$self->{'comments'}}) =~ /^\s*$/mx) {
        $nr_comment_lines = 0;
        $text = "";
    }

    # save object itself
    $text .= $disabled;
    $text .= "define ".$self->{'type'}." {\n"; $nr_object_lines++;

    for my $key (@{$self->get_sorted_keys()}) {
        my $value;
        my $type = defined $self->{'default'}->{$key} ? $self->{'default'}->{$key}->{'type'} : '';
        if($type eq 'LIST' || $type eq 'ENUM') {
            $value = join($cfg->{'list_join_string'}, @{$self->{'conf'}->{$key}});
        } else {
            $value = $self->{'conf'}->{$key} // '';

            # break very long lines
            if($key eq 'command_line' and $cfg->{'break_long_arguments'} and length($key) + length($value) > 120) {
                my $long_command = $self->_break_long_command($key, $value, $disabled);
                $text .= $disabled.join(" \\\n".$disabled, @{$long_command})."\n";
                $nr_object_lines += scalar @{$long_command};
                if($self->{'inl_comments'}->{$key}) {
                    chomp($text);
                    my $ind      = rindex($text, "\n");
                    my $lastline = substr($text, $ind+1);
                    $text        = substr($text, 0, $ind);
                    $text       .= "\n";
                    $text       .= sprintf $Monitoring::Config::format_comments, $lastline, $self->{'inl_comments'}->{$key};
                    $text       .= "\n";
                }
                next;
            }
        }

        $text .= $disabled;
        if($self->{'inl_comments'}->{$key}) {
            my $line = sprintf $Monitoring::Config::format_values, "", $key, $value;
            $text   .= sprintf $Monitoring::Config::format_comments, $line, $self->{'inl_comments'}->{$key};
            $text .= "\n";
        }
        elsif($value ne '') {
            $text .= sprintf $Monitoring::Config::format_values_nl, "", $key, $value;
        } else {
            # empty values are allowed
            $text .= sprintf $Monitoring::Config::format_keys, "", $key;
        }
        $nr_object_lines++;
    }
    $text .= $disabled;
    $text .= "}\n\n";
    $nr_object_lines += 2;

    if(wantarray) {
        return($text, $nr_comment_lines, $nr_object_lines);
    }
    return $text;
}

##########################################################

=head2 is_template

returns 1 if this is a template

=cut
sub is_template {
    my($self) = @_;
    return 1 if (defined $self->{'conf'}->{'register'} and $self->{'conf'}->{'register'} == 0);
    return 1 if $self->get_template_name();
    return 0;
}

##########################################################

=head2 get_template_name

return the objects template name or undef

=cut
sub get_template_name {
    my($self) = @_;
    # in case there is no name set, use the primary name
    if(defined $self->{'conf'}->{'register'} && $self->{'conf'}->{'register'} == 0 && !defined $self->{'conf'}->{'name'} && defined $self->{'conf'}->{$self->{'primary_key'}}) {
        return $self->{'conf'}->{$self->{'primary_key'}};
    }
    return $self->{'conf'}->{'name'};
}


##########################################################

=head2 get_name

return the objects name

=cut
sub get_name {
    my $self = shift;
    if($self->is_template()) {
        return $self->get_template_name();
    }
    return $self->get_primary_name();
}


##########################################################

=head2 get_id

return the objects id

=cut
sub get_id {
    my $self = shift;
    return $self->{'id'};
}


##########################################################

=head2 get_type

return the objects type

=cut
sub get_type {
    my $self = shift;
    return $self->{'type'};
}

##########################################################

=head2 must_have_name

returns true if object must have a name

=cut
sub must_have_name {
    my $self = shift;
    return 0 if $self->{'can_have_no_name'};
    return 1;
}


##########################################################

=head2 get_primary_name

return the primary objects name

=cut
sub get_primary_name {
    my($self, $full, $conf, $fallback) = @_;
    $full = 0 unless $full;
    $conf = $self->{'conf'} unless $conf;

    return $fallback if defined $fallback;

    return if defined $conf->{'register'} and $conf->{'register'} == 0;

    return $conf->{$self->{'primary_key'}} unless ref $self->{'primary_key'};

    unless($full) {
        return $self->{'name'} if defined $self->{'name'};
    }

    # multiple primary keys
    if(ref $self->{'primary_key'}->[1] eq '') {
        my @keys;
        for my $key (@{$self->{'primary_key'}}) {
            push @keys, $conf->{$key} if defined $conf->{$key};
        }
        push @keys, $self->{'name'} if defined $self->{'name'};
        return \@keys;
    }

    # secondary keys
    my $primary = $self->{'name'} || $conf->{$self->{'primary_key'}->[0]};

    return $primary unless $full;
    my $secondary = [];
    for my $key (@{$self->{'primary_key'}->[1]}) {
        next unless defined $conf->{$key};
        push @{$secondary}, [ $key, $conf->{$key} ];
    }
    return([$primary, $secondary]);
}

##########################################################

=head2 get_primary_name_as_text

return the primary name as text

=cut

sub get_primary_name_as_text {
    my($self, $fallback) = @_;
    return $fallback;
}

##########################################################

=head2 get_long_name

return the objects name plus alias

=cut
sub get_long_name {
    my($self, $fallback, $seperator) = @_;
    $seperator = ' - ' unless defined $seperator;
    my $name =  $self->get_name();
    if(defined $self->{'conf'}->{'alias'} and $self->{'conf'}->{'alias'} ne $name) {
        return $name.$seperator.$self->{'conf'}->{'alias'};
    }
    return $name || $fallback;
}


##########################################################

=head2 get_sorted_keys

return the sorted config keys for this object

=cut
sub get_sorted_keys {
    my($self, $conf) = @_;
    defined $Monitoring::Config::key_sort or confess('uninitialized');

    my @keys;
    if(!defined $conf) {
        @keys = keys %{$self->{'conf'}};
    } else {
        if(ref $conf eq 'HASH') {
            @keys = keys %{$conf};
        } else {
            @keys = @{$conf};
        }
    }
    return([sort $Monitoring::Config::key_sort @keys]);
}

##########################################################

=head2 _sort_by_object_keys

sort function for object keys

=cut
sub _sort_by_object_keys {
    my($attr_keys, $cust_var_keys) = @_;

    my $order_cache = {};
    my $max         = scalar @{$attr_keys} + 5;

    my $num = $max;
    for my $ord (@{$attr_keys}) {
        $order_cache->{$ord} = $num;
        $num--;
    }

    return sub {
        my $num_a = $order_cache->{$a} || 0;
        my $num_b = $order_cache->{$b} || 0;
        if($num_a > $num_b) { return -$num_a; }
        if($num_b > $num_a) { return  $num_b; }

        my $result = $a cmp $b;

        if(substr($a, 0, 1) eq '_') {
            if(substr($b, 0, 1) eq '_') {
                # prefer some custom variables
                my $cust_order = $cust_var_keys;
                my $cust_num   = scalar @{$cust_var_keys} + 3;
                for my $ord (@{$cust_order}) {
                    if($a eq $ord) { return -$cust_num; }
                    if($b eq $ord) { return  $cust_num; }
                    $cust_num--;
                }
                return $result;
            }
            return -$result;
        }
        elsif(substr($b, 0, 1) eq '_') {
            return -$result;
        }

        return $result;
    };
}

##########################################################

=head2 get_computed_config

return computed config for this object

=cut
sub get_computed_config {
    my($self, $objects, $keep_plus) = @_;

    my $cache = $self->{'cache'}->{'computed'}->{$self->{'id'}};
    return(@{$cache}) if defined $cache;

    my $conf = dclone($self->{'conf'});
    my $templates = $self->get_used_templates($objects);
    for my $tname (@{$templates}) {
        my $t = $objects->get_template_by_name($self->{'type'}, $tname);
        if(defined $t) {
            my($tconf_keys, $tconf) = $t->get_computed_config($objects, 1);
            for my $key (keys %{$tconf}) {
                next if $key eq 'name';
                next if $key eq 'register';
                if(!defined $conf->{$key}) {
                    $conf->{$key} = $tconf->{$key};
                }
                if(defined $self->{'default'}->{$key}
                         and  $self->{'default'}->{$key}->{'type'} eq 'LIST')
                {
                    if(scalar @{$conf->{$key}} > 0 && $conf->{$key}->[0] && substr($conf->{$key}->[0], 0, 1) eq '+') {
                        # merge uniq list elements together
                        my $list           = dclone($tconf->{$key});
                        $tconf->{$key}->[0] =~ s/^\+//gmx;
                        $conf->{$key}->[0] = substr($conf->{$key}->[0], 1) if(substr($conf->{$key}->[0],0,1) eq '+');
                        @{$conf->{$key}}   = sort @{Thruk::Utils::array_uniq([@{$list}, @{$conf->{$key}}])};
                        $conf->{$key}->[0] = '+'.$conf->{$key}->[0];
                        $conf->{$key}->[0] =~ s/^\++/+/gmx;
                    }
                }
            }
        }
    }
    delete $conf->{'use'};

    # remove + signs
    if(!$keep_plus) {
        for my $key (keys %{$conf}) {
            if( defined $self->{'default'}->{$key}
                    and $self->{'default'}->{$key}->{'type'} eq 'LIST'
                    and defined $conf->{$key}->[0]
                    and substr($conf->{$key}->[0], 0, 1) eq '+')
            {
                $conf->{$key}->[0] = substr($conf->{$key}->[0], 1);
            }
        }
    }

    defined $Monitoring::Config::key_sort or confess('uninitialized');
    my @keys = sort $Monitoring::Config::key_sort keys %{$conf};
    $self->{'cache'}->{'computed'}->{$self->{'id'}} = [\@keys, $conf];
    return(\@keys, $conf);
}


##########################################################

=head2 get_default_keys

return the sorted default keys for this object

=cut
sub get_default_keys {
    my $self = shift;
    my $categories = {};
    for my $key (keys %{$self->{'default'}}) {
        next if $self->{'default'}->{$key}->{'type'} eq 'DEPRECATED';
        next if $self->{'default'}->{$key}->{'type'} eq 'ALIAS';
        my $cat = $self->{'default'}->{$key}->{'cat'} || 'Misc';
        $categories->{$cat} = [] unless defined $categories->{$cat};
        push @{$categories->{$cat}}, $key;
    }

    defined $Monitoring::Config::key_sort or confess('uninitialized');
    my @result;
    for my $cat (sort _sort_by_category_keys keys %{$categories}) {
        my @keys = sort $Monitoring::Config::key_sort @{$categories->{$cat}};
        push @result, { name => $cat, keys => \@keys };
    }

    if($self->{'has_custom'}) {
        push @result, { name => 'Custom Variables', keys => ['customvariable'] };
    }

    return \@result;
}


##########################################################

=head2 get_help

return the help for given attribute

=cut
sub get_help {
    my($self, $attr) = @_;
    return Monitoring::Config::Help::get_config_help($self->{'type'}, $attr);
}


##########################################################

=head2 get_data_from_param

get data hash from post parameter

=cut
sub get_data_from_param {
    my $self     = shift;
    my $param    = shift;
    my $data     = shift || {};
    my $defaults = $self->{'default'};

    my @param_keys;
    my $new_param = {};
    for my $key (sort keys %{$param}) {
        next unless $key =~ m/^obj\./mx;
        my $value = $param->{$key};
        $key =~ s/^obj\.//mx;
        $key =~ s/\.\d+$//mx;

        # remove whitespace
        $key   =~ s/^\s*(.*?)\s*$/$1/gmxo;
        $value =~ s/^\s*(.*?)\s*$/$1/gmxo unless ref $value;

        push @param_keys, $key;
        $new_param->{$key} = $value;
    }

    my %seen = ();
    my @uniq = sort( grep { !$seen{$_}++ } (@param_keys, keys %{$self->{'conf'}}) );
    for my $key (@uniq) {
        my $value = $new_param->{$key};
        next unless defined $value;

        if($self->{'type'} eq 'timeperiod' and $value =~ m/\d{1,2}:\d{1,2}\-\d{1,2}:\d{1,2}/gmx) {
            # add leading zeros to timestamps
            $value =~ s/^(\d):/0$1:/gmx;
            $value =~ s/,\s*(\d):/,0$1:/gmx;
            $value =~ s/\-(\d):/-0$1:/gmx;
            $value =~ s/:(\d)\-/:0$1-/gmx;
            $value =~ s/:(\d)$/:0$1/gmx;
            $value =~ s/,\s*/,/gmx;
        }

        if(!defined $defaults->{$key}) {
            if(substr($key, 0, 1) eq '_') {
                $key = uc $key; # custom vars are all uppercase
                $data->{$key} = $value;
            }
            elsif($self->{'type'} eq 'timeperiod') {
                $data->{$key} = $value;
            }
            next;
        }
        next if $defaults->{$key}->{'type'} eq 'DEPRECATED';

        if( $defaults->{$key}->{'type'} eq 'LIST' ) {
            if(ref $value eq 'ARRAY') {
                $data->{$key} = $value;
            } else {
                my @list = split(/\s*,\s*/mx, $value);
                # remove empty elements
                @list = grep {!/^\s*$/mx} @list;
                $data->{$key} = \@list;
            }
        }
        elsif( $defaults->{$key}->{'type'} eq 'ENUM' ) {
            my @values;
            if(ref $value eq 'ARRAY') {
                @values = @{$value};
            } else {
                @values = split(/\s*,\s*/mx, $value);
            }
            $data->{$key} = [];
            for my $v (@values) {
                next if $v eq 'noop';
                next if $v =~ m/^\s*$/mx;
                push @{$data->{$key}}, $v;
            }
        }
        elsif( $defaults->{$key}->{'type'} eq 'COMMAND' ) {
            # when there are arguments, join them with a !
            if($param->{'obj.'.$key.'.2'} !~ m/^\s*$/mx) {
                $data->{$key} = $param->{'obj.'.$key.'.1'}.'!'.$param->{'obj.'.$key.'.2'};
            }
            # just use the command else
            else {
                $data->{$key} = $param->{'obj.'.$key.'.1'};
            }
            delete $param->{$key.'.2'};
        }
        else {
            $data->{$key} = $value;
        }
    }
    return $data;
}


##########################################################

=head2 has_object_changed

check if there are any differences between this object and a reference object

=cut
sub has_object_changed {
    my $self = shift;
    my $data = shift;

    my %seen = ();
    my @uniq = sort( grep { !$seen{$_}++ } (keys %{$data}, keys %{$self->{'conf'}}) );

    for my $key (@uniq) {
        return 1 if !defined $data->{$key};
        return 1 if !defined $self->{'conf'}->{$key};

        my $test1 = $data->{$key};
        if(ref $test1 eq 'ARRAY') { $test1 = join(',', @{$test1}) }

        my $test2 = $self->{'conf'}->{$key};
        if(ref $test2 eq 'ARRAY') { $test2 = join(',', @{$test2}) }

        return 1 if $test1 ne $test2;
    }
    return;
}


##########################################################

=head2 get_used_templates

return all recursive used templates

=cut
sub get_used_templates {
    my $self    = shift;
    my $objects = shift;
    my $lvl     = shift || 0;

    my @templates;
    return \@templates unless defined $self->{'conf'}->{'use'};

    # avoid deep recursion
    return \@templates if $lvl > 50;

    my $cat  = $self->{'type'};

    for my $template (@{$self->{'conf'}->{'use'}}) {
        push @templates, $template;
        my $tmpl = $objects->get_template_by_name($cat, $template);
        if(defined $tmpl) {
            push @templates, @{$tmpl->get_used_templates($objects, ++$lvl)};
        }
    }
    return \@templates;
}


##########################################################

=head2 get_resolved_config

returns config hash with templates resolved

=cut
sub get_resolved_config {
    my($self, $objects) = @_;

    confess("no objects") unless defined $objects;

    return $self->{'conf'} unless defined $self->{'conf'}->{'use'};

    my $conf = {};
    for my $key (keys %{$self->{'conf'}}) {
        next if $key eq 'use';
        $conf->{$key} = $self->{'conf'}->{$key};
    }

    # add resolved templates
    for my $tname (@{$self->{'conf'}->{'use'}}) {
        my $tmpl;
        my $tpl_id = $objects->{'byname'}->{'templates'}->{$self->get_type()}->{$tname};
        if(defined $tpl_id) {
            $tmpl = $objects->{'byid'}->{$tpl_id};
        }
        if(defined $tmpl) {
            my $tpl_conf = $tmpl->get_resolved_config($objects);
            for my $key (keys %{$tpl_conf}) {
                next if defined $conf->{$key};
                next if $key eq 'register';
                next if $key eq 'name';
                $conf->{$key} = $tpl_conf->{$key};
            }
        }
    }

    return $conf;
}


##########################################################

=head2 set_uniq_id

sets a uniq id

=cut
sub set_uniq_id {
    my($self, $objects) = @_;

    if(!defined $self->{'id'} || $self->{'id'} eq 'new') {
        $self->{'id'} = $self->_make_id();
    }

    # make sure id is uniq
    my $nr = 5;
    while(defined $objects->{'byid'}->{$self->{'id'}} and $objects->{'byid'}->{$self->{'id'}} != $self) {
        $self->{'id'} = $self->_make_id(++$nr);
        if(length($self->{'id'}) < $nr) {
            $self->{'id'} = $self->{'id'} . int(rand(10000));
        }
        if($nr > 100) {
            die(sprintf("cannot assign uniq id to %s in %s:%i", $self->get_name(), $self->{'file'}->{'path'}, $self->{'line'}));
        }
    }
    return $self->{'id'};
}


##########################################################

=head2 set_name

sets new name for this object

=cut
sub set_name {
    my($self, $newname) = @_;

    die("no new name!") unless defined $newname;

    my $conf = $self->{'conf'};
    if(defined $conf->{'register'} and $conf->{'register'} == 0) {
        $conf->{'name'} = $newname;
        return;
    }

    if(ref $self->{'primary_key'} eq '') {
        $conf->{$self->{'primary_key'}} = $newname;
    }

    return;
}

##########################################################

=head2 set_file

sets a new file

=cut
sub set_file {
    my($self, $newfile) = @_;
    $self->{'file'} = $newfile;
    # otherwise we create circular references
    weaken $self->{'file'};
    return;
}


##########################################################

=head2 _sort_by_category_keys

sort function for category keys

=cut
sub _sort_by_category_keys {

    my $num = 20;
    my $order = [
        "Basic",
        "Extended",
        "Checks",
        "Contacts",
        "Notifications",
        "Ext Info",
        "Flapping",
        "Map",
        "Misc",
    ];
    for my $ord (@{$order}) {
        if($a eq $ord) { return -$num; }
        if($b eq $ord) { return  $num; }
        $num--;
    }

    return $a cmp $b;
}


##########################################################

=head2 _make_id

return a uniq id for this object

=cut
sub _make_id {
    my $self   = shift;
    my $length = shift || 5;

    my $digest = substr(md5_hex($self->{'file'}->{'path'}.':'.$self->{'line'}), 0, $length);

    return $digest;
}

##########################################################
sub _count_quotes {
    my($string, $char, $number) = @_;
    my @chars = split//mx, $string;
    my $size  = scalar @chars - 1;
    for my $x (0..$size) {
        if($chars[$x] eq $char and $chars[$x-1] ne '\\') {
            if($number) {
                $number--;
            } else {
                $number++;
            }
        }
    }
    return($number, $char);
}

##########################################################
sub _break_long_command {
    my($self,$key,$value) = @_;
    my @text;
    my @chunks = split(/(\s+[\-]{1,2}\w+|\s+[\|]{1}\s+|\s+>>\s*)/mx ,$value);
    my $first = shift @chunks;
    $first =~ s/\s+$//gmx;
    push @text, sprintf("  %-30s %s", $key, $first);
    my $size = scalar @chunks;
    my $arg  = 1;
    my $x    = 0;
    my $line = '';
    while($x < $size) {
        my $chunk = $chunks[$x];
        if($arg) {
            $chunk =~ s/^\s+//gmx;
            if(index($chunk, '-') == 0) { $chunk = '  '.$chunk; }
            if(index($chunk, '>') == 0) { $chunk = '  '.$chunk; }
            $line .= sprintf "%-33s %s", '', $chunk;
            $arg   = 0;
            push @text, $line if $x == $size - 1; # make sure last option is not left behind
        } else {
            $line    .= $chunk;
            my $si    = index($chunk, "'");
            my $di    = index($chunk, '"');
            my $char  = '';
            my $count = 0;
            if(    $si == -1 and $di == -1)               { $char = '';  }
            elsif(($si == -1 and $di >=  0) or ($di != -1 and $di < $si)) { $char = '"'; }
            elsif(($di == -1 and $si >=  0) or ($si != -1 and $si < $di)) { $char = "'"; }
            if($char) {
                # append all chunks till our quotes are balanced
                ($count, $char) = _count_quotes($chunk, $char, $count);
                while($count > 0) {
                    last unless defined $chunks[$x+1];
                    $x++;
                    $chunk = $chunks[$x];
                    $line .= $chunk;
                    ($count, $char) = _count_quotes($chunk, $char, $count);
                }
            }

            $arg = 1;
            push @text, $line;
            $line = '';
        }
        $x++;
    }
    return \@text;
}

##########################################################
sub _business_impact_keys {
    return [
        "Business Critical",     # 5
        "Top Production",        # 4
        "Production",            # 3
        "Standard",              # 2
        "Testing",               # 1
        "Development",           # 0
    ];
}

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
