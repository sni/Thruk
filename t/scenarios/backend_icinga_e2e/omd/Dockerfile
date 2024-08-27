FROM  ghcr.io/consol/omd-labs-docker/omd-labs-centos:v2.90

COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH=/thruk/t/scenarios/_common/ansible/roles
COPY test.cfg /root/
