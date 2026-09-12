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
cd srcs
cp .env.example .env
chmod u=rw,go= .env
# Edit .env and replace every change_me value.
cd ..
make
```

This builds and starts all services with Docker Compose.

Only perform the copy the first time. Do not overwrite an existing `srcs/.env` containing your credentials.

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
cd srcs
docker compose ps
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

## Managing credentials

Real credentials are stored only in the local `srcs/.env`, which is ignored by Git. `srcs/.env.example` contains the required variable names but no real credentials. Keep `srcs/.env` readable only by your user and never commit or share it.

The initialization scripts use these values when the volumes are first created. Editing `.env` later does not automatically change accounts already stored in WordPress or MariaDB; update those accounts explicitly or recreate the project data only when losing the existing content is acceptable.

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
cd srcs
docker compose exec wordpress wp user list --allow-root
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
