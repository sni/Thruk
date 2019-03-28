FROM consol/ubuntu-xfce-vnc
ENV REFRESHED_AT 2019-03-25

USER 0
RUN apt-get -y update && apt-get -y dist-upgrade && apt-get clean
RUN apt-get -y update && apt-get -y install krb5-user xvfb curl && apt-get clean
COPY krb5.conf /etc/krb5.conf
COPY user.js /tmp/user.js
COPY kinit.sh /headless/kinit.sh
RUN chmod 755 /headless/kinit.sh

USER 1000
RUN xvfb-run firefox -no-remote -CreateProfile default
RUN cp /tmp/user.js /headless/.mozilla/firefox/*.default/user.js
RUN echo /headless/kinit.sh >> /headless/.bashrc
