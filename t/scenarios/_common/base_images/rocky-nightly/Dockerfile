FROM  consol/omd-labs-rocky:nightly

COPY ansible /root/ansible/
ENV  ANSIBLE_ROLES_PATH /root/ansible/roles
RUN /root/ansible/install_role.sh common
RUN /root/ansible/install_role.sh thruk_developer
RUN /root/ansible/install_role.sh test-config-generator
