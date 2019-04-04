use strict;
use warnings;
use Test::More;
use Thruk::Utils;
use File::Slurp qw/read_file/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $filter = $ARGV[0];
my $whitelist_vars = Thruk::Utils::array2hash([qw/
    theme url_prefix logo_path_prefix filebranch version branch extjs_version jquery_ui
    date.now pd referer cs j js jsfiles page class statusclass statusClass rowclass hostclass serviceclass
    loopclass body_class param.breakdown url defaults.$key.link
    c.config.useragentcompat c.stash.last_graph_type c.config.cgi_cfg.notes_url_target
    c.config.cgi_cfg.action_url_target avgClass log.class rowclasses show_sitepanel extrabodyclass b.cls
    remote_thruk_url bug_email_rcpt start_page main target prio pnp_url c.config.extra_version_link
    histou_frame_url histou_url c.stash.help_topic n.annotation peer_key passive_icon svcbg
    get_user_token(c) object.get_id() object.get_id object.get_type() svc.get_id()
    obj_id start end servicelink l.url plugin.url r.link link action_url home_link n.node_url
    c.config.use_feature_core_scheduling prefix paneprefix style counter service_comment_count
    sites.up sites.disabled sites.down pb_options.lineheight par desc refresh_rate imgsize
    h.current_notification_number s.current_notification_number how_far_back audiofile
    host.$host_icon_image_alt host_comment_count param_name state_color last_col
    crit.text crit.value icon pic pnpdata onchange
    day monthday hour hours min key helpkey
    has_bp bp.fullid md5 rd.file b.basefile
    host_health_pic service_health_pic health_perc service_perc
    a.t1 a.t2 nr id first_remaining
    s_status f d i j x key size head_height image_width state status image_height
/]);
my $whitelist_regex = [
    qr/^\w+\.(id|nr)$/,
    qr/^\w+\.href$/,
    qr/^\w+\.peer_key$/,
    qr/^\w+\.target$/,
    qr/^\w+\.width$/,
    qr/^\w+\.height$/,
    qr/^\w+\.notes_url$/,
    qr/^\w+\.notes_url_expanded$/,
    qr/^\w+\.action_url$/,
    qr/^\w+\.comment_count$/,
    qr/^\w+\.keys\.size$/,
    qr/^\w+\.action_url_expaned$/,
    qr/^\w+\.icon_image$/,
    qr/^[\w\$\.]+icon_image_expanded$/,
    qr/^date.now[\s\d\+\*\-]+$/,
    qr/^loop\.\w+$/,
    qr/^a\.(x|y)\d*$/,
    qr/^action_icon\(/,
];
my @dirs = glob("./templates ./plugins/plugins-available/*/templates ./themes/themes-available/*/templates");
for my $dir (@dirs) {
    check_templates($dir.'/');
}
@dirs = glob("./lib ./plugins/plugins-available/*/lib");
for my $dir (@dirs) {
    check_libs($dir.'/');
}
done_testing();

sub check_templates {
    my($dir) = @_;
    my(@files, @folders);
    opendir(my $dh, $dir) || die $!;
    while(my $file = readdir $dh) {
        next if $file eq '.';
        next if $file eq '..';
        if($file =~ m/\.tt/mx) {
            push @files, $dir.$file;
        }
        elsif(-d $dir.$file) {
            push @folders, $dir.$file.'/';
        }
    }
    closedir $dh;

    for my $folder (sort @folders) {
        check_templates($folder);
    }
    for my $file (sort @files) {
        check_templates_file($file);
    }
    return;
}

sub check_templates_file {
    my($file) = @_;
    return if($filter && $file !~ m%$filter%mx);
    return if($file =~ m%templates/excel%mx);
    return if($file =~ m%templates/.*csv.*%mx);
    my $content = read_file($file);
    my $failed = 0;
    my $escaped_keys = {};

    # extract all tags
    $content =~ s/\[%\+?\s*(ELSIF|IF|UNLESS|FOREACH)\s*([^;%]*?)\s*;/[% /gmx;
    $content =~ s/\[%\+?\s*(ELSIF|IF|UNLESS|FOREACH)\s*([^;%]*?)\s*\+?%\]//gmx;
    while($content =~ m%(<[^>]+>)%gms) {
        my $tag = substr($content, $-[0], $+[0]-$-[0]);
        my $linenr = 1 + substr($content,0,$-[0]) =~ y/\n//;
        next if substr($tag,0,2) eq '</';
        next if $tag !~ m/\[%/gmx;
        # extract attributes from this tag
        my $str = $tag; # not copying the string seems to miss some matches
        my @attributes = $str =~ m%([\w\-]+)=("[^"]*"|'[^']*')%sgmx;
        while(my ($key,$value) = splice(@attributes,0,2)) {
            next unless $value =~ m/\[%/mx;
            my @tt = $value =~ m/\[%[^%]*%\]/sgmx;
            my $escaped = 0;
            for my $var (@tt) {
                $var =~ s/^\[%\+?\s*(.*?)\s*\+?%\]/$1/gmx;
                next if defined $whitelist_vars->{$var};
                my $found = 0;
                for my $r (@{$whitelist_regex}) {
                    if($var =~ $r) {
                        $found++;
                        last;
                    }
                }
                next if $found;
                next if $var eq '';
                next if $var eq 'END';
                next if $var eq 'ELSE';

                if($key =~ m/^(href|src)$/mx) {
                    if($var =~ m/
                                     \|\s*uri
                                    |\|\s*html
                                    |escape_html\(
                                    |full_uri\(
                                    |short_uri\(
                                    |uri_with\(
                                    /mx) {
                        $escaped = 1;
                        my $escaped_var = $var;
                        $escaped_var =~ s/\s*\|.*$//gmx;
                        $escaped_var =~ s/[\w_]+\(([^\)]+)\)/$1/gmx;
                        $escaped_keys->{$escaped_var} = $linenr;
                        next;
                    }
                    fail(sprintf("%s:%d uses variable '%s' without uri/html filter in: %s=%s", $file, $linenr, $var, $key, $value));
                    $failed++;
                }
                else {
                    if($var =~ m/
                                    \|\s*html
                                    |escape_html\(
                                    |full_uri\(
                                    |short_uri\(
                                    |uri_with\(
                                    |escape_js\(
                                    |name2id\(
                                    |encode_json_obj\(
                                    |json_encode\(
                                    /mx) {
                        $escaped = 1;
                        my $escaped_var = $var;
                        $escaped_var =~ s/\s*\|.*$//gmx;
                        $escaped_var =~ s/[\w_]+\((\s*[^\)]+\s*)\)/$1/gmx;
                        $escaped_keys->{$escaped_var} = $linenr;
                        next;
                    }
                    fail(sprintf("%s:%d uses variable '%s' without html filter in: %s=%s", $file, $linenr, $var, $key, $value));
                    $failed++;
                }
            }
            if($escaped && $value =~ m/^'/mx && $value !~ m/(encode_json_obj|json_encode)\(/mx) {
                fail(sprintf("%s:%d uses single quotes but html/uri filter only escapes double quotes in: %s=%s", $file, $linenr, $key, $value));
                $failed++;
                #diag($tag);
            }
        }
    }
    # check if escaped keys are used elsewhere
    while($content =~ m%(\[\%.*?\%\])%gms) {
        my $tag = substr($content, $-[0], $+[0]-$-[0]);
        my $linenr = 1 + substr($content,0,$-[0]) =~ y/\n//;
        my $var = $tag;
        $var =~ s/^\[%\+?\s*(.*?)\s*\+?%\]$/$1/gmx;
        if(defined $escaped_keys->{$var}) {
            next if $var eq 'cust.1';
            next if $var eq 'referer';
            next if $var =~ m/^PROCESS/mx;
            fail(sprintf("%s:%d uses unescaped variable which is used escaped elsewhere in the same file (line %d) in: %s", $file, $linenr, $escaped_keys->{$var}, $tag));
            $failed++;
        }
    }

    if(!$failed) {
        ok(1, $file." seems to be ok");
    }
}

sub check_libs {
    my($dir) = @_;
    my(@files, @folders);
    opendir(my $dh, $dir) || die $!;
    while(my $file = readdir $dh) {
        next if $file eq '.';
        next if $file eq '..';
        if($file =~ m/\.p(l|m)$/mx) {
            push @files, $dir.$file;
        }
        elsif(-d $dir.$file) {
            push @folders, $dir.$file.'/';
        }
    }
    closedir $dh;

    for my $folder (sort @folders) {
        check_libs($folder);
    }
    for my $file (sort @files) {
        check_libs_file($file);
    }
    return;
}

sub check_libs_file {
    my($file) = @_;
    my $content = read_file($file);
    my $failed = 0;

    # do not put json encoded structures into stash, instead use json_encode() from within the template
    while($content =~ m%(\$c->stash[^\n]*encode[^\n]*)%gms) {
        my $match = substr($content, $-[0], $+[0]-$-[0]);
        my $linenr = 1 + substr($content,0,$-[0]) =~ y/\n//;
        next if $match =~ m/Thruk::Utils::Filter::json_encode/gmx;
        fail(sprintf("%s:%d puts encoded structure into stash, better use encoding function from within the template or Thruk::Utils::Filter::json_encode directly: %s", $file, $linenr, $match));
        $failed++;
    }

    if(!$failed) {
        ok(1, $file." seems to be ok");
    }
}