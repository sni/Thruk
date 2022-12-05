#!/bin/bash

ROLE=$1
shift

export ANSIBLE_RETRY_FILES_ENABLED="False"
ansible-playbook -i localhost, -c local -e SITENAME=demo "$@" /dev/stdin <<END
---
- hosts: localhost
  roles:
    - $ROLE
END
