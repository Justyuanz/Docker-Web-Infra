FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx \
        openssl && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes \
    -out /etc/nginx/ssl/inception.crt \
    -keyout /etc/nginx/ssl/inception.key \
    -subj "/C=FI/ST=Uusimaa/L=Helsinki/O=42/OU=Inception/CN=jinzhang.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]