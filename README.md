*This project has been created as part of the 42 curriculum by jinzhang.*

# Inception

## Description

Inception is a Docker Compose project that builds a small infrastructure made of three separate services:

- **NGINX**: the only public entrypoint, exposed on HTTPS port `443` with SSL/TLS.
- **WordPress + PHP-FPM**: the PHP application service, listening internally on port `9000`.
- **MariaDB**: the database service, listening internally on port `3306`.

The services communicate through a custom Docker network called `inception`.

The request flow is:

```text
Browser
  ↓ HTTPS :443
NGINX
  ↓ FastCGI
WordPress / PHP-FPM :9000
  ↓ SQL
MariaDB :3306
```

The WordPress service does not contain NGINX. The NGINX service does not contain WordPress or MariaDB. Each container has one main responsibility.

## Instructions

Before running the project, make sure the domain is mapped to localhost.

On Linux/macOS, add this line to `/etc/hosts`:

```text
127.0.0.1 jinzhang.42.fr
```

Start the project from the repository root:

```bash
make
```

Open the website:

```text
https://jinzhang.42.fr
```

The certificate is self-signed, so the browser may show a security warning. This is expected for this project.

HTTP is intentionally not available:

```text
http://jinzhang.42.fr
```

Only HTTPS port `443` should be exposed.

Stop the project:

```bash
make down
```

Clean containers and volumes:

```bash
make fclean
```

Rebuild from scratch:

```bash
make re
```

## Project structure

```text
inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   └── tools/
        │       └── init.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── php-fpm.conf
        │   └── tools/
        │       └── init.sh
        └── nginx/
            ├── Dockerfile
            └── conf/
                └── nginx.conf
```

## Resources

Resources used while studying and building the project:

- Docker documentation
- Docker Compose documentation
- Debian documentation
- MariaDB documentation
- NGINX documentation
- WordPress documentation
- WP-CLI documentation
- 42 Inception subject and evaluation sheet

## AI usage

AI was used as a study assistant to explain Docker, Docker Compose, Docker networks, Docker volumes, MariaDB initialization, PHP-FPM, NGINX, WordPress setup.

The project files were written, tested, debugged, and adapted by the student. AI explanations were used to understand the architecture, command behaviornand configuration files.
