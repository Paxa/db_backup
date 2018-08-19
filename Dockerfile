FROM minio/mc:latest
#FROM alpine:3.7

MAINTAINER Pavel Evstigneev <pavel.evst@gmail.com>

# Influxdb is available only in edge/testing
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main"       > /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing"   >> /etc/apk/repositories && \
    cat /etc/apk/repositories

RUN apk upgrade --update-cache --available && \
    apk add curl openssh-client rsync lftp bash ruby ruby-bundler py-pip && \
    update-ca-certificates && \
    rm -rf /var/cache/apk/*

# Backblaze B2 cloud storage
RUN pip install 'b2>=1.3.4'
RUN b2 version

# google libs are too big
# RUN curl https://sdk.cloud.google.com | bash

# Database clients
# TODO: remove unnecessary files
RUN apk add postgresql-client mysql-client influxdb --no-cache

RUN mkdir -p /opt/app
WORKDIR /opt/app

ADD . /opt/app

RUN bundle install --retry 10 --system

ENTRYPOINT ["bin/db_backup"]
CMD "backup"
