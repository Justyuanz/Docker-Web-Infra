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

RUN mkdir -p /usr/src/wordpress /var/www/html && \
    curl -fsSL https://wordpress.org/latest.tar.gz -o /tmp/wordpress.tar.gz && \
    tar -xzf /tmp/wordpress.tar.gz \
        -C /usr/src/wordpress \
        --strip-components=1 && \
    rm /tmp/wordpress.tar.gz

RUN curl -fsSL \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /usr/local/bin/wp && \
    chmod +x /usr/local/bin/wp

COPY conf/php-fpm.conf \
    /etc/php/8.2/fpm/pool.d/www.conf