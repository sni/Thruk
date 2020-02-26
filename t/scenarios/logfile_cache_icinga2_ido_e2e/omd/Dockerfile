FROM  consol/omd-labs-centos:nightly

COPY utf8.conf /root/
COPY add_user.sh /root/
COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH /thruk/t/scenarios/_common/ansible/roles
