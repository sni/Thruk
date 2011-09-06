################################################################
#                     SIGMA Informatique
################################################################


OBJECT :   Dashboard Plugin

DESC   :    New view for get stats on hostgroups and servicegroups. tested with Thruk 1.0.8.

PREREQUISITE : List::Compare

LINKS : Exemple links to add on menu :

add_section('name' => 'Dashboard', 'icon' => '/thruk/plugins/dashboard/thruk/images/dashboard.png');
  add_link('icon'  => '/thruk/plugins/dashboard/thruk/images/servicegroup_16.png', 'href'  => '/thruk/cgi-bin/dashboard.cgi?servicegroup=all&style=overview', 'name'  => 'DB Servicegroups', 'roles' => [qw/authorized_for_system_information/]);
  add_link('icon'  => '/thruk/plugins/dashboard/thruk/images/hostgroup_16.png', 'href'  => '/thruk/cgi-bin/dashboard.cgi?hostgroup=all&style=overview','name'  => 'DB Hostgroups','roles' => [qw/authorized_for_system_information/]);


################################################################
# Copyright © 2011 Sigma Informatique. All rights reserved.
# Copyright © 2010 Thruk Developer Team.
# Copyright © 2009 Nagios Core Development Team and Community Contributors.
# Copyright © 1999-2009 Ethan Galstad.
################################################################

Detailed Description:

Background color of the box for the dashboard service_group:

It does not take into account the background color of the states of hosts, they are present for informational purposes only, except for state downtime.

Priority of color on the business rules (from highest priority to lowest priority):
- Blue
- Red
- Yellow
- Orange
- Green

Blue (downtime)
- All services of the reference downtime (downtime in effect at the time of the request of the page)
- Or all servers in the reference downtime (downtime in effect at the time of the request of the page)

Red (critical):
- At least one non-critical service paid (acknowledge), not downtime.
- At least a critical service (paid or not) and not in downtime and whose host is not in service and no downtime OK valid (ie not in downtime).

Yellow (warning):
- At least one service warning unacknowledged (acknowledge), not downtime
- At least one warning service (paid or not) and not in downtime and whose host is not in service and no downtime OK valid (ie not in downtime).

Orange (unknown):
- At least one service unknown unacknowledged (acknowledge), not downtime
- At least one unknown service (paid or not) and not in downtime and whose host is not in service and no downtime OK valid (ie not in downtime).

Green (OK service group):
- At least one service and not OK in downtime and whose host downtime is not critical or warning, and if present, they are all acknowledge (in process) and / or downtime (or service-related host ).

Background color of the box for the dashboard HOST_GROUP:

It does not take into account the background color of the services of hosts, they are present for informational purposes only, except for state downtime.

Priority of color on the business rules (from highest priority to lowest priority):
- Blue
- Red
- Yellow
- Orange
- Green

Blue (downtime)
- All services of the reference downtime (downtime in effect at the time of the request of the page)
- Or all servers in the reference downtime (downtime in effect at the time of the request of the page)

Red (critical):
- At least one host critical unacknowledged (acknowledge), not downtime.
- At least one host review (paid or not) and not OK host downtime and no valid (ie not in downtime).

Yellow (warning):
- At least one host in flapping

Orange (unreacheable):
- At least one host unreacheable unacknowledged (acknowledge), not downtime
- At least one host unreacheable (paid or not) and not OK host downtime and no valid (ie not in downtime).

Green (OK service group):
- At least one host and not OK in downtime warning or critical and if present, they are all acknowledge (in process) and / or downtime.
