FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tar \
        mariadb-client \
        php-fpm \
        php-cli \
        php-mysql \
        php-curl \
        php-gd \
        php-intl \
        php-mbstring \
        php-xml \
        php-zip && \
    rm -rf /var/lib/apt/lists/*