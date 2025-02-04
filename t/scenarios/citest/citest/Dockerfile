FROM  ubuntu:24.04

RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install \
        apt-utils \
        expect \
        lsb-release \
        mysql-server \
        sudo \
        systemd-cron \
        vim \
    ; \
    apt-get clean

COPY prepare_machine.sh /tmp/prepare_machine.sh
RUN mkdir -p /tmp/install
RUN cd /tmp/install && /tmp/prepare_machine.sh

CMD exec /bin/bash -c "trap : TERM INT; echo 'ci container ready'; sleep infinity & wait"
