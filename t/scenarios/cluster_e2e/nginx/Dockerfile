FROM  nginx

RUN apt-get update; apt-get -y install vim lsof strace telnet procps; apt-get clean

COPY loadbalancer.conf /etc/nginx/conf.d/default.conf
