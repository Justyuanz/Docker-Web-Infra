# Docker Fundamentals — Short Note

## Core flow

```text
    Dockerfile
        ↓
    docker build
        ↓
    IMAGE
        ↓
    docker run
        ↓
    CONTAINER
```

## Docker
Docker is the tool that **builds, runs, and manages containers**.

In Inception:

```text
Debian VM
├── NGINX container
├── WordPress/PHP-FPM container
└── MariaDB container
```

## Container
A container is an **isolated running process/environment**.

It has its own filesystem and dependencies, but it shares the host Linux kernel.

## Image
An image is the **template used to create containers**.

```text
Image = prepared template
Container = running instance
```

One image can create multiple containers.

## Dockerfile
A Dockerfile is a text file containing **instructions for building an image**.

Example:

```Dockerfile
FROM debian:bookworm
RUN apt-get update
RUN apt-get install -y nginx
CMD ["nginx", "-g", "daemon off;"]
```

## `docker build`

```bash
docker build -t my-image .
```

Reads the Dockerfile and creates an **image**.

## `docker run`

```bash
docker run my-image
```

Creates and starts a **container** from the image.

## Image vs Container

| Image | Container |
|---|---|
| Template | Running instance |
| Created with `docker build` | Started with `docker run` |
| Not running by itself | Runs the service/process |
| Reusable | Specific instance |

## VM vs Container

### Virtual Machine
- Acts like a separate computer.
- Has its own guest OS and kernel.
- Heavier.

### Container
- Isolates an application/process.
- Shares the host's Linux kernel.
- Lighter and faster.

In Inception:

```text
School computer
    ↓
Debian VM
    ↓
Docker
    ↓
Containers
```

## `RUN` vs `CMD`

### `RUN`
Runs **while building the image**.

Example:

```Dockerfile
RUN apt-get install -y nginx
```

Think:

> `RUN` = prepare the image.

### `CMD`
Defines the **default command when the container starts**.

Example:

```Dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

Think:

> `CMD` = what runs at container runtime.

## The most important summary

```text
Dockerfile
    ↓ build
Image
    ↓ run
Container
```

And:

```text
RUN = build time
CMD = container runtime
```
