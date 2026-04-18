FROM jenkins/jenkins:2.319.2@sha256:59355a8c68f415d5360e6e44c5aba352dcf9927dd4b0680ce7ff1233fb041a67

USER root

# TODO: curl-pipe-exec anti-pattern -- pin tyk-sync package and verify checksum
RUN apt-get update && \
    curl -O https://packagecloud.io/install/repositories/tyk/tyk-sync/script.deb.sh && \
    chmod +x script.deb.sh && \
    ./script.deb.sh && \
    apt-get install -y tyk-sync=2.1.0

USER jenkins
