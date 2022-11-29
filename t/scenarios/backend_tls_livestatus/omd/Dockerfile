FROM  consol/omd-labs-rocky:nightly

COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH /thruk/t/scenarios/_common/ansible/roles
RUN mkdir -p /omd/sites/demo/etc/stunnel
COPY server.* xinetd.conf stunnel.conf /omd/sites/demo/etc/stunnel/
RUN chown demo: -R /omd/sites/demo/etc/stunnel
