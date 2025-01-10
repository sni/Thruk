FROM ghcr.io/consol/omd-labs-docker/omd-labs-rocky:nightly

COPY ansible /root/ansible/
ENV  ANSIBLE_ROLES_PATH=/root/ansible/roles
RUN /root/ansible/install_role.sh common
RUN /root/ansible/install_role.sh thruk_developer
RUN /root/ansible/install_role.sh test-config-generator
RUN /root/ansible/install_role.sh local_tests

# improve startup time of grafana after first launch
RUN omd config demo set GRAFANA on; omd start demo grafana; omd stop demo; omd config demo set GRAFANA off

# improve startup time of influxdb after first launch
RUN omd config demo set INFLUXDB on; omd start demo influxdb; omd stop demo; omd config demo set INFLUXDB off

RUN echo -e "#!/bin/bash\n\nansible-playbook -i localhost, \"/provision/playbook.yml\" -c local -e SITENAME=\$SITENAME\n" > /root/ansible_provision.sh; chmod 755 /root/ansible_provision.sh

# show version string
RUN echo "omd-labs-rocky:nightly:omd version: $(omd version -b)"
