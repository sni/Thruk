FROM  ghcr.io/consol/omd-labs-docker/omd-labs-centos:v3.00

COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH=/thruk/t/scenarios/_common/ansible/roles
COPY test.cfg /root/
COPY auth_ldap.conf /root/
COPY ldif /root/ldif
COPY test.sh /root/
