FROM  ahannigan/docker-arachni

RUN apt-get -qq update ; \
    apt-get -qq install -y --no-install-recommends curl unzip ; \
    apt-get clean ; \
    rm -rf /var/lib/apt/lists
