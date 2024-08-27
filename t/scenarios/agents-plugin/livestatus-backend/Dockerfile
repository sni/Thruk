FROM local/thruk-labs-rocky:nightly

COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH=/thruk/t/scenarios/_common/ansible/roles
COPY snclient_local.ini /root/
COPY agents.cfg /root/
