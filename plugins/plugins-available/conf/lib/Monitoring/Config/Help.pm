package Monitoring::Config::Help;

use strict;
use warnings;

=head1 NAME

Monitoring::Config::Help - Help definitions for various objects

=head1 DESCRIPTION

Help for various configuration settings

=head1 METHODS

=cut

##########################################################

=head2 get_config_help

return help for config directive

=cut
sub get_config_help {
    my ( $type, $key ) = @_;
    our($helpdata);

    if ($type eq 'discoveryrule') {
        # discoveryrule attributes can be prefixed by '+', '-' or '!'
        my $c = substr($key,0,1);
        $key = substr($key, 1) if $c eq '!' or $c eq '+' or $c eq '-';
    }
    if($key eq 'use') {
        return "This directive specifies the name of the template object that you want to inherit properties/variables from. The name you specify for this variable must be defined as another object's template named (using the <i>name</i> variable).";
    }
    if($key eq 'name') {
        return "This attribute is just a 'template' name that can be referenced in other object definitions so they can inherit the objects properties/variables. Template names must be unique amongst objects of the same type, so you can't have two or more host definitions that have 'hosttemplate' as their template name.";
    }
    if($key eq 'register') {
        return "This variable is used to indicate whether or not the object definition should be 'registered' with Nagios. By default, all object definitions are registered. If you are using a partial object definition as a template, you would want to prevent it from being registered. Values are as follows: 0 = do NOT register object definition, 1 = register object definition (this is the default). This variable is NOT inherited; every (partial) object definition used as a template must explicitly set the <i>register</i> directive to be <i>0</i>. This prevents the need to override an inherited <i>register</i> directive with a value of <i>1</i> for every object that should be registered.";
    }
    if($key eq 'customvar') {
        return "Custom variables allow users to define additional properties in their host, service, and contact definitions, and use their values in notifications, event handlers, and host and service checks.<br><ul><li>Custom variable names must begin with an underscore (_) to prevent name collision with standard variables</li><li>Custom variable names are converted to all uppercase before use</li><li>Custom variables are inherited from object templates like normal variables</li><li>Scripts can reference custom variable values with macros and environment variables</li></ul>";
    }

    # read data unless defined already
    if(!defined $helpdata) {
        my $var;
        while (<DATA>) {
            $var .= $_;
        }
        ## no critic
        $helpdata = eval $var;
        ## use critic
    }

    unless(defined $helpdata->{$type}->{$key}) {
        return "topic does not exist!";
    }
    return $helpdata->{$type}->{$key};
}

##########################################################


=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

##########################################################

