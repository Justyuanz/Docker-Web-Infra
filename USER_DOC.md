# USER_DOC.md

## Purpose

This document explains how to use the Inception stack as an end user or administrator.

The stack contains:

- NGINX with HTTPS on port `443`
- WordPress running through PHP-FPM
- MariaDB as the WordPress database

## Start the stack

From the repository root:

```bash
make
```

This builds and starts all services with Docker Compose.

## Stop the stack

```bash
make down
```

## Restart the stack

```bash
make restart
```

## View service status

```bash
make ps
```

Or directly:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected services:

```text
mariadb
wordpress
nginx
```

All should be running.

## Access the website

Open:

```text
https://jinzhang.42.fr
```

A browser warning may appear because the TLS certificate is self-signed. This is expected.

Click the browser's advanced/proceed option to continue.

## HTTP access

This should fail:

```text
http://jinzhang.42.fr
```

The project exposes only HTTPS port `443`.

## WordPress administrator access

Open:

```text
https://jinzhang.42.fr/wp-admin
```

Use the WordPress administrator username and password from `srcs/.env`:

```env
WP_ADMIN_USER=...
WP_ADMIN_PASSWORD=...
```

The administrator username must not contain:

```text
admin
Admin
ADMIN
```

For example, `boss42` is acceptable. `admin`, `administrator`, `Admin-login`, or `admin-123` are not acceptable.

## Normal WordPress user

A normal non-administrator WordPress user is also created from `srcs/.env`:

```env
WP_USER=...
WP_USER_PASSWORD=...
WP_USER_EMAIL=...
```

This user is created with the WordPress role:

```text
author
```

The normal user email must be different from the administrator email.

## Basic user checks

Check that the website returns WordPress HTML:

```bash
curl -k https://jinzhang.42.fr
```

Check that HTTP does not work:

```bash
curl http://jinzhang.42.fr
```

Check WordPress users:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress wp user list --allow-root
```

Expected result:

```text
one administrator user
one normal author user
```

## Persistence check

To check persistence:

1. Log in to WordPress admin.
2. Edit a page or create a post/comment.
3. Restart the stack:

```bash
make restart
```

4. Open the website again.
5. Confirm the change is still present.

A stronger check:

```bash
make down
make
```

The WordPress site and database should still be configured.
