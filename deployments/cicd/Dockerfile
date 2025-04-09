FROM jenkins/jenkins:2.319.2

USER root

RUN apt-get update && \
    curl -O https://packagecloud.io/install/repositories/tyk/tyk-sync/script.deb.sh && \
    chmod +x script.deb.sh && \
    ./script.deb.sh && \
    apt-get install -y tyk-sync=2.1.0

USER jenkins