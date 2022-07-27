FROM consol/omd-labs-ubuntu:v4.40
COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH /thruk/t/scenarios/_common/ansible/roles
COPY thruk_local.conf /root/
COPY *.tbp /root/
