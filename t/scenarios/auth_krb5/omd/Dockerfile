FROM  local/thruk-labs-rocky:nightly

COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH=/thruk/t/scenarios/_common/ansible/roles
COPY krb5.conf /root/
COPY apache_auth_krb5.conf /root/
COPY naemon_grafana_example.cfg /root/
COPY thruk_local.conf /root/
