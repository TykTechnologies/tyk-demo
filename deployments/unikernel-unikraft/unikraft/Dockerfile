FROM --platform=linux/x86_64 golang:1.22.6-bookworm@sha256:d31e093e3aeaee68ccee6c4c96e554ef0f192ea37ae684d91b206bec17377f19 AS build

ARG TYK_VERSION=5.7.1

WORKDIR /tyk

RUN --mount=type=cache,target=/root/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git; \
    git clone --depth=1 --branch v${TYK_VERSION} https://github.com/TykTechnologies/tyk /tyk; \
    go build  \
      -buildmode=pie \
      -ldflags "-linkmode external -extldflags -static-pie" \
      -tags netgo;

FROM alpine:3@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS sys

RUN set -xe; \
    mkdir -p /target/etc; \
    mkdir -p /blank; \
    apk --no-cache add \
      ca-certificates \
      tzdata \
    ; \
    update-ca-certificates; \
    ln -sf /usr/share/zoneinfo/Etc/UTC /target/etc/localtime; \
    echo "Etc/UTC" > /target/etc/timezone;


FROM scratch

COPY --from=sys /target/etc /etc
COPY --from=sys /usr/share/zoneinfo/UTC /usr/share/zoneinfo/UTC
COPY --from=sys /usr/share/zoneinfo/Etc/UTC /usr/share/zoneinfo/Etc/UTC
COPY --from=sys /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=sys /blank /tmp

COPY --from=build /tyk/tyk /usr/bin/tyk
COPY --from=build /tyk/templates /tyk/templates

COPY ./rootfs/ /
