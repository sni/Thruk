FROM  consol/omd-labs-centos:latest

RUN yum -y makecache
RUN yum -y install wget gcc make gd-devel gcc-c++

COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH /thruk/t/scenarios/_common/ansible/roles
COPY test.cfg /root/
