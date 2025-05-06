FROM debian:stable-slim

ARG BUILD_DATE="${BUILD_DATE:-2025-05-06}"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        default-mysql-client \
        awscli \
        s3cmd \
        ca-certificates \
        curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./scripts/backup.sh /scripts/backup.sh
COPY ./scripts/copy2aws.sh /scripts/copy2aws.sh
COPY ./scripts/notify.sh /scripts/notify.sh

RUN chmod +x /scripts/backup.sh

ENTRYPOINT ["/scripts/backup.sh"]
