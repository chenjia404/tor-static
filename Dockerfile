# syntax=docker/dockerfile:1.7

ARG GO_VERSION=1.25

FROM --platform=$TARGETPLATFORM golang:${GO_VERSION}-bookworm AS toolchain

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace

# Install the autotools and native build chain required by Tor and its bundled C dependencies.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        autopoint \
        build-essential \
        ca-certificates \
        git \
        libtool \
        perl \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

FROM toolchain AS builder

ARG TARGETARCH

COPY . .

# Fail early with a clear message when the repository was not cloned with recursive submodules.
RUN test -f openssl/Configure \
    && test -f libevent/autogen.sh \
    && test -f tor/configure.ac \
    && test -f xz/configure.ac \
    && test -f zlib/configure \
    || (echo "Submodules are missing. Run: git submodule update --init --recursive" >&2 && exit 1)

RUN go run build.go -verbose build-all \
    && go run build.go package-libs \
    && go run build.go show-libs > /tmp/show-libs.txt \
    && cp libs.tar.gz /tmp/tor-static-linux-${TARGETARCH}.tar.gz \
    && cp libs.zip /tmp/tor-static-linux-${TARGETARCH}.zip

FROM scratch AS artifact

ARG TARGETARCH

COPY --from=builder /tmp/tor-static-linux-${TARGETARCH}.tar.gz /tor-static-linux-${TARGETARCH}.tar.gz
COPY --from=builder /tmp/tor-static-linux-${TARGETARCH}.zip /tor-static-linux-${TARGETARCH}.zip
COPY --from=builder /tmp/show-libs.txt /show-libs.txt
