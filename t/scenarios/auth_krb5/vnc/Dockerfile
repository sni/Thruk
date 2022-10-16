FROM consol/debian-xfce-vnc:nightly
ENV REFRESHED_AT 2019-03-25

USER 0
RUN apt-get -y update && apt-get -y install krb5-user xvfb curl && apt-get clean
COPY krb5.conf /etc/krb5.conf
COPY user.js /tmp/user.js
COPY kinit.sh /headless/kinit.sh
COPY ff_profile.sh /headless/ff_profile.sh
RUN chmod 755 /headless/kinit.sh

USER 1000
RUN /headless/ff_profile.sh
RUN echo /headless/kinit.sh >> /headless/.bashrc
