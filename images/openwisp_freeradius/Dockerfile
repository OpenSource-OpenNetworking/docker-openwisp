# Multi-platform build arguments
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# Use Alpine Linux base for multi-platform support instead of freeradius image
FROM alpine:3.19

# Install FreeRADIUS and dependencies from Alpine repositories (supports multi-platform)
# hadolint ignore=DL3018
RUN apk add --no-cache --update \
    freeradius \
    freeradius-postgresql \
    freeradius-rest \
    freeradius-sql \
    tzdata \
    postgresql-client \
    && rm -rf /var/cache/apk/* /tmp/*

# Create FreeRADIUS user and group (Alpine creates these by default, but let's be explicit)
RUN addgroup -S freerad 2>/dev/null || true && \
    adduser -S freerad -G freerad 2>/dev/null || true

CMD ["sh", "init_command.sh"]
EXPOSE 1812/udp 1813/udp

# hadolint ignore=DL3045
COPY ./common/init_command.sh \
    ./common/utils.sh ./
COPY ./openwisp_freeradius/docker-entrypoint.sh ./
COPY ./openwisp_freeradius/raddb/ /etc/raddb/
RUN chown -R freerad:root /etc/raddb/ && \
    mkdir -p /var/log/radius && \
    chown -R freerad:root /var/log/radius

ENV TZ=UTC \
    MODULE_NAME=freeradius \
    DB_NAME=openwisp_db \
    DB_USER=admin \
    DB_PASS=admin \
    DB_HOST=postgres \
    DB_PORT=5432 \
    DB_SSLMODE=disable \
    DB_SSLKEY=None \
    DB_SSLCERT=None \
    DB_SSLROOTCERT=None \
    DB_OPTIONS={} \
    DASHBOARD_INTERNAL=dashboard.internal \
    API_INTERNAL=api.internal \
    DEBUG_MODE=False
