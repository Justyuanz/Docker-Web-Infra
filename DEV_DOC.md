# DEV_DOC.md

## Purpose

This document explains the developer setup and architecture of the Inception project.

The infrastructure is built with Docker Compose and contains three mandatory services:

```text
nginx
wordpress
mariadb
```

Each service has its own Dockerfile.

## Prerequisites

Required tools:

- Docker
- Docker Compose
- Make

On the final Linux evaluation machine, the persistent data directories should exist under:

```text
/home/jinzhang/data/
```

Expected directories:

```bash
mkdir -p /home/jinzhang/data/mariadb
mkdir -p /home/jinzhang/data/wordpress
```

The Makefile can create these directories automatically before starting the stack.

## Environment file

The project uses:

```text
srcs/.env
```

Example variables:

```env
LOGIN=jinzhang

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=your_database_password
MYSQL_ROOT_PASSWORD=your_root_password

DOMAIN_NAME=jinzhang.42.fr

WP_ADMIN_USER=boss42
WP_ADMIN_PASSWORD=your_admin_password
WP_ADMIN_EMAIL=admin_email@example.com

WP_USER=author1
WP_USER_PASSWORD=your_user_password
WP_USER_EMAIL=author1@example.com
```

`srcs/.env` must not be committed to Git.

Root `.gitignore` should contain:

```gitignore
srcs/.env
```

## Build and run

From the repository root:

```bash
make
```

Equivalent Compose command:

```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

## Stop

```bash
make down
```

## Full clean rebuild

```bash
make re
```

Warning: `make re` may remove Docker volumes depending on the Makefile implementation. Do not use it if you want to keep current data.

## Logs

```bash
make logs
```

Or:

```bash
docker compose -f srcs/docker-compose.yml logs
```

## Service architecture

### NGINX

NGINX is the only public service.

It listens on:

```text
443
```

It uses SSL/TLS and forwards PHP requests to WordPress/PHP-FPM:

```text
wordpress:9000
```

It should not expose port `80`.

### WordPress / PHP-FPM

WordPress runs as PHP files inside:

```text
/var/www/html
```

PHP-FPM listens internally on:

```text
0.0.0.0:9000
```

NGINX sends FastCGI requests to PHP-FPM.

The WordPress container does not contain NGINX.

WordPress is installed automatically using WP-CLI. The browser installation wizard should not appear.

### MariaDB

MariaDB stores the WordPress database.

The data directory is:

```text
/var/lib/mysql
```

MariaDB listens on:

```text
0.0.0.0:3306
```

This allows the WordPress container to connect through the Docker network.

## Docker network

All services are connected to a custom Docker bridge network:

```text
inception
```

Docker DNS allows services to reach each other by service name:

```text
nginx → wordpress:9000
wordpress → mariadb:3306
```

Do not use:

```yaml
network_mode: host
links:
```

Do not use:

```bash
--link
```

## Docker volumes

The project uses persistent volumes for MariaDB and WordPress.

MariaDB volume:

```text
mariadb → /var/lib/mysql
```

WordPress volume:

```text
wordpress → /var/www/html
```

For final evaluation, `docker volume inspect` should show paths containing:

```text
/home/jinzhang/data/mariadb
/home/jinzhang/data/wordpress
```

## Useful checks

Check containers:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Check HTTPS:

```bash
curl -k https://jinzhang.42.fr
```

Check HTTP fails:

```bash
curl http://jinzhang.42.fr
```

Check network:

```bash
docker network inspect inception
```

Check volumes:

```bash
docker volume inspect mariadb
docker volume inspect wordpress
```

Check WordPress installation:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress wp core is-installed --allow-root
```

Check WordPress users:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress wp user list --allow-root
```

Check MariaDB database:

```bash
docker compose -f srcs/docker-compose.yml exec mariadb mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
```

Inside MariaDB:

```sql
SHOW TABLES;
SELECT ID, user_login, user_email FROM wp_users;
exit
```

Check real main processes:

```bash
docker compose -f srcs/docker-compose.yml exec mariadb cat /proc/1/comm
docker compose -f srcs/docker-compose.yml exec wordpress cat /proc/1/comm
docker compose -f srcs/docker-compose.yml exec nginx cat /proc/1/comm
```

Expected idea:

```text
mariadbd
php-fpm8.2
nginx
```

## Forbidden patterns to check

Run from the repository root:

```bash
grep -R "network_mode: host\|network: host\|links:" srcs Makefile
```

```bash
grep -R -- "--link" srcs Makefile
```

```bash
grep -R -E "sleep infinity|tail -f /dev/null|tail -f /dev/random" srcs Makefile
```

Expected result: no output.

Containers should stay alive because their real services run in the foreground, not because of fake keep-alive commands.

## Configuration modification practice

During evaluation, the reviewer may ask for a configuration change, such as changing an exposed port.

Example practice change:

```yaml
ports:
  - "8443:443"
```

Then rebuild/restart:

```bash
make down
make
curl -k https://jinzhang.42.fr:8443
```

After testing, restore the expected final configuration:

```yaml
ports:
  - "443:443"
```
