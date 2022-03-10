FROM docker:20.10.12@sha256:a729cce205a05b0b86dc8dca87823efaffc3f74979fe7dc86a707c2fbf631b61 as runtime
ADD entrypoint.sh /entrypoint.sh
ADD _Dockerfile /Dockerfile
ADD nginx.conf /nginx.conf
ADD .dockerignore /.dockerignore
RUN chmod 777 entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

RUN apk add --no-cache coreutils bats

FROM runtime
