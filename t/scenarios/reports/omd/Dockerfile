FROM  local/thruk-labs-rocky:nightly

COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH=/thruk/t/scenarios/_common/ansible/roles
COPY test.cfg /root/
COPY 1.rpt /root/
COPY 2.rpt /root/
COPY 3.rpt /root/
