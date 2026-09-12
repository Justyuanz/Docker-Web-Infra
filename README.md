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

## Project description and design choices

Docker builds and runs each service from the files under `srcs/requirements/`. Docker Compose describes how those images, containers, volumes, environment variables, and the private network work together. The Dockerfiles install each service, the `conf/` files configure it, and the `tools/` scripts perform first-start initialization.

### Virtual machines vs Docker

A virtual machine runs a complete guest operating system and its own kernel, which provides strong isolation but uses more resources. A Docker container shares the host's kernel and isolates a service as a process, so containers are smaller and start faster. This project uses Docker to separate NGINX, WordPress/PHP-FPM, and MariaDB into independent services.

### Secrets vs environment variables

Environment variables are convenient for non-secret configuration and for passing values into containers. Docker secrets expose confidential values as mounted files and are useful for larger or production deployments. This project keeps its local configuration in `srcs/.env`, which is ignored by Git, while `srcs/.env.example` documents the required keys without containing real credentials.

### Docker network vs host network

The custom `inception` bridge network gives the containers isolated service-to-service communication and DNS names such as `wordpress` and `mariadb`. Host networking would remove that isolation. Only NGINX publishes a host port.

### Docker volumes vs bind mounts

A normal Docker volume is stored in Docker's managed storage. A bind mount uses a specific host directory. This project declares named volumes with the local driver and bind options, combining Compose-managed volume names with a configurable host data location. `DATA_DIR` defaults to `${HOME}/data`.

## Instructions

Before running the project, make sure the domain is mapped to localhost.

Create the local environment file and replace every `change_me` value:

```bash
cd srcs
cp .env.example .env
chmod u=rw,go= .env
cd ..
```

Do not commit `srcs/.env`. Its default `DATA_DIR=${HOME}/data` stores persistent data below the current user's home directory.

Add this line to the host's `/etc/hosts` file:

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
    ├── .env.example
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
- 42 Inception project brief

## AI usage

AI was used as a study assistant to explain Docker, Docker Compose, Docker networks, Docker volumes, MariaDB initialization, PHP-FPM, NGINX, WordPress setup, and testing approaches.

The project files were written, tested, debugged, and adapted by the student. AI explanations were used to understand the architecture, command behavior, and configuration files.
