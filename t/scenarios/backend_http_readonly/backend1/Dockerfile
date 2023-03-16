FROM  ghcr.io/consol/omd-labs-docker/omd-labs-rocky:latest

COPY playbook.yml /root/ansible_dropin/
ENV  ANSIBLE_ROLES_PATH /thruk/t/scenarios/_common/ansible/roles
COPY test.cfg /root/
COPY 88db079c08a1aa46d4df2e5fb770d66d6572972cde4831ec64b20ccbe66f287b.SHA-256 /root/
