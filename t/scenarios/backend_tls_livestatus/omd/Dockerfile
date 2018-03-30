FROM  consol/omd-labs-centos:nightly

COPY playbook.yml /root/ansible_dropin/
RUN mkdir -p /omd/sites/demo/etc/stunnel
COPY server.* xinetd.conf stunnel.conf /omd/sites/demo/etc/stunnel/
RUN chown demo: -R /omd/sites/demo/etc/stunnel
