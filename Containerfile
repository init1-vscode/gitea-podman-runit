# syntax=docker/dockerfile:1

# Build frontend on the native platform to avoid QEMU-related issues with nodejs ecosystem
FROM --platform=$BUILDPLATFORM docker.io/library/golang:1.26-alpine3.24 AS frontend-build

RUN apk --no-cache add \
    build-base \
    git \
    nodejs \
    pnpm

WORKDIR /src

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

COPY --exclude=.git/ . .

RUN make frontend

# ----------------------------------------------------------------------

# Build backend for each target platform
FROM docker.io/library/golang:1.26-alpine3.24 AS build-env

ARG GITEA_VERSION
ARG TAGS=""
ENV TAGS="bindata timetzdata $TAGS"

ARG CGO_EXTRA_CFLAGS

RUN apk --no-cache add \
    build-base \
    git

WORKDIR ${GOPATH}/src/gitea.dev

COPY go.mod go.sum ./

RUN go mod download

COPY --exclude=.git/ . .

COPY --from=frontend-build /src/public/assets public/assets

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=bind,source=".git/",target=".git/" \
    make backend

COPY podman/root /tmp/local

RUN chmod 755 \
        /tmp/local/usr/bin/entrypoint \
        /tmp/local/usr/local/bin/* \
        /tmp/local/service/gitea/run \
        /tmp/local/service/openssh/run \
        /go/src/gitea.dev/gitea

# ----------------------------------------------------------------------

FROM docker.io/library/alpine:3.24 AS gitea

EXPOSE 22 3000

RUN apk --no-cache add \
    bash \
    ca-certificates \
    curl \
    gettext \
    git \
    linux-pam \
    openssh \
    runit \
    sqlite \
    su-exec \
    gnupg

RUN addgroup \
        -S \
        -g 1000 \
        git && \
    adduser \
        -S \
        -H \
        -D \
        -h /data/git \
        -s /bin/bash \
        -u 1000 \
        -G git \
        git && \
    echo "git:*" | chpasswd -e

COPY --from=build-env /tmp/local /
COPY --from=build-env /go/src/gitea.dev/gitea /app/gitea/gitea

RUN find /usr/bin /bin -type d -exec chmod 755 {} \;
RUN find /usr/bin /bin -type f -exec chmod 755 {} \;
RUN find /usr/lib /lib -type d -exec chmod 755 {} \;
RUN find /usr/lib /lib -type f -exec chmod 755 {} \;

ENV USER=git
ENV HOME=/data/git
ENV GITEA_CUSTOM=/data/gitea

VOLUME ["/data"]

# HINT: HEALTH-CHECK-ENDPOINT: don't use HEALTHCHECK

ENTRYPOINT ["/usr/bin/entrypoint"]

CMD ["/usr/sbin/runsvdir", "-P", "/run/service"]
