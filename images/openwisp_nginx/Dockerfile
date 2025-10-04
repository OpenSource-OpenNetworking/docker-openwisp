# Multi-platform build arguments
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

FROM nginx:1.29.0-alpine

# hadolint ignore=DL3018
RUN apk add --update --no-cache \
            py3-pip~=25.1.1-r0 \
            certbot~=4.0.0-r0 \
            certbot-nginx~=4.0.0-r1 \
            openssl \
            netcat-openbsd && \
    rm -rf /var/cache/apk/* /tmp/*

WORKDIR /etc/nginx/
EXPOSE 80 443

# DL3018
COPY ./common/services.py \
    ./common/init_command.sh \
    ./common/utils.sh \
    ./openwisp_nginx/ \
    /etc/nginx/

RUN pip install --break-system-packages --no-cache-dir -r requirements.txt

COPY ./openwisp_nginx/nginx.template.conf /etc/nginx/
COPY --chown=openwisp:openwisp ./openwisp_nginx/direct_entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV MODULE_NAME=nginx \
    PYTHONUNBUFFERED=1 \
    DOLLAR=$ \
    TZ=UTC \
    SSL_CERT_MODE=Yes \
    CERT_ADMIN_EMAIL=example@example.com \
    NGINX_HTTP2=http2 \
    NGINX_CLIENT_BODY_SIZE=30 \
    NGINX_ADMIN_ALLOW_NETWORK=all \
    NGINX_HTTPS_ALLOWED_IPS=all \
    NGINX_HTTP_ALLOW=False \
    NGINX_SERVER_NAME_HASH_BUCKET=32 \
    NGINX_SSL_CONFIG='' \
    NGINX_IP6_STRING='' \
    NGINX_IP6_80_STRING='' \
    NGINX_80_CONFIG='' \
    NGINX_GZIP_SWITCH=on \
    NGINX_GZIP_LEVEL=6 \
    NGINX_GZIP_PROXIED=any \
    NGINX_GZIP_MIN_LENGTH=1000 \
    NGINX_GZIP_TYPES='text/plain image/svg+xml application/json application/javascript text/xml text/css application/xml application/x-font-ttf font/opentype' \
    NGINX_CUSTOM_FILE=False \
    NINGX_REAL_REMOTE_ADDR='$real_ip' \
    # USWGI pass_port
    DASHBOARD_APP_PORT=8000 \
    API_APP_PORT=8001 \
    WEBSOCKET_APP_PORT=8002 \
    NETWORK_TOPOLOGY_APP_PORT=8003 \
    # Application Service Name
    DASHBOARD_APP_SERVICE=dashboard \
    API_APP_SERVICE=api \
    WEBSOCKET_APP_SERVICE=websocket \
    NETWORK_TOPOLOGY_APP_SERVICE=openwisp-network-topology \
    # Listen domains
    DASHBOARD_DOMAIN=dashboard.example.com \
    API_DOMAIN=api.example.com \
    # Inter container communication domains
    DASHBOARD_INTERNAL=dashboard.internal \
    API_INTERNAL=api.internal \
    NETWORK_TOPOLOGY_INTERNAL=network-topology.internal

# Run nginx
WORKDIR /etc/nginx/
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
