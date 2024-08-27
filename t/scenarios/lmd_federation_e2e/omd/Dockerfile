FROM  local/thruk-labs-rocky:nightly

# uncomment to test against latest daily
#RUN rpm -Uvh "https://labs.consol.de/repo/testing/rhel7/i386/labs-consol-testing.rhel7.noarch.rpm"
#RUN yum -y makecache
#RUN yum -y install omd-labs-edition-daily
#RUN omd -f update demo

COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH=/thruk/t/scenarios/_common/ansible/roles
