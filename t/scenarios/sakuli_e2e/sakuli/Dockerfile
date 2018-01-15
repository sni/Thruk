FROM consol/sakuli-ubuntu-xfce:dev
MAINTAINER Sven Nierlein "sven@nierlein.de"

USER root
RUN apt-get update
RUN apt-get install -y lsof bash-completion gdb strace telnet
#RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
#RUN echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list
#RUN apt-get update
#RUN apt-get install -y google-chrome-stable
#
USER 1984
