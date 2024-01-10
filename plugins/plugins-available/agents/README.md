## Agents Thruk Plugin

Agent configuration for SNClient+ agents in Naemon.

![Thruk Agents Plugin](preview.png "Thruk Agents Plugin")

## Installation

Assuming you are using OMD (omdistro.org).
All steps have to be done as site user:

    %> cd etc/thruk/plugins-enabled/
    %> git clone https://github.com/sni/thruk-plugin-agents.git agents
    %> omd reload apache

You now have a new menu item under System -> Agents.

Create a example configuration file:

`~/etc/thruk/thruk_local.d/agents.conf`.

For example:

    <Component Thruk::Agents>
      <snclient>
        # use a default backend if there are multiple
        default_backend = LOCAL

        # set a default password macro, ex.: $USER5$
        default_password = $USER5$

        # add extra options to check_nsc_web
        check_nsc_web_extra_options = "-k -t 35"

        # override check interval
        check_interval = 1
        retry_interval = 0.5
        max_check_attempts = 5

        # override inventory interval
        inventory_interval = 60

        # set default contact(s)
        #default_contacts = admin, other

        # set default contactgroups(s)
        #default_contactgroups = group, ...

        # set performance data templates (default is autodetect based on whether grafana is enabled)
        #perf_template      = srv-perf
        #host_perf_template = host-perf

        # disable network checks matching these attributes
        <disable network>
          enabled != true
          name    ~ ^(lo|.*Loopback)
          flags   ~ loopback
        </disable>

        # disable check_drivesize checks matching these attributes
        <disable drivesize>
          fstype  ~ ^(tracefs|securityfs|debugfs|configfs|pstorefs|fusectl|cgroup2fs|bpf|efivarfs|sysfs|fuseblk|rpc_pipefs|nsfs|ramfs|binfmt_misc|proc|nfs|devpts|mqueue|hugetlbfs)$
          drive   ~ ^(/run/|/dev|/boot/efi|/proc|/sys)
          mounted = 0
          drive   =
        </disable>

        # disable services by name or type
        <exclude>
          #name = check_users   # name string match
          #name ~ net lo        # name regex match
          #type = df./proc      # type string match
          #type ~ ^extscript\.  # type regex, disable all external scripts by default
          #host !~ \.win\.      # apply this exclude only to specific hosts, only hosts not matching ".win."
          #host ~ ^l            # apply this exclude only to hosts starting with an "l"
          #section ~ test       # apply this exclude only to sections containing "test"
        </exclude>

        # include services in discovery
        <service>
          # service name (available placeholder: %s - service name)
          name  = service %s
          service = snclient
          service = apache2
          service = postfix
          service = ssh
          service = exim4
          service = mariadb
          service = ntp
          service = squid

          # restrict to specific hosts (regular expression)
          #host = ANY
          #section ~ test # apply this service only to sections containing "test"
        </service>

        <proc>
          # service name (available placeholder: %u - user | %e - executable)
          name  = ssh controlmaster %u
          match = /usr/bin/ssh.*ControlMaster=yes
          user  = mon
          # restrict to specific hosts (regular expression)
          #host = ANY
          #section ~ test # apply this process check only to sections containing "test"
          #warn = 1:5  # warning threshold for number of processes (low:high)
          #crit = 1:10 # critical threshold
        </proc>

        <proc>
          # if no match is given, use the name as exe filter
          name  = snclient
          name  = httpd
        </proc>

        # set default args (if multiple args match, the last one overrides previous ones)
        <args>
          value = warn='load > 95' crit='load > 100'
          match = cpu # regex match on service name
          # restrict to specific hosts (regular expression)
          #host = ANY
          #section ~ test # apply this process check only to sections containing "test"
        </args>

      </snclient>
    </Component>

You have to reload the apache to activate changes
from the `thruk_local.d` folder.
