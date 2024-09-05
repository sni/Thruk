# Node Control Thruk Plugin

This plugin allows you to control nodes (OMD / OS) from within Thruk.

![Thruk Node Control Plugin](preview.png "Thruk Node Control Plugin")

## Features

- OMD installation
- OMD site updates
- OMD cleanup old unused versions
- OMD services start/stop
- OS Updates

## Installation

This plugin requires OMD ([omd.consol.de](https://omd.consol.de)).
All steps have to be done as site user:

    %> cd etc/thruk/plugins-enabled/
    %> git clone https://github.com/sni/thruk-plugin-node-control.git node-control
    %> omd reload apache

You now have a new menu item under System -> Node Control.

## Setup

The controlled sites need to have sudo permissions for omd and their package
manager.

- Debian: `siteuser  ALL=(ALL) NOPASSWD: /usr/bin/omd, NOPASSWD:SETENV: /usr/bin/apt-get`
- Centos: `siteuser  ALL=(ALL) NOPASSWD: /usr/bin/omd, NOPASSWD: /usr/bin/dnf`

(replace siteuser with the actual site user name)

Optional ssh login helps starting services if http connection does not work, for
ex. because the site is stopped.

## Configuration

    <Component Thruk::Plugin::NodeControl>
      #hook_update_pre  = if [ $(git status --porcelain 2>&1 | wc -l) -gt 0 ]; then echo "omd home not clean"; git status --porcelain 2>&1; exit 1; fi
      #hook_update_post = git add . && git commit -a -m "update to omd $(omd version -b)"

      # set to 0 to disable ssh fallback in case http connection fails
      #ssh_fallback = 1

      cmd_omd_cleanup         = sudo -n omd cleanup

      cmd_yum_pkg_install     = sudo -n yum install -y %PKG
      cmd_dnf_pkg_install     = sudo -n dnf install -y %PKG
      cmd_apt_pkg_install     = DEBIAN_FRONTEND=noninteractive sudo -En apt-get install -y %PKG

      cmd_yum_os_update       = sudo -n yum upgrade -y
      cmd_dnf_os_update       = sudo -n dnf upgrade -y
      cmd_apt_os_update       = DEBIAN_FRONTEND=noninteractive sudo -En apt-get upgrade -y

      cmd_yum_os_sec_update   = sudo -n yum upgrade -y --security
      cmd_dnf_os_sec_update   = sudo -n dnf upgrade -y --security
      cmd_apt_os_sec_update   = DEBIAN_FRONTEND=noninteractive sudo -En apt-get upgrade -y
    </Component>

Configure hooks to automatically checkin the version update into git. Requires
git and the omd site in a git repository.