__DATA__
{
    'command' => {
        'command_line' => '<p>This directive is used to define what is actually executed by Nagios when the command is used for service or host checks, notifications, or event handlers. Before the command line is executed, all valid macros are replaced with their respective values.  See the documentation on macros for determining when you can use different macros.  Note that the command line is <i>not</i> surrounded in quotes.  Also, if you want to pass a dollar sign ($) on the command line, you have to escape it with another dollar sign.</p><p><strong>NOTE</strong>: You may not include a <b>semicolon</b> (;) in the <i>command_line</i> directive, because everything after it will be ignored as a config file comment.  You can work around this limitation by setting one of the <b>$USER$</b> macros in your resource file to a semicolon and then referencing the appropriate $USER$ macro in the <i>command_line</i> directive in place of the semicolon.</p><p>If you want to pass arguments to commands during runtime, you can use <b>$ARGn$</b> macros in the <i>command_line</i> directive of the command definition and then separate individual arguments from the command name (and from each other) using bang (!) characters in the object definition directive (host check command, service event handler command, etc) that references the command.  More information on how arguments in command definitions are processed during runtime can be found in the documentation on macros.</p>',
        'command_name' => 'This directive is the short name used to identify the command.  It is referenced in contact, host, and service definitions (in notification, check, and event handler directives), among other places.',
        'module_type' => 'This optional directive defines the type of the module <i>(Shinken-specific)</i>.',
        'reactionner_tag' => 'This command will run on the reactionner with the specified tag <i>(Shinken-specific)</i>.',
    },
    'contact' => {
        'addressx' => 'Address directives are used to define additional "addresses" for the contact.  These addresses can be anything - cell phone numbers, instant messaging addresses, etc.  Depending on how you configure your notification commands, they can be used to send out an alert to the contact.  Up to six addresses can be defined using these directives (<i>address1</i> through <i>address6</i>). The $CONTACTADDRESS<i>x</i>$ macro will contain this value.',
        'alias' => 'This directive is used to define a longer name or description for the contact.  Under the rights circumstances, the $CONTACTALIAS$ macro will contain this value.  If not specified, the <i>contact_name</i> will be used as the alias.',
        'can_submit_commands' => 'This directive is used to determine whether or not the contact can submit external commands to Nagios from the CGIs.  Values: 0 = don\'t allow contact to submit commands, 1 = allow contact to submit commands.',
        'contact_name' => 'This directive is used to define a short name used to identify the contact.  It is referenced in contact group definitions.  Under the right circumstances, the $CONTACTNAME$ macro will contain thisvalue.',
        'contactgroups' => 'This directive is used to identify the <i>short name(s)</i> of the contactgroup(s) that the contact belongs to.  Multiple contactgroups should be separated by commas.  This directive may be used as an alternative to (or in addition to) using the <i>members</i> directive in contactgroup definitions.',
        'email' => 'This directive is used to define an email address for the contact.  Depending on how you configure your notification commands, it can be used to send out an alert email to the contact.  Under the right circumstances, the $CONTACTEMAIL$macro will contain this value.',
        'host_notification_commands' => 'This directive is used to define a list of the <i>short names</i> of the commands used to notify the contact of a <i>host</i> problem or recovery.  Multiple notification commands should be separated by commas.  Allnotification commands are executed when the contact needs to be notified.  The maximum amount of time that a notification command can run is controlled by the notification_timeout option.',
        'host_notification_options' => 'This directive is used to define the host states for which notifications can be sent out to this contact.  Valid options are a combination of one or more of the following: <b>d</b> = notify on DOWN host states, <b>u</b> = notify on UNREACHABLE host states, <b>r</b> = notify on host recoveries (UP states), <b>f</b> = notify when the host starts and stops flapping, and <b>s</b> = send notifications when host or service scheduled downtime starts and ends.  If you specify <b>n</b> (none) as an option, the contact will not receive any type of host notifications.',
        'host_notification_period' => 'This directive is used to specify the short name of the time period during which the contact can be notified about host problems or recoveries.  You can think of this as an "on call" time for host notifications for the contact.  Read the documentation on time periods for more information on how this works and potential problems that may result from improper use.',
        'host_notifications_enabled' => 'This directive is used to determine whether or not the contact will receive notifications about host problems and recoveries.  Values: 0 = don\'t send notifications, 1 = send notifications.',
        'pager' => 'This directive is used to define a pager number for the contact.  It can also be an email address to a pager gateway (i.e. pagejoe@pagenet.com).  Depending on how you configure your notification commands, it can be used to send out an alert page to the contact.  Under the right circumstances, the $CONTACTPAGER$ macro will contain this value.',
        'retain_nonstatus_information' => 'This directive is used to determine whether or not non-status information about the contact is retained across program restarts.  This is only useful if you have enabled state retention using the retain_state_information directive.  Value: 0 = disable non-status information retention, 1 = enable non-status information retention.',
        'retain_status_information' => 'This directive is used to determine whether or not status-related information about the contact is retained across program restarts.  This is only useful if you have enabled state retention using the retain_state_information directive.  Value: 0 = disable status information retention, 1 = enable status information retention.',
        'service_notification_commands' => 'This directive is used to define a list of the <i>short names</i> of the commands used to notify the contact of a <i>service</i> problem or recovery.  Multiple notification commands should be separated by commas.  Allnotification commands are executed when the contact needs to be notified.  The maximum amount of time that a notification command can run is controlled by the notification_timeout option.',
        'service_notification_options' => 'This directive is used to define the service states for which notifications can be sent out to this contact.  Valid options are a combination of one or more of the following: <b>w</b> = notify on WARNING service states, <b>u</b> = notify on UNKNOWN service states, <b>c</b> = notify on CRITICAL service states, <b>r</b> = notify on service recoveries (OK states), and <b>f</b> = notify when the service starts and stops flapping.  If you specify <b>n</b> (none) as an option, the contact will not receive any type of service notifications.',
        'service_notification_period' => 'This directive is used to specify the short name of the time period during which the contact can be notified about service problems or recoveries.  You can think of this as an "on call" time for service notifications for the contact.  Read the documentation on time periods for more information on how this works and potential problems that may result from improper use.',
        'service_notifications_enabled' => 'This directive is used to determine whether or not the contact will receive notifications about service problems and recoveries.  Values: 0 = don\'t send notifications, 1 = send notifications.',
        'is_admin' => ' This directive is used to determine whether or not the contact can see all object in Shinken WebUI. Values: 0 = normal user, can see all objects he is in contact, 1 = allow contact to see all objects',
        'min_business_impact' => 'This directive is use to define the minimum business criticity level of a service/host the contact will be notified',
        'password' => 'Contact password (used by SHinken UI).',
    },
    'contactgroup' => {
        'alias' => 'This directive is used to define a longer name or description used to identify the contact group.',
        'contactgroup_members' => 'This optional directive can be used to include contacts from other "sub" contact groups in this contact group.  Specify a comma-delimited list of short names of other contact groups whose members should be included in this group.',
        'contactgroup_name' => 'This directive is a short name used to identify the contact group.',
        'members' => 'This optional directive is used to define a list of the <i>short names</i> of contacts  that should be included in this group.   Multiple contact names should be separated by commas.  This directive may be used as an alternative to (or in addition to) using the <i>contactgroups</i> directive in contact definitions.'
    },
    'host' => {
        '2d_coords' => 'This variable is used to define coordinates to use when drawing the host in the statusmap CGI.  Coordinates should be given in positive integers, as they correspond to physical pixels in the generated image.  The origin for drawing (0,0) is in the upper left hand corner of the image and extends in the positive x direction (to the right) along the top of the image and in the positive y direction (down) along the left hand side of the image.  For reference, the size of the icons drawn is usually about 40x40 pixels (text takes a little extra space).  The coordinates you specify here are for the upper left hand corner of the host icon that is drawn.  Note:  Don\'t worry about what the maximum x and y coordinates that you can use are.  The CGI will automatically calculate the maximum dimensions of the image it creates based on the largest x and y coordinates you specify.',
        '3d_coords' => 'This variable is used to define coordinates to use when drawing the host in the statuswrl CGI.  Coordinates can be positive or negative real numbers.  The origin for drawing is (0.0,0.0,0.0).  For reference, the size of the host cubes drawn is 0.5 units on each side (text takes a little more space).  The coordinates you specify here are used as the center of the host cube.',
        'action_url' => 'This directive is used to define an optional URL that can be used to provide more actions to be performed on the host.  If you specify an URL, you will see a red "splat" icon in the CGIs (when you are viewing host information) that links to the URL you specify here.  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).',
        'active_checks_enabled' => 'This directive is used to determine whether or not active checks (either regularly scheduled or on-demand) of this host are enabled. Values: 0 = disable active host checks, 1 = enable active host checks (default). ',
        'address' => 'This directive is used to define the address of the host.  Normally, this is an IP address, although it could really be anything you want (so long as it can be used to check the status of the host).  You can use a FQDN to identify the host instead of an IP address, but if DNS services are not available this could cause problems. When used properly, the $HOSTADDRESS$ macro will contain this address.  <b>Note:</b> If you do not specify an address directive in a host definition, the name of the host will be used as its address.  A word of caution about doing this, however - if DNS fails, most of your service checks will fail because the plugins will be unable to resolve the host name.',
        'address6' => 'This directive is used to define a second address for the host. Normally, this is an IPv6 address, although it could really be anything you want (so long as it can be used to check the status of the host). You can use a FQDN to identify the host instead of an IP address, but if DNS services are not availble this could cause problems. When used properly, the $HOSTADDRESS6$ macro will contain this address.',
        'alias' => 'This directive is used to define a longer name or description used to identify the host.  It is provided in order to allow you to more easily identify a particular host.  When used properly, the $HOSTALIAS$ macro will contain this alias/description.',
        'check_command' => 'This directive is used to specify the <i>short name</i> of the command that should be used to check if the host is up or down.  Typically, this command would try and ping the host to see if it is "alive".  The command must return a status of OK (0) or Nagios will assume the host is down.  If you leave this argument blank, the host will <i>not</i> be actively checked.  Thus, Nagios will likely always assume the host is up (it may show up as being in a "PENDING" state in the web interface).  This is useful if you are monitoring printers or other devices that are frequently turned off.  The maximum amount of time that the notification command can run is controlled by the host_check_timeout option.',
        'check_freshness' => 'This directive is used to determine whether or not freshness checks are enabled for this host. Values: 0 = disable freshness checks, 1 = enable freshness checks (default).',
        'check_interval' => 'This directive is used to define the number of "time units" between regularly scheduled checks of the host.  Unless you\'ve changed the interval_length directive from the default value of 60, this number will mean minutes.  More information on this value can be found in the check scheduling documentation.',
        'check_period' => 'This directive is used to specify the short name of the time period during which active checks of this host can be made.',
        'contact_groups' => 'This is a list of the <i>short names</i> of the contact groups that should be notified whenever there are problems (or recoveries) with this host.  Multiple contact groups should be separated by commas.  You must specify at least one contact or contact group in each host definition.',
        'contacts' => 'This is a list of the <i>short names</i> of the contacts that should be notified whenever there are problems (or recoveries) with this host.  Multiple contacts should be separated by commas.  Useful if you want notifications to go to just a few people and don\'t want to configure contact groups.  You must specify at least one contact or contact group in each host definition.',
        'display_name' => 'This directive is used to define an alternate name that should be displayed in the web interface for this host.  If not specified, this defaults to the value you specify for the <i>host_name</i> directive.  Note:  The current CGIs do not use this option, although future versions of the web interface will.',
        'event_handler' => 'This directive is used to specify the <i>short name</i> of the command that should be run whenever a change in the state of the host is detected (i.e. whenever it goes down or recovers).  Read the documentation onevent handlers for a more detailed explanation of how to write scripts for handling events.  The maximum amount of time that the event handler command can run is controlled by the event_handler_timeout option.',
        'event_handler_enabled' => 'This directive is used to determine whether or not the event handler for this host is enabled. Values: 0 = disable host event handler, 1 = enable host event handler.',
        'failure_prediction_enabled' => 'This directive is used to determine whether or not failure prediction is enabled for this host.  Values: 0 = disable host failure prediction, 1 = enable host failure prediction.',
        'first_notification_delay' => 'This directive is used to define the number of "time units" to wait before sending out the first problem notification when this host enters a non-UP state.  Unless you\'ve changed the interval_length directive from the default value of 60, this number will mean minutes.  If you set this value to 0, Nagios will start sending out notifications immediately.',
        'flap_detection_enabled' => 'This directive is used to determine whether or not flap detection is enabled for this host.  More information on flap detection can be found here. Values: 0 = disable host flap detection, 1 = enable host flap detection.',
        'flap_detection_options' => 'This directive is used to determine what host states the flap detection logic will use for this host.  Valid options are a combination of one or more of the following: <b>o</b> = UP states, <b>d</b> = DOWN states, <b>u</b> =  UNREACHABLE states.',
        'freshness_threshold' => 'This directive is used to specify the freshness threshold (in seconds) for this host.  If you set this directive to a value of 0, Nagios will determine a freshness threshold to use automatically.',
        'high_flap_threshold' => 'This directive is used to specify the high state change threshold used in flap detection for this host.  More information on flap detection can be found here.  If you set this directive to a value of 0, the program-wide value specified by the high_host_flap_threshold directive will be used.',
        'host_name' => 'This directive is used to define a short name used to identify the host.  It is used in host group and service definitions to reference this particular host.  Hosts can have multiple services (which are monitored) associated with them.  When used properly, the $HOSTNAME$ macro will contain this short name.',
        'hostgroups' => 'This directive is used to identify the <i>short name(s)</i> of the hostgroup(s) that the host belongs to.  Multiple hostgroups should be separated by commas.  This directive may be used as an alternative to (or in addition to) using the <i>members</i> directive in hostgroup definitions.',
        'icon_image' => 'This variable is used to define the name of a GIF, PNG, or JPG image that should be associated with this host.  This image will be displayed in the various places in the CGIs.  The image will look best if it is 40x40 pixels in size.  Images for hosts are assumed to be in the <b>logos/</b> subdirectory in your HTML images directory (i.e. <i>/usr/local/nagios/share/images/logos</i>).',
        'icon_image_alt' => 'This variable is used to define an optional string that is used in the ALT tag of the image specified by the <i>&lt;icon_image&gt;</i> argument.',
        'initial_state' => 'By default Nagios will assume that all hosts are in UP states when it starts.  You can override the initial state for a host by using this directive.  Valid options are: <b>o</b> = UP, <b>d</b> = DOWN, and <b>u</b> = UNREACHABLE.',
        'low_flap_threshold' => 'This directive is used to specify the low state change threshold used in flap detection for this host.  More information on flap detection can be found here.  If you set this directive to a value of 0, the program-wide value specified by the low_host_flap_threshold directive will be used.',
        'max_check_attempts' => 'This directive is used to define the number of times that Nagios will retry the host check command if it returns any state other than an OK state.  Setting this value to 1 will cause Nagios to generate an alert without retrying the host check.  Note: If you do not want to check the status of the host, you must still set this to a minimum value of 1.  To bypass the host check, just leave the <i>check_command</i> option blank.',
        'notes' => 'This directive is used to define an optional string of notes pertaining to the host.  If you specify a note here, you will see the it in the extended information CGI (when you are viewing information about the specified host).',
        'notes_url' => 'This variable is used to define an optional URL that can be used to provide more information about the host.  If you specify an URL, you will see a red folder icon in the CGIs (when you are viewing host information) that links to the URL you specify here.  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).  This can be very useful if you want to make detailed information on the host, emergency contact methods, etc. available to other support staff.',
        'notification_interval' => 'This directive is used to define the number of "time units" to wait before re-notifying a contact that this service is <i>still</i> down or unreachable.  Unless you\'ve changed the interval_length directive from the default value of 60, this number will mean minutes.  If you set this value to 0, Nagios will <i>not</i> re-notify contacts about problems for this host - only one problem notification will be sent out.',
        'notification_options' => 'This directive is used to determine when notifications for the host should be sent out.  Valid options are a combination of one or more of the following: <b>d</b> = send notifications on a DOWN state, <b>u</b> = send notifications on an UNREACHABLE state, <b>r</b> = send notifications on recoveries (OK state), <b>f</b> = send notifications when the host starts and stops flapping, and <b>s</b> = send notifications when scheduled downtime starts and ends.  If you specify <b>n</b> (none) as an option, no host notifications will be sent out.  If you do not specify any notification options, Nagios will assume that you want notifications to be sent out for all possible states.  Example: If you specify <b>d,r</b> in this field, notifications will only be sent out when the host goes DOWN and when it recovers from a DOWN state.',
        'notification_period' => 'This directive is used to specify the short name of the time period during which notifications of events for this host can be sent out to contacts.  If a host goes down, becomes unreachable, or recoveries during a time which is not covered by the time period, no notifications will be sent out.',
        'notifications_enabled' => 'This directive is used to determine whether or not notifications for this host are enabled. Values: 0 = disable host notifications, 1 = enable host notifications.',
        'obsess_over_host' => 'This directive determines whether or not checks for the host will be "obsessed" over using the ochp_command.',
        'parents' => 'This directive is used to define a comma-delimited list of short names of the "parent" hosts for this particular host.  Parent hosts are typically routers, switches, firewalls, etc. that lie between the monitoring host and a remote hosts.  A router, switch, etc. which is closest to the remote host is considered to be that host\'s "parent".  Read the "Determining Status and Reachability of Network Hosts" document located here for more information. If this host is on the same network segment as the host doing the monitoring (without any intermediate routers, etc.) the host is considered to be on the local network and will not have a parent host.  Leave this value blank if the host does not have a parent host (i.e. it is on the same segment as the Nagios host).   The order in which you specify parent hosts has no effect on how things are monitored.',
        'passive_checks_enabled' => 'This directive is used to determine whether or not passive checks are enabled for this host. Values: 0 = disable passive host checks, 1 = enable passive host checks (default).',
        'process_perf_data' => 'This directive is used to determine whether or not the processing of performance data is enabled for this host.  Values: 0 = disable performance data processing, 1 = enable performance data processing.',
        'retain_nonstatus_information' => 'This directive is used to determine whether or not non-status information about the host is retained across program restarts.  This is only useful if you have enabled state retention using the retain_state_information directive.  Value: 0 = disable non-status information retention, 1 = enable non-status information retention.',
        'retain_status_information' => 'This directive is used to determine whether or not status-related information about the host is retained across program restarts.  This is only useful if you have enabled state retention using the retain_state_information directive.  Value: 0 = disable status information retention, 1 = enable status information retention.',
        'retry_interval' => 'This directive is used to define the number of "time units" to wait before scheduling a re-check of the hosts.  Hosts are rescheduled at the retry interval when they have changed to a non-UP state.  Once the host has been retried <b>max_check_attempts</b> times without a change in its status, it will revert to being scheduled at its "normal" rate as defined by the <b>check_interval</b> value. Unless you\'ve changed the interval_length directive from the default value of 60, this number will mean minutes.  More information on this value can be found in the check scheduling documentation.',
        'stalking_options' => 'This directive determines which host states "stalking" is enabled for.  Valid options are a combination of one or more of the following: <b>o</b> = stalk on UP states, <b>d</b> = stalk on DOWN states, and <b>u</b> = stalk on UNREACHABLE states.  More information on state stalking can be found here.',
        'statusmap_image' => 'This variable is used to define the name of an image that should be associated with this host in the statusmap CGI.  You can specify a JPEG, PNG, and GIF image if you want, although I would strongly suggest using a GD2 format image, as other image formats will result in a lot of wasted CPU time when the statusmap image is generated.  GD2 images can be created from PNG images by using the <b>pngtogd2</b> utility supplied with Thomas Boutell\'s gd library.  The GD2 images should be created in <i>uncompressed</i> format in order to minimize CPU load when the statusmap CGI is generating the network map image.  The image will look best if it is 40x40 pixels in size.  You can leave these option blank if you are not using the statusmap CGI.  Images for hosts are assumed to be in the <b>logos/</b> subdirectory in your HTML images directory (i.e. <i>/usr/local/nagios/share/images/logos</i>).',
        'vrml_image' => 'This variable is used to define the name of a GIF, PNG, or JPG image that should be associated with this host.  This image will be used as the texture map for the specified host in the statuswrl CGI.  Unlike the image you use for the <i>&lt;icon_image&gt;</i> variable, this one should probably <i>not</i> have any transparency.  If it does, the host object will look a bit wierd.  Images for hosts are assumed to be in the <b>logos/</b> subdirectory in your HTML images directory (i.e. <i>/usr/local/nagios/share/images/logos</i>).',
        'realm' => 'This variable is used to define the realm where the host will be put. By putting the host in a realm, it will be manage by one of the scheduler of this realm.',
        'poller_tag' => 'This variable is used to define the poller_tag of the host. All checks of this hosts will only take by pollers that have this value in their poller_tags parameter. By default there is no poller_tag, so all untagged pollers can take it.',
        'business_impact' => 'This variable is used to set the importance we gave to this host for the business from the less important (0 = nearly nobody will see if it\'s in error) to the maximum (5 = you lost your job if it fail). The default value is 2.',
        'resultmodulations' => 'This variable is used to link with resultmodulations objects. It will allow such modulation to apply, like change a warning in critical for this host.',
        'escalations' => 'This variable is used to link with escalations objects. It will allow such escalations rules to appy. Look at escalations objects for more details.',
        'business_impact_modulations' => 'This variable is used to link with business_impact_modulations objects. It will allow such modulation to apply (for example if the host is a payd server, it will be important only in a specific timeperiod: near the payd day). Look at business_impact_modulations objects for more details.',
        'icon_set' => 'This variable is used to set the icon in the Shinken Webui. For now, values are only : database, disk, network_service, server',
        'maintenance_period' => 'no help yet',
        'reactionner_tag' => 'no help yet',
    },
    'hostdependency' => {
        'dependency_period' => 'This directive is used to specify the short name of the time period during which this dependency is valid.  If this directive is not specified, the dependency is considered to be valid during all times.',
        'dependent_host_name' => 'This directive is used to identify the <i>short name(s)</i> of the <i>dependent</i> host(s).  Multiple hosts should be separated by commas.',
        'dependent_hostgroup_name' => 'This directive is used to identify the <i>short name(s)</i> of the <i>dependent</i> hostgroup(s).  Multiple hostgroups should be separated by commas.  The dependent_hostgroup_name may be used instead of, or in addition to, the dependent_host_name directive.',
        'execution_failure_criteria' => 'This directive is used to specify the criteria that determine when the dependent host should <i>not</i> be actively checked.  If the <i>master</i> host is in one of the failure states we specify, the <i>dependent</i> host will not be actively checked.  Valid options are a combination of one or more of the following (multiple options are separated with commas): <b>o</b> = fail on an UP state, <b>d</b> = fail on a DOWN state, <b>u</b> = fail on an UNREACHABLE state, and <b>p</b> = fail on a pending state (e.g. the host has not yet been checked).  If you specify <b>n</b> (none) as an option, the execution dependency will never fail and the dependent host will always be actively checked (if other conditions allow for it to be).  Example: If you specify <b>u,d</b> in this field, the <i>dependent</i> host will not be actively checked if the <i>master</i> host is in either an UNREACHABLE or DOWN state.',
        'host_name' => 'This directive is used to identify the <i>short name(s)</i> of the host(s) <i>that is being depended upon</i> (also referred to as the master host).  Multiple hosts should be separated by commas.',
        'hostgroup_name' => 'This directive is used to identify the <i>short name(s)</i> of the hostgroup(s) <i>that is being depended upon</i> (also referred to as the master host).  Multiple hostgroups should be separated by commas.  The hostgroup_name may be used instead of, or in addition to, the host_name directive.',
        'inherits_parent' => 'This directive indicates whether or not the dependency inherits dependencies of the host <i>that is being depended upon</i> (also referred to as the master host).  In other words, if the master host is dependent upon other hosts and any one of those dependencies fail, this dependency will also fail.',
        'notification_failure_criteria' => 'This directive is used to define the criteria that determine when notifications for the dependent host should <i>not</i> be sent out.  If the <i>master</i> host is in one of the failure states we specify, notifications for the <i>dependent</i> host will not be sent to contacts.  Valid options are a combination of one or more of the following: <b>o</b> = fail on an UP state, <b>d</b> = fail on a DOWN state, <b>u</b> = fail on an UNREACHABLE state, and <b>p</b> = fail on a pending state (e.g. the host has not yet been checked).  If you specify <b>n</b> (none) as an option, the notification dependency will never fail and notifications for the dependent host will always be sent out.  Example: If you specify <b>d</b> in this field, the notifications for the <i>dependent</i> host will not be sent out if the <i>master</i> host is in a DOWN state.'
    },
    'hostescalation' => {
        'contact_groups' => 'This directive is used to identify the <i>short name</i> of the contact group that should be notified when the host notification is escalated.  Multiple contact groups should be separated by commas.  You must specify at least one contact or contact group in each host escalation definition.',
        'contacts' => 'This is a list of the <i>short names</i> of the contacts that should be notified whenever there are problems (or recoveries) with this host.  Multiple contacts should be separated by commas.  Useful if you want notifications to go to just a few people and don\'t want to configure contact groups.  You must specify at least one contact or contact group in each host escalation definition.',
        'escalation_options' => 'This directive is used to define the criteria that determine when this host escalation is used.  The escalation is used only if the host is in one of the states specified in this directive.  If this directive is not specified in a host escalation, the escalation is considered to be valid during all host states.  Valid options are a combination of one or more of the following: <b>r</b> = escalate on an UP (recovery) state, <b>d</b> = escalate on a DOWN state, and <b>u</b> = escalate on an UNREACHABLE state.   Example: If you specify <b>d</b> in this field, the escalation will only be used if the host is in a DOWN state.',
        'escalation_period' => 'This directive is used to specify the short name of the time period during which this escalation is valid.  If this directive is not specified, the escalation is considered to be valid during all times.',
        'first_notification' => 'This directive is a number that identifies the <i>first</i> notification for which this escalation is effective.  For instance, if you set this value to 3, this escalation will only be used if the host is down or unreachable long enough for a third notification to go out.',
        'host_name' => 'This directive is used to identify the <i>short name</i> of the host that the escalation should apply to.',
        'hostgroup_name' => 'This directive is used to identify the <i>short name(s)</i> of the hostgroup(s) that the escalation should apply to.  Multiple hostgroups should be separated by commas.  If this is used, the escalation will apply to all hosts that are members of the specified hostgroup(s).',
        'last_notification' => 'This directive is a number that identifies the <i>last</i> notification for which this escalation is effective.  For instance, if you set this value to 5, this escalation will not be used if more than five notifications are sent out for the host.  Setting this value to 0 means to keep using this escalation entry forever (no matter how many notifications go out).',
        'notification_interval' => 'This directive is used to determine the interval at which notifications should be made while this escalation is valid.  If you specify a value of 0 for the interval, Nagios will send the first notification when this escalation definition is valid, but will then prevent any more problem notifications from being sent out for the host.  Notifications are sent out again until the host recovers.  This is useful if you want to stop having notifications sent out after a certain amount of time.  Note:  If multiple escalation entries for a host overlap for one or more notification ranges, the smallest notification interval from all escalation entries is used.'
    },
    'hostextinfo' => {
        '2d_coords' => 'This variable is used to define coordinates to use when drawing the host in the statusmap CGI.  Coordinates should be given in positive integers, as they correspond to physical pixels in the generated image.  The origin for drawing (0,0) is in the upper left hand corner of the image and extends in the positive x direction (to the right) along the top of the image and in the positive y direction (down) along the left hand side of the image.  For reference, the size of the icons drawn is usually about 40x40 pixels (text takes a little extra space).  The coordinates you specify here are for the upper left hand corner of the host icon that is drawn.  Note:  Don\'t worry about what the maximum x and y coordinates that you can use are.  The CGI will automatically calculate the maximum dimensions of the image it creates based on the largest x and y coordinates you specify.',
        '3d_coords' => 'This variable is used to define coordinates to use when drawing the host in the statuswrl CGI.  Coordinates can be positive or negative real numbers.  The origin for drawing is (0.0,0.0,0.0).  For reference, the size of the host cubes drawn is 0.5 units on each side (text takes a little more space).  The coordinates you specify here are used as the center of the host cube.',
        'action_url' => 'This directive is used to define an optional URL that can be used to provide more actions to be performed on the host.  If you specify an URL, you will see a link that says "Extra Host Actions" in the extended information CGI (when you are viewing information about the specified host).  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).',
        'host_name' => 'This variable is used to identify the <i>short name</i> of the host which the data is associated with.',
        'icon_image' => 'This variable is used to define the name of a GIF, PNG, or JPG image that should be associated with this host.  This image will be displayed in the status and extended information CGIs.  The image will look best if it is 40x40 pixels in size.  Images for hosts are assumed to be in the <b>logos/</b> subdirectory in your HTML images directory (i.e. <i>/usr/local/nagios/share/images/logos</i>).',
        'icon_image_alt' => 'This variable is used to define an optional string that is used in the ALT tag of the image specified by the <i>&lt;icon_image&gt;</i> argument.  The ALT tag is used in the status, extended information and statusmap CGIs.',
        'notes' => 'This directive is used to define an optional string of notes pertaining to the host.  If you specify a note here, you will see the it in the extended information CGI (when you are viewing information about the specified host).',
        'notes_url' => 'This variable is used to define an optional URL that can be used to provide more information about the host.  If you specify an URL, you will see a link that says "Extra Host Notes" in the extended information CGI (when you are viewing information about the specified host).  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).  This can be very useful if you want to make detailed information on the host, emergency contact methods, etc. available to other support staff.',
        'statusmap_image' => 'This variable is used to define the name of an image that should be associated with this host in the statusmap CGI.  You can specify a JPEG, PNG, and GIF image if you want, although I would strongly suggest using a GD2 format image, as other image formats will result in a lot of wasted CPU time when the statusmap image is generated.  GD2 images can be created from PNG images by using the <b>pngtogd2</b> utility supplied with Thomas Boutell\'s gd library.  The GD2 images should be created in <i>uncompressed</i> format in order to minimize CPU load when the statusmap CGI is generating the network map image.  The image will look best if it is 40x40 pixels in size.  You can leave these option blank if you are not using the statusmap CGI.  Images for hosts are assumed to be in the <b>logos/</b> subdirectory in your HTML images directory (i.e. <i>/usr/local/nagios/share/images/logos</i>).',
        'vrml_image' => 'This variable is used to define the name of a GIF, PNG, or JPG image that should be associated with this host.  This image will be used as the texture map for the specified host in the statuswrl CGI.  Unlike the image you use for the <i>&lt;icon_image&gt;</i> variable, this one should probably <i>not</i> have any transparency.  If it does, the host object will look a bit wierd.  Images for hosts are assumed to be in the <b>logos/</b> subdirectory in your HTML images directory (i.e. <i>/usr/local/nagios/share/images/logos</i>).',
    },
    'hostgroup' => {
        'action_url' => 'This directive is used to define an optional URL that can be used to provide more actions to be performed on the host group.  If you specify an URL, you will see a red "splat" icon in the CGIs (when you are viewing hostgroup information) that links to the URL you specify here.  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).',
        'alias' => 'This directive is used to define is a longer name or description used to identify the host group.  It is provided in order to allow you to more easily identify a particular host group.',
        'hostgroup_members' => 'This optional directive can be used to include hosts from other "sub" host groups in this host group.  Specify a comma-delimited list of short names of other host groups whose members should be included in this group.',
        'hostgroup_name' => 'This directive is used to define a short name used to identify the host group.',
        'members' => 'This is a list of the <i>short names</i> of hosts that should be included in this group.   Multiple host names should be separated by commas.  This directive may be used as an alternative to (or in addition to) the <i>hostgroups</i> directive in host definitions.',
        'notes' => 'This directive is used to define an optional string of notes pertaining to the host.  If you specify a note here, you will see the it in the extended information CGI (when you are viewing information about the specified host).',
        'notes_url' => 'This variable is used to define an optional URL that can be used to provide more information about the host group.  If you specify an URL, you will see a red folder icon in the CGIs (when you are viewing hostgroup information) that links to the URL you specify here.  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).  This can be very useful if you want to make detailed information on the host group, emergency contact methods, etc. available to other support staff.'
    },
    'service' => {
        'action_url' => 'This directive is used to define an optional URL that can be used to provide more actions to be performed on the service.  If you specify an URL, you will see a red "splat" icon in the CGIs (when you are viewing service information) that links to the URL you specify here.  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).',
        'active_checks_enabled' => 'This directive is used to determine whether or not active checks of this service are enabled. Values: 0 = disable active service checks, 1 = enable active service checks (default).',
        'check_command' => '<p>This directive is used to specify the <i>short name</i> of the command that Nagios will run in order to check the status of the service.  The maximum amount of time that the service check command can run is controlled by the service_check_timeout option.</p>',
        'check_freshness' => 'This directive is used to determine whether or not freshness checks are enabled for this service. Values: 0 = disable freshness checks, 1 = enable freshness checks (default).',
        'check_interval' => 'This directive is used to define the number of "time units" to wait before scheduling the next "regular" check of the service.  "Regular" checks are those that occur when the service is in an OK state or when the service is in a non-OK state, but has already been rechecked <b>max_check_attempts</b> number of times.  Unless you\'ve changed the interval_length directive from the default value of 60, this number will mean minutes.  More information on this value can be found in the check scheduling documentation.',
        'check_period' => 'This directive is used to specify the short name of the time period during which active checks of this service can be made.',
        'contact_groups' => 'This is a list of the <i>short names</i> of the contact groups that should be notified whenever there are problems (or recoveries) with this service.  Multiple contact groups should be separated by commas.  You must specify at least one contact or contact group in each service definition.',
        'contacts' => 'This is a list of the <i>short names</i> of the contacts that should be notified whenever there are problems (or recoveries) with this service.  Multiple contacts should be separated by commas.  Useful if you want notifications to go to just a few people and don\'t want to configure contact groups.  You must specify at least one contact or contact group in each service definition.',
        'display_name' => 'This directive is used to define an alternate name that should be displayed in the web interface for this service.  If not specified, this defaults to the value you specify for the <i>service_description</i> directive.  Note:  The current CGIs do not use this option, although future versions of the web interface will.',
        'event_handler' => 'This directive is used to specify the <i>short name</i> of the command that should be run whenever a change in the state of the service is detected (i.e. whenever it goes down or recovers).  Read the documentation onevent handlers for a more detailed explanation of how to write scripts for handling events.  The maximum amount of time that the event handler command can run is controlled by the event_handler_timeout option.',
        'event_handler_enabled' => 'This directive is used to determine whether or not the event handler for this service is enabled. Values: 0 = disable service event handler, 1 = enable service event handler.',
        'failure_prediction_enabled' => 'This directive is used to determine whether or not failure prediction is enabled for this service.  Values: 0 = disable service failure prediction, 1 = enable service failure prediction.',
        'first_notification_delay' => 'This directive is used to define the number of "time units" to wait before sending out the first problem notification when this service enters a non-OK state.  Unless you\'ve changed the interval_length directive from the default value of 60, this number will mean minutes.  If you set this value to 0, Nagios will start sending out notifications immediately.',
        'flap_detection_enabled' => 'This directive is used to determine whether or not flap detection is enabled for this service.  More information on flap detection can be found here. Values: 0 = disable service flap detection, 1 = enable service flap detection.',
        'flap_detection_options' => 'This directive is used to determine what service states the flap detection logic will use for this service.  Valid options are a combination of one or more of the following: <b>o</b> = OK states, <b>w</b> = WARNING states, <b>c</b> = CRITICAL states, <b>u</b> = UNKNOWN states.',
        'freshness_threshold' => 'This directive is used to specify the freshness threshold (in seconds) for this service.  If you set this directive to a value of 0, Nagios will determine a freshness threshold to use automatically.',
        'high_flap_threshold' => 'This directive is used to specify the high state change threshold used in flap detection for this service.  More information on flap detection can be found here.  If you set this directive to a value of 0, the program-wide value specified by the high_service_flap_threshold directive will be used.',
        'host_name' => 'This directive is used to specify the <i>short name(s)</i> of the host(s) that the service "runs" on or is associated with.  Multiple hosts should be separated by commas.',
        'hostgroup_name' => 'This directive is used to specify the <i>short name(s)</i> of the hostgroup(s) that the service "runs" on or is associated with.  Multiple hostgroups should be separated by commas.  The hostgroup_name may be used instead of, or in addition to, the host_name directive.',
        'icon_image' => 'This variable is used to define the name of a GIF, PNG, or JPG image that should be associated with this service.  This image will be displayed in the status and extended information CGIs.  The image will look best if it is 40x40 pixels in size.  Images for services are assumed to be in the <b>logos/</b> subdirectory in your HTML images directory (i.e. <i>/usr/local/nagios/share/images/logos</i>).',
        'icon_image_alt' => 'This variable is used to define an optional string that is used in the ALT tag of the image specified by the <i>&lt;icon_image&gt;</i> argument.  The ALT tag is used in the status, extended information and statusmap CGIs.',
        'initial_state' => 'By default Nagios will assume that all services are in OK states when it starts.  You can override the initial state for a service by using this directive.  Valid options are: <b>o</b> = OK, <b>w</b> = WARNING, <b>u</b> = UNKNOWN, and <b>c</b> = CRITICAL.',
        'is_volatile' => 'This directive is used to denote whether the service is "volatile".  Services are normally <i>not</i> volatile.  More information on volatile service and how they differ from normal services can be found here.  Value: 0 = service is not volatile, 1 = service is volatile.',
        'low_flap_threshold' => 'This directive is used to specify the low state change threshold used in flap detection for this service.  More information on flap detection can be found here.  If you set this directive to a value of 0, the program-wide value specified by the low_service_flap_threshold directive will be used.',
        'max_check_attempts' => 'This directive is used to define the number of times that Nagios will retry the service check command if it returns any state other than an OK state.  Setting this value to 1 will cause Nagios to generate an alert without retrying the service check again.',
        'notes' => 'This directive is used to define an optional string of notes pertaining to the service.  If you specify a note here, you will see the it in the extended information CGI (when you are viewing information about the specified service).',
        'notes_url' => 'This directive is used to define an optional URL that can be used to provide more information about the service.  If you specify an URL, you will see a red folder icon in the CGIs (when you are viewing service information) that links to the URL you specify here.  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).  This can be very useful if you want to make detailed information on the service, emergency contact methods, etc. available to other support staff.',
        'notification_interval' => 'This directive is used to define the number of "time units" to wait before re-notifying a contact that this service is <i>still</i> in a non-OK state.  Unless you\'ve changed the interval_length directive from the default value of 60, this number will mean minutes.  If you set this value to 0, Nagios will <i>not</i> re-notify contacts about problems for this service - only one problem notification will be sent out.',
        'notification_options' => 'This directive is used to determine when notifications for the service should be sent out.  Valid options are a combination of one or more of the following: <b>w</b> = send notifications on a WARNING state, <b>u</b> = send notifications on an UNKNOWN state, <b>c</b> = send notifications on a CRITICAL state, <b>r</b> = send notifications on recoveries (OK state), <b>f</b> = send notifications when the service starts and stops flapping, and <b>s</b> = send notifications when scheduled downtime starts and ends.  If you specify <b>n</b> (none) as an option, no service notifications will be sent out.  If you do not specify any notification options, Nagios will assume that you want notifications to be sent out for all possible states.  Example: If you specify <b>w,r</b> in this field, notifications will only be sent out when the service goes into a WARNING state and when it recovers from a WARNING state.',
        'notification_period' => 'This directive is used to specify the short name of the time period during which notifications of events for this service can be sent out to contacts.  No service notifications will be sent out during times which is not covered by the time period.',
        'notifications_enabled' => 'This directive is used to determine whether or not notifications for this service are enabled. Values: 0 = disable service notifications, 1 = enable service notifications.',
        'obsess_over_service' => 'This directive determines whether or not checks for the service will be "obsessed" over using the ocsp_command.',
        'passive_checks_enabled' => 'This directive is used to determine whether or not passive checks of this service are enabled. Values: 0 = disable passive service checks, 1 = enable passive service checks (default).',
        'process_perf_data' => 'This directive is used to determine whether or not the processing of performance data is enabled for this service.  Values: 0 = disable performance data processing, 1 = enable performance data processing.',
        'retain_nonstatus_information' => 'This directive is used to determine whether or not non-status information about the service is retained across program restarts.  This is only useful if you have enabled state retention using the retain_state_information directive.  Value: 0 = disable non-status information retention, 1 = enable non-status information retention.',
        'retain_status_information' => 'This directive is used to determine whether or not status-related information about the service is retained across program restarts.  This is only useful if you have enabled state retention using the retain_state_information directive.  Value: 0 = disable status information retention, 1 = enable status information retention.',
        'retry_interval' => 'This directive is used to define the number of "time units" to wait before scheduling a re-check of the service.  Services are rescheduled at the retry interval when they have changed to a non-OK state.  Once the service has been retried <b>max_check_attempts</b> times without a change in its status, it will revert to being scheduled at its "normal" rate as defined by the <b>check_interval</b> value. Unless you\'ve changed the interval_length directive from the default value of 60, this number will mean minutes.  More information on this value can be found in the check scheduling documentation.',
        'service_description' => 'This directive is used to define the description of the service, which may contain spaces, dashes, and colons (semicolons, apostrophes, and quotation marks should be avoided).  No two services associated with the same host can have the same description.  Services are uniquely identified with their <i>host_name</i> and <i>service_description</i> directives.',
        'servicegroups' => 'This directive is used to identify the <i>short name(s)</i> of the servicegroup(s) that the service belongs to.  Multiple servicegroups should be separated by commas.  This directive may be used as an alternative to using the <i>members</i> directive in servicegroup definitions.',
        'stalking_options' => 'This directive determines which service states "stalking" is enabled for.  Valid options are a combination of one or more of the following: <b>o</b> = stalk on OK states, <b>w</b> = stalk on WARNING states, <b>u</b> = stalk on UNKNOWN states, and <b>c</b> = stalk on CRITICAL states.  More information on state stalking can be found here.',
        'realm' => 'This variable is used to define the realm where the host will be put. By putting the host in a realm, it will be manage by one of the scheduler of this realm.',
        'poller_tag' => 'This variable is used to define the poller_tag of the host. All checks of this hosts will only take by pollers that have this value in their poller_tags parameter. By default there is no poller_tag, so all untagged pollers can take it.',
        'business_impact' => 'This variable is used to set the importance we gave to this host for the business from the less important (0 = nearly nobody will see if it\'s in error) to the maximum (5 = you lost your job if it fail). The default value is 2.',
        'resultmodulations' => 'This variable is used to link with resultmodulations objects. It will allow such modulation to apply, like change a warning in critical for this host.',
        'escalations' => 'This variable is used to link with escalations objects. It will allow such escalations rules to appy. Look at escalations objects for more details.',
        'business_impact_modulations' => 'This variable is used to link with business_impact_modulations objects. It will allow such modulation to apply (for example if the host is a payd server, it will be important only in a specific timeperiod: near the payd day). Look at business_impact_modulations objects for more details.',
        'service_dependencies' => 'This variable is used to define services that this serice is dependent of for notifications. It\'s a comma separated list of service like host,service_description. For each service a service_dependency will be created with default values (notification_failure_criteria as \'u,c,w\' and no dependency_period). By default this value is void so there is no linked dependencies.',
        'icon_set' => 'This variable is used to set the icon in the Shinken Webui. For now, values are only : database, disk, network_service, server',
        'maintenance_period' => 'no help yet',
        'reactionner_tag' => 'no help yet',
    },
    'servicedependency' => {
        'dependency_period' => 'This directive is used to specify the short name of the time period during which this dependency is valid.  If this directive is not specified, the dependency is considered to be valid during all times.',
        'dependent_host_name' => 'This directive is used to identify the <i>short name(s)</i> of the host(s) that the <i>dependent</i> service "runs" on or is associated with.  Multiple hosts should be separated by commas.  Leaving this directive blank can be used to create "same host" dependencies.',
        'dependent_hostgroup_name' => 'This directive is used to specify the <i>short name(s)</i> of the hostgroup(s) that the <i>dependent</i> service "runs" on or is associated with.  Multiple hostgroups should be separated by commas.  The dependent_hostgroup may be used instead of, or in addition to, the dependent_host directive.',
        'dependent_servicegroup_name' => 'This directive is used to specify the <i>short name(s)</i> of the servicegroup(s) that the <i>dependent</i> service "runs" on or is associated with.  Multiple servicegroups should be separated by commas.',
        'dependent_service_description' => 'This directive is used to identify the <i>description</i> of the <i>dependent</i> service.',
        'execution_failure_criteria' => 'This directive is used to specify the criteria that determine when the dependent service should <i>not</i> be actively checked.  If the <i>master</i> service is in one of the failure states we specify, the <i>dependent</i> service will not be actively checked.  Valid options are a combination of one or more of the following (multiple options are separated with commas): <b>o</b> = fail on an OK state, <b>w</b> = fail on a WARNING state, <b>u</b> = fail on an UNKNOWN state, <b>c</b> = fail on a CRITICAL state, and <b>p</b> = fail on a pending state (e.g. the service has not yet been checked).  If you specify <b>n</b> (none) as an option, the execution dependency will never fail and checks of the dependent service will always be actively checked (if other conditions allow for it to be).  Example: If you specify <b>o,c,u</b> in this field, the <i>dependent</i> service will not be actively checked if the <i>master</i> service is in either an OK, a CRITICAL, or an UNKNOWN state.',
        'host_name' => 'This directive is used to identify the <i>short name(s)</i> of the host(s) that the service <i>that is being depended upon</i> (also referred to as the master service) "runs" on or is associated with.  Multiple hosts should be separated by commas.',
        'hostgroup_name' => 'This directive is used to identify the <i>short name(s)</i> of the hostgroup(s) that the service <i>that is being depended upon</i> (also referred to as the master service) "runs" on or is associated with.  Multiple hostgroups should be separated by commas.  The hostgroup_name may be used instead of, or in addition to, the host_name directive.',
        'inherits_parent' => 'This directive indicates whether or not the dependency inherits dependencies of the service <i>that is being depended upon</i> (also referred to as the master service).  In other words, if the master service is dependent upon other services and any one of those dependencies fail, this dependency will also fail.',
        'notification_failure_criteria' => 'This directive is used to define the criteria that determine when notifications for the dependent service should <i>not</i> be sent out.  If the <i>master</i> service is in one of the failure states we specify, notifications for the <i>dependent</i> service will not be sent to contacts.  Valid options are a combination of one or more of the following: <b>o</b> = fail on an OK state, <b>w</b> = fail on a WARNING state, <b>u</b> = fail on an UNKNOWN state, <b>c</b> = fail on a CRITICAL state, and <b>p</b> = fail on a pending state (e.g. the service has not yet been checked).  If you specify <b>n</b> (none) as an option, the notification dependency will never fail and notifications for the dependent service will always be sent out.  Example: If you specify <b>w</b> in this field, the notifications for the <i>dependent</i> service will not be sent out if the <i>master</i> service is in a WARNING state.',
        'service_description' => 'This directive is used to identify the <i>description</i> of the service <i>that is being depended upon</i> (also referred to as the master service).'
    },
    'serviceescalation' => {
        'contact_groups' => 'This directive is used to identify the <i>short name</i> of the contact group that should be notified when the service notification is escalated.  Multiple contact groups should be separated by commas.  You must specify at least one contact or contact group in each service escalation definition.',
        'contacts' => 'This is a list of the <i>short names</i> of the contacts that should be notified whenever there are problems (or recoveries) with this service.  Multiple contacts should be separated by commas.  Useful if you want notifications to go to just a few people and don\'t want to configure contact groups.  You must specify at least one contact or contact group in each service escalation definition.',
        'escalation_options' => 'This directive is used to define the criteria that determine when this service escalation is used.  The escalation is used only if the service is in one of the states specified in this directive.  If this directive is not specified in a service escalation, the escalation is considered to be valid during all service states.  Valid options are a combination of one or more of the following: <b>r</b> = escalate on an OK (recovery) state, <b>w</b> = escalate on a WARNING state, <b>u</b> = escalate on an UNKNOWN state, and <b>c</b> = escalate on a CRITICAL state.   Example: If you specify <b>w</b> in this field, the escalation will only be used if the service is in a WARNING state.',
        'escalation_period' => 'This directive is used to specify the short name of the time period during which this escalation is valid.  If this directive is not specified, the escalation is considered to be valid during all times.',
        'first_notification' => 'This directive is a number that identifies the <i>first</i> notification for which this escalation is effective.  For instance, if you set this value to 3, this escalation will only be used if the service is in a non-OK state long enough for a third notification to go out.',
        'host_name' => 'This directive is used to identify the <i>short name(s)</i> of the host(s) that the service escalation should apply to or is associated with.',
        'hostgroup_name' => 'This directive is used to specify the <i>short name(s)</i> of the hostgroup(s) that the service escalation should apply to or is associated with.  Multiple hostgroups should be separated by commas.  The hostgroup_name may be used instead of, or in addition to, the host_name directive.',
        'servicegroup_name' => 'This directive is used to specify the <i>short name(s)</i> of the servicegroup(s) that the service escalation should apply to or is associated with. Multiple servicegroups should be separated by commas. The servicegroup_name may be used instead of, or in addition to, the service_name directive.',
        'last_notification' => 'This directive is a number that identifies the <i>last</i> notification for which this escalation is effective.  For instance, if you set this value to 5, this escalation will not be used if more than five notifications are sent out for the service.  Setting this value to 0 means to keep using this escalation entry forever (no matter how many notifications go out).',
        'notification_interval' => 'This directive is used to determine the interval at which notifications should be made while this escalation is valid.  If you specify a value of 0 for the interval, Nagios will send the first notification when this escalation definition is valid, but will then prevent any more problem notifications from being sent out for the host.  Notifications are sent out again until the host recovers.  This is useful if you want to stop having notifications sent out after a certain amount of time.  Note:  If multiple escalation entries for a host overlap for one or more notification ranges, the smallest notification interval from all escalation entries is used.',
        'service_description' => 'This directive is used to identify the <i>description</i> of the service the escalation should apply to.'
    },
    'serviceextinfo' => {
        'action_url' => 'This directive is used to define an optional URL that can be used to provide more actions to be performed on the service.  If you specify an URL, you will see a link that says "Extra Service Actions" in the extended information CGI (when you are viewing information about the specified service).  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).',
        'host_name' => 'This directive is used to identify the <i>short name</i> of the host that the service is associated with.',
        'icon_image' => 'This variable is used to define the name of a GIF, PNG, or JPG image that should be associated with this host.  This image will be displayed in the status and extended information CGIs.  The image will look best if it is 40x40 pixels in size.  Images for hosts are assumed to be in the <b>logos/</b> subdirectory in your HTML images directory (i.e. <i>/usr/local/nagios/share/images/logos</i>).',
        'icon_image_alt' => 'This variable is used to define an optional string that is used in the ALT tag of the image specified by the <i>&lt;icon_image&gt;</i> argument.  The ALT tag is used in the status, extended information and statusmap CGIs.',
        'notes' => 'This directive is used to define an optional string of notes pertaining to the service.  If you specify a note here, you will see the it in the extended information CGI (when you are viewing information about the specified service).',
        'notes_url' => 'This directive is used to define an optional URL that can be used to provide more information about the service.  If you specify an URL, you will see a link that says "Extra Service Notes" in the extended information CGI (when you are viewing information about the specified service).  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).  This can be very useful if you want to make detailed information on the service, emergency contact methods, etc. available to other support staff.',
        'service_description' => 'This directive is description of the service which the data is associated with.'
    },
    'servicegroup' => {
        'action_url' => 'This directive is used to define an optional URL that can be used to provide more actions to be performed on the service group.  If you specify an URL, you will see a red "splat" icon in the CGIs (when you are viewing service group information) that links to the URL you specify here.  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).',
        'alias' => 'This directive is used to define is a longer name or description used to identify the service group.  It is provided in order to allow you to more easily identify a particular service group.',
        'members' => '<p>This is a list of the <i>descriptions</i> of services (and the names of their corresponding hosts) that should be included in this group.   Host and service names should be separated by commas.  This directive may be used as an alternative to the <i>servicegroups</i> directive in service definitions.  The format of the member directive is as follows (note that a host name must precede a service name/description):</p><p>members=&lt;host1&gt;,&lt;service1&gt;,&lt;host2&gt;,&lt;service2&gt;,...,&lt;host<i>n</i>&gt;,&lt;service<i>n</i>&gt;</p>',
        'notes' => 'This directive is used to define an optional string of notes pertaining to the service group.  If you specify a note here, you will see the it in the extended information CGI (when you are viewing information about the specified service group).',
        'notes_url' => 'This directive is used to define an optional URL that can be used to provide more information about the service group.  If you specify an URL, you will see a red folder icon in the CGIs (when you are viewing service group information) that links to the URL you specify here.  Any valid URL can be used.  If you plan on using relative paths, the base path will the the same as what is used to access the CGIs (i.e. <i>/cgi-bin/nagios/</i>).  This can be very useful if you want to make detailed information on the service group, emergency contact methods, etc. available to other support staff.',
        'servicegroup_members' => 'This optional directive can be used to include services from other "sub" service groups in this service group.  Specify a comma-delimited list of short names of other service groups whose members should be included in this group.',
        'servicegroup_name' => 'This directive is used to define a short name used to identify the service group.'
    },
    'timeperiod' => {
        '[exception]' => '<p>You can specify several different types of exceptions to the standard rotating weekday schedule.  Exceptions can take a number of different forms including single days of a specific or generic month, single weekdays in a month, or single calendar dates.  You can also specify a range of days/dates and even specify skip intervals to obtain functionality described by "every 3 days between these dates".  Rather than list all the possible formats for exception strings, I\'ll let you look at the example timeperiod definitions above to see what\'s possible. :-)  Weekdays and different types of exceptions all have different levels of precedence, so its important to understand how they can affect each other.  More information on this can be found in the documentation on timeperiods.</p>',
        '[weekday]' => 'The weekday directives ("<i>sunday</i>" through "<i>saturday</i>")are comma-delimited lists of time ranges that are "valid" times for a particular day of the week.  Notice that there are seven different days for which you can define time ranges (Sunday through Saturday).  Each time range is in the form of <b>HH:MM-HH:MM</b>, where hours are specified on a 24 hour clock.  For example, <b>00:15-24:00</b> means 12:15am in the morning for this day until 12:00am midnight (a 23 hour, 45 minute total time range).  If you wish to exclude an entire day from the timeperiod, simply do not include it in the timeperiod definition.',
        'alias' => 'This directive is a longer name or description used to identify the time period.',
        'exclude' => 'This directive is used to specify the short names of other timeperiod definitions whose time ranges should be excluded from this timeperiod.  Multiple timeperiod names should be separated with a comma.',
        'timeperiod_name' => 'This directives is the short name used to identify the time period.'
    },
    'module' => {
        'module_name' => 'This directive identifies the unique name of the module so you cannot have two modules with the same module name. It is mandatory, otherwise the config will not be accepted and the module will not be loaded.',
        'module_type' => '<p><b>Icinga:</b> This optional directive defines the type of the module, e.g. &#39;neb&#39; for event broker modules. This directive is intended to allow further filtering on the module loading.</p><p><b>Shinken:</b> This mandatory directive defines the type of the module.</p>',
        'path' => 'mandatory directive specifies the path to the module binary to be loaded. For event broker modules like idomod the user running the core must be allowed to read and load the module.',
        'args' => 'This directive defines optional arguments passed to the module. idomod needs config_file=.../idomod.cfg while other modules have their own syntax. This directive is passed as argument string to the event broker module loader if used as neb module.',
        'modules' => 'List of submodules.',

        'host' => 'Host name or IP address to connect or listen to (depending on the module).',
        'port' => 'TCP port to connect or listen to (depending on the module).'
    },
    'escalation' => {
        'escalation_name' => 'This directive identifies the unique name of the escalation so you reference this escalation by your hosts and services.',
        'contact_groups' => 'This directive is used to identify the <i>short name</i> of the contact group that should be notified when the host notification is escalated.  Multiple contact groups should be separated by commas.  You must specify at least one contact or contact group in each host escalation definition.',
        'contacts' => 'This is a list of the <i>short names</i> of the contacts that should be notified whenever there are problems (or recoveries) with this host.  Multiple contacts should be separated by commas.  Useful if you want notifications to go to just a few people and don\'t want to configure contact groups.  You must specify at least one contact or contact group in each host escalation definition.',
        'escalation_options' => 'This directive is used to define the criteria that determine when this host escalation is used.  The escalation is used only if the host is in one of the states specified in this directive.  If this directive is not specified in a host escalation, the escalation is considered to be valid during all host states.  Valid options are a combination of one or more of the following: <b>r</b> = escalate on an UP (recovery) state, <b>d</b> = escalate on a DOWN state, and <b>u</b> = escalate on an UNREACHABLE state.   Example: If you specify <b>d</b> in this field, the escalation will only be used if the host is in a DOWN state.',
        'escalation_period' => 'This directive is used to specify the short name of the time period during which this escalation is valid.  If this directive is not specified, the escalation is considered to be valid during all times.',
        'first_notification_time' => 'This directive is a number that identifies the <i>first</i> notification for which this escalation is effective.  For instance, if you set this value to 3, this escalation will only be used if the host is down or unreachable long enough for a third notification to go out.',
        'last_notification_time' => 'This directive is a number that identifies the <i>last</i> notification for which this escalation is effective.  For instance, if you set this value to 5, this escalation will not be used if more than five notifications are sent out for the host.  Setting this value to 0 means to keep using this escalation entry forever (no matter how many notifications go out).',
        'notification_interval' => 'This directive is used to determine the interval at which notifications should be made while this escalation is valid.  If you specify a value of 0 for the interval, Nagios will send the first notification when this escalation definition is valid, but will then prevent any more problem notifications from being sent out for the host.  Notifications are sent out again until the host recovers.  This is useful if you want to stop having notifications sent out after a certain amount of time.  Note:  If multiple escalation entries for a host overlap for one or more notification ranges, the smallest notification interval from all escalation entries is used.',
    },
    'arbiter' => {
        'address' => 'DNS name of ip address',
        'timeout' => 'Number of seconds to waint when pinging the daemon',
        'data_timeout' => 'Number of seconds to wait when sending data',
        'check_interval' => 'Number of seconds to wait before issuing a new ping check',
        'max_check_attempts' => 'Number of failed pings before marking the node as dead',
        'spare' => 'Is this daemon a failover slave',
        #'manage_sub_realms' => 'Does this daemon take jobs from the subdomains too <i>(default value is false for pollers, and true for reactionners and brokers)</i>',
        #'manage_arbiters' => 'Take data from Arbiter. There should be only one broker for the arbiter.',
        'modules' => 'List of submodules.',
        #'polling_interval' => 'Get jobs from schedulers each N seconds.',
        'use_timezone' => 'Override the default timezone that this instance of Shinken runs in.',
        'realm' => 'Daemon realm',
        'satellitemap' => '<p>In NATted environments, you declare each satellite ip[:port] as seen by <b>this</b> scheduler <i>(if port not set, the port declared by satellite itself is used)</i>.</p><p><b>Example:</b> <pre>poller-1=1.2.3.4:1772, reactionner-1=1.2.3.5:1773</pre></p>',
        'use_ssl' => 'Use SSL',

        'arbiter_name' => 'This directive identifies the unique name of the daemon.',
        'host_name' => 'Host name.',
        'port' => 'TCP port.',
    },
    'broker' => {
        'address' => 'DNS name of ip address',
        'timeout' => 'Number of seconds to waint when pinging the daemon',
        'data_timeout' => 'Number of seconds to wait when sending data',
        'check_interval' => 'Number of seconds to wait before issuing a new ping check',
        'max_check_attempts' => 'Number of failed pings before marking the node as dead',
        'spare' => 'Is this daemon a failover slave',
        'manage_sub_realms' => 'Does this daemon take jobs from the subdomains too <i>(default value is false for pollers, and true for reactionners and brokers)</i>',
        'manage_arbiters' => 'Take data from Arbiter. There should be only one broker for the arbiter.',
        'modules' => 'List of submodules.',
        'polling_interval' => 'Get jobs from schedulers each N seconds.',
        'use_timezone' => 'Override the default timezone that this instance of Shinken runs in.',
        'realm' => 'Daemon realm',
        'satellitemap' => '<p>In NATted environments, you declare each satellite ip[:port] as seen by <b>this</b> scheduler <i>(if port not set, the port declared by satellite itself is used)</i>.</p><p><b>Example:</b> <pre>poller-1=1.2.3.4:1772, reactionner-1=1.2.3.5:1773</pre></p>',
        'use_ssl' => 'Use SSL',

        'broker_name' => 'This directive identifies the unique name of the daemon.',
        'port' => 'TCP port.',
    },
    'poller' => {
        'address' => 'DNS name of ip address',
        'timeout' => 'Number of seconds to waint when pinging the daemon',
        'data_timeout' => 'Number of seconds to wait when sending data',
        'check_interval' => 'Number of seconds to wait before issuing a new ping check',
        'max_check_attempts' => 'Number of failed pings before marking the node as dead',
        'spare' => 'Is this daemon a failover slave',
        'manage_sub_realms' => 'Does this daemon take jobs from the subdomains too <i>(default value is false for pollers, and true for reactionners and brokers)</i>',
        #'manage_arbiters' => 'Take data from Arbiter. There should be only one broker for the arbiter.',
        'modules' => 'List of submodules.',
        'polling_interval' => 'Get jobs from schedulers each N seconds.',
        'use_timezone' => 'Override the default timezone that this instance of Shinken runs in.',
        'realm' => 'Daemon realm',
        'satellitemap' => '<p>In NATted environments, you declare each satellite ip[:port] as seen by <b>this</b> scheduler <i>(if port not set, the port declared by satellite itself is used)</i>.</p><p><b>Example:</b> <pre>poller-1=1.2.3.4:1772, reactionner-1=1.2.3.5:1773</pre></p>',
        'use_ssl' => 'Use SSL',

        'poller_name' => 'This directive identifies the unique name of the daemon.',
        'port' => 'TCP port.',
        'passive' => 'Is this daemon passive.',
        'min_workers' => 'Starts with N processes (0 = 1 per CPU)',
        'max_workers' => 'No more than N processes (0 = 1 per CPU)',
        'processes_by_worker' => 'Each worker manages N checks',
        'poller_tags' => 'This variable is used to define the checks the poller can take. If no poller_tags is defined, poller will take all untagued checks. If at least one tag is defined, it will take only the checks that are also taggued like it.',
    },
    'reactionner' => {
        'address' => 'DNS name of ip address',
        'timeout' => 'Number of seconds to waint when pinging the daemon',
        'data_timeout' => 'Number of seconds to wait when sending data',
        'check_interval' => 'Number of seconds to wait before issuing a new ping check',
        'max_check_attempts' => 'Number of failed pings before marking the node as dead',
        'spare' => 'Is this daemon a failover slave',
        'manage_sub_realms' => 'Does this daemon take jobs from the subdomains too <i>(default value is false for pollers, and true for reactionners and brokers)</i>',
        'manage_arbiters' => 'Take data from Arbiter. There should be only one broker for the arbiter.',
        'modules' => 'List of submodules.',
        'polling_interval' => 'Get jobs from schedulers each N seconds.',
        'use_timezone' => 'Override the default timezone that this instance of Shinken runs in.',
        'realm' => 'Daemon realm',
        'satellitemap' => '<p>In NATted environments, you declare each satellite ip[:port] as seen by <b>this</b> scheduler <i>(if port not set, the port declared by satellite itself is used)</i>.</p><p><b>Example:</b> <pre>poller-1=1.2.3.4:1772, reactionner-1=1.2.3.5:1773</pre></p>',
        'use_ssl' => 'Use SSL',

        'reactionner_name' => 'This directive identifies the unique name of the daemon.',
        'port' => 'TCP port.',
        'passive' => 'Is this daemon passive.',
        'min_workers' => 'Starts with N processes (0 = 1 per CPU)',
        'max_workers' => 'No more than N processes (0 = 1 per CPU)',
        'processes_by_worker' => 'Each worker manages N checks',
        'poller_tags' => 'This variable is used to define the checks the poller can take. If no poller_tags is defined, poller will take all untagued checks. If at least one tag is defined, it will take only the checks that are also taggued like it.',
    },
    'receiver' => {
        'address' => 'DNS name of ip address',
        'timeout' => 'Number of seconds to waint when pinging the daemon',
        'data_timeout' => 'Number of seconds to wait when sending data',
        'check_interval' => 'Number of seconds to wait before issuing a new ping check',
        'max_check_attempts' => 'Number of failed pings before marking the node as dead',
        'spare' => 'Is this daemon a failover slave',
        'manage_sub_realms' => 'Does this daemon take jobs from the subdomains too <i>(default value is false for pollers, and true for reactionners and brokers)</i>',
        'manage_arbiters' => 'Take data from Arbiter. There should be only one broker for the arbiter.',
        'modules' => 'List of submodules.',
        'polling_interval' => 'Get jobs from schedulers each N seconds.',
        'use_timezone' => 'Override the default timezone that this instance of Shinken runs in.',
        'realm' => 'Daemon realm',
        'satellitemap' => '<p>In NATted environments, you declare each satellite ip[:port] as seen by <b>this</b> scheduler <i>(if port not set, the port declared by satellite itself is used)</i>.</p><p><b>Example:</b> <pre>poller-1=1.2.3.4:1772, reactionner-1=1.2.3.5:1773</pre></p>',
        'use_ssl' => 'Use SSL',

        'receiver_name' => 'This directive identifies the unique name of the daemon.',
        'port' => 'TCP port.',
        'direct_routing' => 'Send commands directly to schedulers',
    },
    'scheduler' => {
        'address' => 'DNS name of ip address',
        'timeout' => 'Number of seconds to waint when pinging the daemon',
        'data_timeout' => 'Number of seconds to wait when sending data',
        'check_interval' => 'Number of seconds to wait before issuing a new ping check',
        'max_check_attempts' => 'Number of failed pings before marking the node as dead',
        'spare' => 'Is this daemon a failover slave',
        'manage_sub_realms' => 'Does this daemon take jobs from the subdomains too <i>(default value is false for pollers, and true for reactionners and brokers)</i>',
        'manage_arbiters' => 'Take data from Arbiter. There should be only one broker for the arbiter.',
        'modules' => 'List of submodules.',
        'polling_interval' => 'Get jobs from schedulers each N seconds.',
        'use_timezone' => 'Override the default timezone that this instance of Shinken runs in.',
        'realm' => 'Daemon realm',
        'satellitemap' => '<p>In NATted environments, you declare each satellite ip[:port] as seen by <b>this</b> scheduler <i>(if port not set, the port declared by satellite itself is used)</i>.</p><p><b>Example:</b> <pre>poller-1=1.2.3.4:1772, reactionner-1=1.2.3.5:1773</pre></p>',
        'use_ssl' => 'Use SSL',

        'scheduler_name' => 'This directive identifies the unique name of the daemon.',
        'port' => 'TCP port.',
        'weight' => 'Some schedulers can manage more hosts than others',
        'skip_initial_broks' => 'Skip initial broks creation for faster boot time <i>(experimental feature)</i>.',
    },
    'discoveryrule' => {
        'discoveryrule_name' => 'This directive identifies the unique name of the discoveryrule so you reference it by your objects.',
        'creation_type' => 'What type of object to create.',
        'discoveryrule_order' => 'The smallest number is applied first',
        'isup' => 'Match if host is alive.',
        'os' => 'Match against operating system name.',
        'osversion' => 'Match against operating system version.',
        'macvendor' => 'Match against vendor from MAC address.',
        'openports' => 'Match against opened TCP ports.',
        'parents' => 'Match against parent hosts.',
        'fqdn' => 'Match against DNS name.',
        'ip' => 'Match against IP address.',
        'fs' => 'Match against filesystem.',
    },
    'discoveryrun' => {
        'discoveryrun_name' => 'This directive identifies the unique name of the discoveryrun so you reference it by your objects.',
        'discoveryrun_command' => 'Discovery command to run.',
    },
    'notificationway' => {
        'notificationway_name' => 'This directive identifies the unique name of the notificationway so you reference it by your contacts.n',
        'host_notifications_enabled' => 'This directive is used to determine whether or not the contact will receive notifications about host problems and recoveries.  Values: 0 = don\'t send notifications, 1 = send notifications.',
        'service_notifications_enabled' => 'This directive is used to determine whether or not the contact will receive notifications about service problems and recoveries.  Values: 0 = don\'t send notifications, 1 = send notifications.',
        'host_notification_period' => 'This directive is used to specify the short name of the time period during which the contact can be notified about host problems or recoveries.  You can think of this as an "on call" time for host notifications for the contact.  Read the documentation on time periods for more information on how this works and potential problems that may result from improper use.',
        'service_notification_period' => 'This directive is used to specify the short name of the time period during which the contact can be notified about service problems or recoveries.  You can think of this as an "on call" time for service notifications for the contact.  Read the documentation on time periods for more information on how this works and potential problems that may result from improper use.',
        'host_notification_options' => 'This directive is used to define the host states for which notifications can be sent out to this contact.  Valid options are a combination of one or more of the following: <b>d</b> = notify on DOWN host states, <b>u</b> = notify on UNREACHABLE host states, <b>r</b> = notify on host recoveries (UP states), <b>f</b> = notify when the host starts and stops flapping, and <b>s</b> = send notifications when host or service scheduled downtime starts and ends.  If you specify <b>n</b> (none) as an option, the contact will not receive any type of host notifications.',
        'service_notification_options' => 'This directive is used to define the service states for which notifications can be sent out to this contact.  Valid options are a combination of one or more of the following: <b>w</b> = notify on WARNING service states, <b>u</b> = notify on UNKNOWN service states, <b>c</b> = notify on CRITICAL service states, <b>r</b> = notify on service recoveries (OK states), and <b>f</b> = notify when the service starts and stops flapping.  If you specify <b>n</b> (none) as an option, the contact will not receive any type of service notifications.',
        'host_notification_commands' => 'This directive is used to define a list of the <i>short names</i> of the commands used to notify the contact of a <i>host</i> problem or recovery.  Multiple notification commands should be separated by commas.  Allnotification commands are executed when the contact needs to be notified.  The maximum amount of time that a notification command can run is controlled by the notification_timeout option.',
        'service_notification_commands' => 'This directive is used to define a list of the <i>short names</i> of the commands used to notify the contact of a <i>service</i> problem or recovery.  Multiple notification commands should be separated by commas.  Allnotification commands are executed when the contact needs to be notified.  The maximum amount of time that a notification command can run is controlled by the notification_timeout option.',
        'min_business_impact' => 'Minimum business criticity level',
    },
    'realm' => {
        'realm_name' => 'This directive identifies the unique name of the realm so you reference it by your objects.',
        'realm_members' => 'This directive is used to define the sub-realms of this realms.',
        'default' => 'This directive is used to define if this realm is the default one (untagged host and satellites wil be put into it). The default value is 0.',
        'broker_complete_links' => 'Enable multi-brokers features',
    },
};
