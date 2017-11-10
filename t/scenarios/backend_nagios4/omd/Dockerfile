FROM  consol/omd-labs-centos:latest

RUN yum -y makecache
RUN yum -y install wget gcc make gd-devel gcc-c++

COPY playbook.yml /root/ansible_dropin/
COPY test.cfg /root/
