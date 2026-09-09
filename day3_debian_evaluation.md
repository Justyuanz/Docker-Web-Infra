# Inception — Day 3 Guide
# WordPress + PHP-FPM + MariaDB Network
## Debian Bookworm version, consistent with your MariaDB

This file replaces the earlier Alpine-based Day 3 guide.

Your MariaDB currently uses:

```dockerfile
FROM debian:bookworm
```

So this WordPress guide also uses:

```dockerfile
FROM debian:bookworm
```

That keeps the project consistent:

```text
MariaDB   → Debian Bookworm
WordPress → Debian Bookworm
Later NGINX → Debian Bookworm too, unless you deliberately choose otherwise
```

This guide is also written in the same style as your MariaDB work:

```text
add a small piece
↓
understand it
↓
test it
↓
then continue
```

You should **not** paste one giant Dockerfile first.

---

# 0. What the evaluation sheet checks that Day 3 touches

The evaluation sheet checks more than "does the container run".

For WordPress/PHP-FPM, the relevant evaluation points are:

```text
WordPress service:
- has its own Dockerfile
- Dockerfile is not empty
- Dockerfile is written by you
- does not use a ready-made WordPress image
- does not contain NGINX
- container is created through docker compose
- WordPress is installed and configured
- you do NOT see the WordPress installation page
- admin username does not contain "admin" or "Admin"
- there is at least one usable normal WordPress user
- user can add a comment
- admin can edit a page
- changes persist through restart/reboot
- WordPress has a volume
- volume inspect path contains /home/<login>/data/
```

For Docker/general rules, Day 3 also touches:

```text
- all service files are inside srcs/
- Makefile at repository root eventually starts the stack
- docker-compose.yml has networks
- docker-compose.yml must NOT use network: host
- docker-compose.yml must NOT use links:
- scripts must NOT use --link
- Dockerfiles must NOT use tail -f as fake keep-alive
- scripts must NOT use sleep infinity
- services must run real foreground processes
- containers are built from allowed Alpine/Debian versions
- images must have same names as services
```

Important scope note:

```text
Day 3 can make WordPress/PHP-FPM work.
Day 3 cannot fully pass the browser part until NGINX exists.
```

The final browser path will be:

```text
https://<login>.42.fr
        ↓
NGINX on port 443 only
        ↓
wordpress:9000
        ↓
mariadb:3306
```

Today we build the middle part:

```text
wordpress:9000
        ↓
mariadb:3306
```

---

# 1. Today's final architecture

At the end of today, you want this:

```text
                  Docker network: inception

┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   wordpress container                 mariadb container      │
│                                                             │
│   /var/www/html                                             │
│   WordPress PHP files                                       │
│          │                                                  │
│          ▼                                                  │
│   PHP-FPM listening on 9000                                 │
│          │                                                  │
│          │ SQL/database connection                          │
│          ▼                                                  │
│   DB_HOST=mariadb  ────────────────► MariaDB listening 3306 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Later NGINX will be added in front:

```text
Browser
  │
  │ HTTPS :443
  ▼
NGINX
  │
  │ FastCGI
  ▼
wordpress:9000
  │
  │ SQL
  ▼
mariadb:3306
```

---

# 2. Five-hour plan

## Hour 1 — Understand the service

- [ ] What WordPress is
- [ ] What PHP is
- [ ] What PHP-FPM is
- [ ] What FastCGI is
- [ ] Why WordPress and NGINX are separate
- [ ] Why PHP-FPM must run in foreground

## Hour 2 — Build the WordPress image gradually

- [ ] Create WordPress directory
- [ ] Add `FROM debian:bookworm`
- [ ] Add package installation
- [ ] Test PHP, PHP-FPM, mysqli
- [ ] Download WordPress source
- [ ] Install WP-CLI

## Hour 3 — Configure PHP-FPM and WordPress init

- [ ] Create `conf/www.conf`
- [ ] Create `tools/init.sh`
- [ ] Copy WordPress into `/var/www/html`
- [ ] Wait for MariaDB
- [ ] Generate `wp-config.php`
- [ ] Install WordPress automatically
- [ ] Create admin and normal user
- [ ] Start PHP-FPM using `exec php-fpm8.2 -F`

## Hour 4 — Compose, network, volumes

- [ ] Add WordPress service to `docker-compose.yml`
- [ ] Add user-defined Docker network
- [ ] Connect MariaDB and WordPress to the same network
- [ ] Use service name `mariadb`, not IP
- [ ] Add WordPress volume path for evaluation compatibility

## Hour 5 — Test and evaluation drill

- [ ] Build with Compose
- [ ] Start containers
- [ ] Check logs
- [ ] Verify Docker network
- [ ] Verify PHP can reach MariaDB
- [ ] Verify WordPress is installed
- [ ] Verify users
- [ ] Verify PHP-FPM is PID 1 / real foreground service

---

# PART 1 — Understand before building

## 1.1 What is WordPress?

WordPress is not a web server.

WordPress is a PHP application.

It is made of files like:

```text
index.php
wp-login.php
wp-config.php
wp-admin/
wp-content/
wp-includes/
```

The important point:

```text
WordPress files are PHP code.
```

The browser does not execute PHP.

NGINX does not execute PHP.

PHP executes PHP.

So WordPress needs a PHP runtime.

In our project, that runtime is PHP-FPM.

---

## 1.2 What is PHP?

PHP is the language/runtime that executes WordPress code.

Example:

```php
<?php
echo "<h1>Hello</h1>";
```

PHP reads that and produces:

```html
<h1>Hello</h1>
```

The browser receives the final HTML.

The browser should not receive the PHP source code.

---

## 1.3 What is PHP-FPM?

FPM means:

```text
FastCGI Process Manager
```

PHP-FPM is a long-running PHP service.

It manages PHP worker processes.

Conceptually:

```text
php-fpm master process
        │
        ├── php worker
        ├── php worker
        └── php worker
```

Later NGINX will say:

```text
Please execute /var/www/html/index.php
```

PHP-FPM receives that request and a PHP worker executes the PHP file.

---

## 1.4 What is FastCGI?

FastCGI is the protocol between NGINX and PHP-FPM.

You have already seen other communication types:

```text
Browser → NGINX       HTTP / HTTPS
WordPress → MariaDB   database connection / SQL
Docker CLI → daemon   Docker API over socket
```

For PHP execution:

```text
NGINX → PHP-FPM       FastCGI
```

Final architecture:

```text
Browser
  ↓ HTTPS
NGINX
  ↓ FastCGI
PHP-FPM
  ↓ SQL/database connection
MariaDB
```

---

## 1.5 Why PHP-FPM listens on port 9000

PHP-FPM commonly listens on port:

```text
9000
```

Later NGINX will have something conceptually like:

```nginx
fastcgi_pass wordpress:9000;
```

Read this as:

```text
Send PHP execution requests
to the service named wordpress
on port 9000.
```

---

## 1.6 PHP-FPM is not HTTP

This is important.

Do not expect this to work:

```bash
curl http://wordpress:9000
```

Why?

Because PHP-FPM speaks FastCGI, not HTTP.

Your browser speaks HTTP/HTTPS.

So the browser needs NGINX in front.

Today, before NGINX exists, it is normal that you cannot properly browse the site yet.

---

## 1.7 Why the WordPress Dockerfile must contain no NGINX

The evaluation sheet explicitly checks that the WordPress Dockerfile has no NGINX.

The design is:

```text
NGINX container
    → web server, HTTPS/TLS, port 443

WordPress container
    → WordPress files + PHP-FPM

MariaDB container
    → database server
```

Bad design:

```text
WordPress container
    → WordPress + PHP-FPM + NGINX
```

Why bad?

Because then one container is doing multiple service responsibilities.

Evaluation answer:

> WordPress and NGINX are separate services. NGINX handles HTTPS and forwards PHP requests using FastCGI. The WordPress container only contains WordPress and PHP-FPM. It must not contain NGINX.

---

# PART 2 — Create the WordPress folder structure

From your repository root, you should already have:

```text
srcs/
└── requirements/
    └── mariadb/
        ├── Dockerfile
        └── tools/
            └── init.sh
```

Now create the WordPress service.

Run:

```bash
cd srcs/requirements
mkdir -p wordpress/conf wordpress/tools
touch wordpress/Dockerfile
touch wordpress/conf/www.conf
touch wordpress/tools/init.sh
```

Check:

```bash
find wordpress -maxdepth 3 -type f
```

Expected:

```text
wordpress/Dockerfile
wordpress/conf/www.conf
wordpress/tools/init.sh
```

## Explain

```bash
mkdir -p wordpress/conf wordpress/tools
```

`mkdir` means make directory.

`-p` means:

```text
create parent directories if needed
do not fail if they already exist
```

This is similar to your MariaDB script:

```sh
mkdir -p /run/mysqld
```

Same idea:

```text
make sure required directory exists
```

---

# PART 3 — Dockerfile, built step by step

Open:

```text
srcs/requirements/wordpress/Dockerfile
```

Do not paste the complete file yet.

---

## Step 3.1 — Add the base image

Write:

```dockerfile
FROM debian:bookworm
```

Stop here.

### Explain `FROM`

`FROM` chooses the starting filesystem for the image.

Before this line:

```text
there is no image filesystem yet
```

After this line:

```text
a minimal Debian Bookworm filesystem exists
```

It contains things like:

```text
/bin
/etc
/usr
/var
```

### Explain `debian`

`debian` is the base image name.

### Explain `bookworm`

`bookworm` is the Debian release tag.

You are deliberately not using:

```dockerfile
FROM debian:latest
```

because `latest` changes over time and is not acceptable for this project style.

### Evaluation connection

The evaluation checks that containers are built from an allowed Alpine/Debian version and not from ready-made service images.

This is good:

```dockerfile
FROM debian:bookworm
```

This is bad:

```dockerfile
FROM wordpress
```

because it is a ready-made WordPress service image.

---

## Step 3.2 — Test only the base image

From:

```text
srcs/requirements/wordpress
```

run:

```bash
docker build -t wordpress-test .
```

Explain:

```bash
docker build
```

means build an image.

```bash
-t wordpress-test
```

means tag/name the built image as `wordpress-test`.

```bash
.
```

means use the current directory as the build context.

If this works, your Dockerfile syntax is valid so far.

---

## Step 3.3 — Add package installation

Now add this under the `FROM` line:

```dockerfile
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
```

Stop.

Now understand it.

---

## Step 3.4 — Explain `RUN`

You wrote this in your MariaDB Dockerfile comments:

```text
RUN = do something while creating the image
```

Correct.

`RUN` happens during:

```text
docker build
```

It does not run every time the container starts.

Compare:

```text
Dockerfile RUN
    → image build time

tools/init.sh
    → container start time / runtime
```

This distinction is central to Inception.

---

## Step 3.5 — Explain `apt-get update`

```bash
apt-get update
```

downloads Debian's package list.

It does not install packages.

It only updates the list of available packages so that `apt-get install` knows what exists and where to download it from.

---

## Step 3.6 — Explain `&&`

```bash
apt-get update && apt-get install ...
```

`&&` means:

```text
run the command on the right only if the command on the left succeeded
```

So:

```text
apt-get update succeeds?
    yes → install packages
    no  → stop
```

This prevents continuing after a failed package update.

---

## Step 3.7 — Explain backslash `\`

```dockerfile
RUN apt-get update && \
    apt-get install ...
```

The backslash means:

```text
this same shell command continues on the next line
```

It is mainly for readability.

Without it, the line would end.

---

## Step 3.8 — Explain `apt-get install -y`

```bash
apt-get install
```

installs packages.

`-y` automatically answers yes to prompts.

During Docker build, there is no human to answer:

```text
Do you want to continue? [Y/n]
```

So we use `-y`.

---

## Step 3.9 — Explain `--no-install-recommends`

Debian packages can have:

```text
required dependencies
recommended optional packages
```

`--no-install-recommends` installs required packages but avoids pulling in many optional extras.

This keeps the image smaller and more intentional.

---

## Step 3.10 — Explain each installed package

### `ca-certificates`

Needed for HTTPS certificate verification.

We will download WordPress and WP-CLI over HTTPS.

### `curl`

Used to download files from URLs.

We use it for:

```text
WordPress source
WP-CLI
```

### `tar`

Used to extract `.tar.gz` archives.

WordPress is downloaded as a compressed archive.

### `mariadb-client`

This is not a database server.

It is only the client command that can connect to your MariaDB container.

Important difference:

```text
mariadb-server
    → runs the database service

mariadb-client
    → connects to a database service
```

Your WordPress container must not run MariaDB server.

It only needs to talk to the MariaDB container.

### `php-fpm`

Installs PHP-FPM.

On Debian Bookworm, this gives PHP-FPM 8.2.

The foreground executable will be:

```text
php-fpm8.2
```

### `php-cli`

Installs the command-line PHP executable:

```bash
php
```

WP-CLI needs this.

### `php-mysql`

This is critical.

It gives PHP the MySQL/MariaDB extensions, including `mysqli`.

Without this, WordPress cannot properly connect to MariaDB.

### `php-curl`

Allows PHP code to make HTTP requests.

WordPress often needs this.

### `php-gd`

Image handling.

Useful for uploads/thumbnails.

### `php-intl`

Internationalization functions.

### `php-mbstring`

Unicode/multibyte string handling.

Important for non-English text.

### `php-xml`

XML parsing.

WordPress and plugins often need it.

### `php-zip`

ZIP archive support.

Useful for plugin/theme installation and updates.

---

## Step 3.11 — Explain cleanup

```bash
rm -rf /var/lib/apt/lists/*
```

`apt-get update` downloads package list files into:

```text
/var/lib/apt/lists/
```

After packages are installed, those index files are not needed at runtime.

Removing them keeps the image cleaner.

---

## Step 3.12 — Why one big `RUN`?

We use:

```dockerfile
RUN apt-get update && \
    apt-get install ... && \
    rm -rf /var/lib/apt/lists/*
```

instead of three separate `RUN`s.

Reason:

Docker image layers.

If you did:

```dockerfile
RUN apt-get update
RUN apt-get install ...
RUN rm -rf /var/lib/apt/lists/*
```

the package lists may still exist in an earlier image layer.

Doing update/install/cleanup in one `RUN` is cleaner.

---

## Step 3.13 — Test installed packages

Build:

```bash
docker build -t wordpress-test .
```

Test PHP:

```bash
docker run --rm wordpress-test php --version
```

Expected concept:

```text
PHP 8.2.x
```

Test PHP-FPM:

```bash
docker run --rm wordpress-test php-fpm8.2 --version
```

Test PHP-FPM config syntax:

```bash
docker run --rm wordpress-test php-fpm8.2 -t
```

This may warn about missing pool config until we replace it later, but the command should exist.

Test mysqli:

```bash
docker run --rm wordpress-test php -m | grep mysqli
```

Expected:

```text
mysqli
```

Test MariaDB client:

```bash
docker run --rm wordpress-test mariadb --version
```

Remember:

```text
This is only the client.
The server is still the MariaDB container.
```

---

# PART 4 — Add WordPress source code to the image

## Step 4.1 — Understand two directories first

We will use two locations:

```text
/usr/src/wordpress
/var/www/html
```

### `/usr/src/wordpress`

This is the clean WordPress source copy stored inside the image.

Think:

```text
template copy
```

### `/var/www/html`

This is the live runtime WordPress directory.

Think:

```text
actual running website files
```

Later your WordPress volume should mount here.

---

## Step 4.2 — Why not only `/var/www/html`?

If later you mount a volume at:

```text
/var/www/html
```

and the volume is empty, it hides whatever was baked into that path in the image.

So if WordPress only existed there at build time, it could disappear behind the empty mounted volume.

Better design:

```text
image contains clean copy:
    /usr/src/wordpress

runtime volume path:
    /var/www/html

init.sh:
    if /var/www/html is empty
        copy from /usr/src/wordpress
```

This is the same idea as MariaDB initialization:

```text
if database files do not exist
    initialize database
else
    do not reinitialize
```

---

## Step 4.3 — Add WordPress download

Add this to the Dockerfile:

```dockerfile
RUN mkdir -p /usr/src/wordpress /var/www/html && \
    curl -fsSL https://wordpress.org/latest.tar.gz -o /tmp/wordpress.tar.gz && \
    tar -xzf /tmp/wordpress.tar.gz \
        -C /usr/src/wordpress \
        --strip-components=1 && \
    rm /tmp/wordpress.tar.gz
```

Stop and understand.

---

## Step 4.4 — Explain `mkdir -p`

```bash
mkdir -p /usr/src/wordpress /var/www/html
```

Creates both directories.

`-p` means:

```text
create if missing
do not fail if already exists
```

---

## Step 4.5 — Explain `curl -fsSL`

```bash
curl -fsSL https://wordpress.org/latest.tar.gz -o /tmp/wordpress.tar.gz
```

Breakdown:

```text
curl
    download data

-f
    fail on HTTP error

-s
    silent/quiet progress output

-S
    still show errors even in silent mode

-L
    follow redirects

-o /tmp/wordpress.tar.gz
    save output to this file
```

---

## Step 4.6 — Is `latest.tar.gz` the same problem as `debian:latest`?

Not exactly.

The evaluation rule is mainly about not using floating Docker base images like:

```dockerfile
FROM debian:latest
```

and not using ready-made service images like:

```dockerfile
FROM wordpress
```

Here:

```text
https://wordpress.org/latest.tar.gz
```

is a WordPress source download endpoint.

For stricter reproducibility, you can later pin a WordPress version.

For today, the important evaluation point is:

```text
You are obtaining/configuring WordPress yourself.
You are not using the ready-made wordpress Docker image.
```

---

## Step 4.7 — Explain `tar -xzf`

```bash
tar -xzf /tmp/wordpress.tar.gz
```

Flags:

```text
-x
    extract

-z
    decompress gzip

-f
    next argument is the archive file
```

---

## Step 4.8 — Explain `-C`

```bash
-C /usr/src/wordpress
```

means:

```text
extract into /usr/src/wordpress
```

---

## Step 4.9 — Explain `--strip-components=1`

The archive normally contains a top-level folder:

```text
wordpress/
    index.php
    wp-admin/
    wp-content/
    ...
```

Without `--strip-components=1`, extraction would create:

```text
/usr/src/wordpress/wordpress/index.php
```

But we want:

```text
/usr/src/wordpress/index.php
```

So:

```text
--strip-components=1
```

removes the first path component, the outer `wordpress/` folder.

---

## Step 4.10 — Explain removing the archive

```bash
rm /tmp/wordpress.tar.gz
```

After extraction, the compressed file is not needed.

The actual WordPress files are now in:

```text
/usr/src/wordpress
```

---

## Step 4.11 — Test WordPress source exists

Build:

```bash
docker build -t wordpress-test .
```

Run:

```bash
docker run --rm wordpress-test ls -la /usr/src/wordpress
```

Expected files:

```text
index.php
wp-admin
wp-content
wp-includes
wp-load.php
```

---

# PART 5 — Install WP-CLI

## Step 5.1 — Why WP-CLI exists in this project

The evaluation says you should not see the WordPress installation page.

Normal manual WordPress setup:

```text
open browser
choose language
enter site title
create admin account
click install
```

But in Inception, the container should configure WordPress automatically.

WP-CLI lets the script do:

```bash
wp config create
wp core install
wp user create
```

So:

```text
browser wizard
```

becomes:

```text
tools/init.sh
```

---

## Step 5.2 — Add WP-CLI download

Add to Dockerfile:

```dockerfile
RUN curl -fsSL \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /usr/local/bin/wp && \
    chmod +x /usr/local/bin/wp
```

Stop.

---

## Step 5.3 — Explain `/usr/local/bin/wp`

The file is saved as:

```text
/usr/local/bin/wp
```

`/usr/local/bin` is normally in the shell's `PATH`.

That means you can run:

```bash
wp
```

instead of typing the full path.

---

## Step 5.4 — Explain `chmod +x`

```bash
chmod +x /usr/local/bin/wp
```

`chmod` changes permissions.

`+x` adds executable permission.

Without this, the file may exist but not run as a command.

---

## Step 5.5 — Test WP-CLI

Build:

```bash
docker build -t wordpress-test .
```

Run:

```bash
docker run --rm wordpress-test wp --info
```

Expected:

```text
WP-CLI information
```

If you see:

```text
wp: command not found
```

then the WP-CLI install path or permission is wrong.

---

# PART 6 — Configure PHP-FPM step by step

Open:

```text
srcs/requirements/wordpress/conf/www.conf
```

We will write this gradually.

---

## Step 6.1 — Add the pool name

Write:

```ini
[www]
```

Explain:

PHP-FPM uses worker pools.

`[www]` is the name of this pool.

Conceptually:

```text
PHP-FPM
   └── pool "www"
          ├── worker
          └── worker
```

---

## Step 6.2 — Add user/group

Add:

```ini
user = www-data
group = www-data
```

Explain:

The PHP worker processes should not run website code as root.

On Debian, the common web service user/group is:

```text
www-data
```

So PHP workers run as:

```text
www-data
```

---

## Step 6.3 — Add listen address

Add:

```ini
listen = 0.0.0.0:9000
```

This is extremely important.

### Explain `9000`

PHP-FPM listens on TCP port 9000 for FastCGI requests.

Later:

```text
NGINX → wordpress:9000
```

### Explain `0.0.0.0`

It means listen on the container's network interfaces.

Do not use:

```ini
listen = 127.0.0.1:9000
```

Why?

Inside the WordPress container:

```text
127.0.0.1
=
the WordPress container itself
```

If PHP-FPM listens only on `127.0.0.1`, another container like NGINX cannot reach it over the Docker network.

Evaluation answer:

> PHP-FPM listens on `0.0.0.0:9000` so the NGINX container can reach it through the Docker network. If it listened only on `127.0.0.1`, it would only accept connections from inside the WordPress container.

---

## Step 6.4 — Add process manager settings

Add:

```ini
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

Explain:

`pm` means process manager.

`dynamic` means PHP-FPM can maintain a dynamic number of workers within these limits.

You do not need to tune performance deeply today.

Understand the concept:

```text
php-fpm master
    ├── worker
    ├── worker
    └── worker
```

---

## Step 6.5 — Add environment behavior

Add:

```ini
clear_env = no
```

This allows environment variables to be available to PHP-FPM workers.

Our init script writes database settings into `wp-config.php`, so WordPress does not depend only on environment variables after setup.

Still, this setting makes the environment behavior explicit and easier to debug.

---

## Step 6.6 — Add worker logs

Add:

```ini
catch_workers_output = yes
```

This helps worker output appear in logs.

Useful for debugging.

---

## Step 6.7 — Final `www.conf` reference

Your file should now be:

```ini
[www]

user = www-data
group = www-data

listen = 0.0.0.0:9000

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

clear_env = no
catch_workers_output = yes
```

---

# PART 7 — Copy PHP-FPM config into image

Return to:

```text
srcs/requirements/wordpress/Dockerfile
```

Add:

```dockerfile
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
```

Stop.

---

## Step 7.1 — Explain Dockerfile `COPY`

Syntax:

```dockerfile
COPY source destination
```

Here:

```text
source on your host:
conf/www.conf
```

is copied into the image at:

```text
/etc/php/8.2/fpm/pool.d/www.conf
```

After build, the image contains its own copy.

It is not reading from your host file live.

---

## Step 7.2 — Why `/etc/php/8.2/fpm/pool.d/`

Because Debian Bookworm's default PHP-FPM version is PHP 8.2.

PHP-FPM pool config lives under:

```text
/etc/php/8.2/fpm/pool.d/
```

---

## Step 7.3 — Test PHP-FPM config

Build:

```bash
docker build -t wordpress-test .
```

Run:

```bash
docker run --rm wordpress-test php-fpm8.2 -t
```

Expected concept:

```text
configuration file ... test is successful
```

If it fails, fix `www.conf` before continuing.

---

# PART 8 — Create `tools/init.sh` step by step

Open:

```text
srcs/requirements/wordpress/tools/init.sh
```

This is the runtime script.

It is like your MariaDB init script:

```text
container starts
↓
init script prepares state
↓
exec real service in foreground
```

For MariaDB:

```text
init.sh
↓
mariadb-install-db if needed
↓
create DB/user if needed
↓
exec mariadbd ...
```

For WordPress:

```text
init.sh
↓
copy WordPress files if needed
↓
wait for MariaDB
↓
create wp-config.php if needed
↓
install WordPress if needed
↓
create normal user if needed
↓
exec php-fpm8.2 -F
```

---

## Step 8.1 — Add shebang

Write:

```sh
#!/bin/sh
```

Explain:

This tells Linux to run the script using:

```text
/bin/sh
```

---

## Step 8.2 — Add strict mode

Add:

```sh
set -eu
```

Explain:

`-e`:

```text
stop if a command fails
```

`-u`:

```text
treat undefined variables as errors
```

This prevents half-broken initialization.

You already used this in MariaDB.

---

## Step 8.3 — Add WordPress path

Add:

```sh
WP_PATH="/var/www/html"
```

Explain:

This creates a shell variable.

Instead of typing:

```text
/var/www/html
```

everywhere, we use:

```sh
"$WP_PATH"
```

The quotes are a good habit because they prevent shell word-splitting problems.

---

## Step 8.4 — Add function for required environment variables

Add:

```sh
require_env()
{
    variable_name="$1"
    eval "variable_value=\${$variable_name:-}"

    if [ -z "$variable_value" ]; then
        echo "ERROR: required environment variable '$variable_name' is missing."
        exit 1
    fi
}
```

Stop.

### Explain function syntax

```sh
require_env()
{
    ...
}
```

defines a reusable shell function.

Later:

```sh
require_env WORDPRESS_DB_NAME
```

runs the function.

### Explain `$1`

Inside the function:

```sh
$1
```

means the first argument passed to the function.

So:

```sh
require_env WORDPRESS_DB_NAME
```

makes:

```sh
variable_name="$1"
```

become:

```text
variable_name="WORDPRESS_DB_NAME"
```

### Explain `eval`

We are passing the **name** of a variable and want the value of that variable.

For example:

```text
variable_name="WORDPRESS_DB_NAME"
```

We want to check the actual value of:

```sh
$WORDPRESS_DB_NAME
```

This line does that lookup:

```sh
eval "variable_value=\${$variable_name:-}"
```

### Explain `${...:-}`

This means:

```text
use the value if set
otherwise use empty string
```

This avoids `set -u` crashing before we can print our clear error.

### Explain `-z`

```sh
[ -z "$variable_value" ]
```

tests whether the string is empty.

If empty:

```sh
exit 1
```

stops the script.

This is fail-fast behavior.

---

## Step 8.5 — Require all environment variables

Add:

```sh
for variable in \
    WORDPRESS_DB_HOST \
    WORDPRESS_DB_NAME \
    WORDPRESS_DB_USER \
    WORDPRESS_DB_PASSWORD \
    DOMAIN_NAME \
    WP_ADMIN_USER \
    WP_ADMIN_PASSWORD \
    WP_ADMIN_EMAIL \
    WP_USER \
    WP_USER_PASSWORD \
    WP_USER_EMAIL

do
    require_env "$variable"
done
```

Explain:

The `for` loop checks each variable name one by one.

If any required variable is missing, the script exits before doing dangerous or confusing partial setup.

---

## Step 8.6 — Reject invalid admin username

Add:

```sh
admin_lowercase="$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')"

case "$admin_lowercase" in
    *admin*)
        echo "ERROR: WP_ADMIN_USER must not contain 'admin'."
        exit 1
        ;;
esac
```

Stop.

### Evaluation reason

The evaluation checks that the administrator username does not include:

```text
admin
Admin
```

So these should be rejected:

```text
admin
administrator
Admin-login
admin-123
myadmin
```

Good examples:

```text
siteowner
boss42
yuanowner
wpboss
```

### Explain `$(...)`

```sh
admin_lowercase="$(...)"
```

runs a command and stores its output.

### Explain `tr`

```sh
tr '[:upper:]' '[:lower:]'
```

converts uppercase letters to lowercase.

So:

```text
AdminBoss
```

becomes:

```text
adminboss
```

before checking.

### Explain `case`

```sh
case "$admin_lowercase" in
    *admin*)
```

checks the variable against patterns.

### Explain `*admin*`

`*` is a wildcard.

```text
*admin*
```

means:

```text
anything before + admin + anything after
```

So any username containing admin fails.

---

# PART 9 — Copy WordPress files at runtime

Add:

```sh
if [ ! -f "$WP_PATH/wp-load.php" ]; then
    echo "WordPress files not found. Copying files..."
    cp -a /usr/src/wordpress/. "$WP_PATH/"
fi
```

---

## Step 9.1 — Explain the condition

```sh
[ ! -f "$WP_PATH/wp-load.php" ]
```

`-f` checks if a regular file exists.

`!` means not.

So this means:

```text
if wp-load.php does NOT exist
```

Why `wp-load.php`?

Because it is a core WordPress file.

If it exists, `/var/www/html` probably already contains WordPress.

---

## Step 9.2 — Why not check only the directory?

This would not be enough:

```sh
[ ! -d "$WP_PATH" ]
```

because `/var/www/html` can exist but be empty.

A mounted volume path may exist but contain no WordPress files.

Checking a WordPress core file is more meaningful.

---

## Step 9.3 — Explain `cp -a`

```sh
cp -a /usr/src/wordpress/. "$WP_PATH/"
```

`cp` copies files.

`-a` means archive mode: copy recursively and preserve useful file attributes.

The source:

```text
/usr/src/wordpress/.
```

means copy the **contents** of the directory.

So you get:

```text
/var/www/html/index.php
```

not:

```text
/var/www/html/wordpress/index.php
```

---

## Step 9.4 — Evaluation/persistence reason

This supports future volume behavior.

First run with empty volume:

```text
/var/www/html is empty
↓
copy WordPress
```

Restart later:

```text
/var/www/html already has WordPress
↓
do not overwrite
```

This is idempotent.

---

# PART 10 — Wait for MariaDB

Add:

```sh
echo "Waiting for MariaDB at $WORDPRESS_DB_HOST..."

attempt=1
```

Then add:

```sh
while [ "$attempt" -le 30 ]
do
    if mariadb \
        --protocol=TCP \
        -h "$WORDPRESS_DB_HOST" \
        -u "$WORDPRESS_DB_USER" \
        "-p$WORDPRESS_DB_PASSWORD" \
        "$WORDPRESS_DB_NAME" \
        -e "SELECT 1;" \
        >/dev/null 2>&1
    then
        echo "MariaDB is ready."
        break
    fi

    echo "MariaDB not ready yet: attempt $attempt/30"
    attempt=$((attempt + 1))
    sleep 2
done
```

Then add:

```sh
if [ "$attempt" -gt 30 ]; then
    echo "ERROR: MariaDB did not become ready."
    exit 1
fi
```

---

## Step 10.1 — Why wait?

Compose can start containers in order, but:

```text
MariaDB container started
```

does not necessarily mean:

```text
MariaDB is ready to accept SQL queries
```

So WordPress must actually test the DB.

---

## Step 10.2 — Explain `while`

```sh
while [ "$attempt" -le 30 ]
```

means:

```text
while attempt number is less than or equal to 30
```

So the loop is bounded.

It does not run forever.

---

## Step 10.3 — Explain the MariaDB client command

```sh
mariadb
```

This is the client installed in the WordPress container.

It connects to the server in the MariaDB container.

### `--protocol=TCP`

Forces TCP network connection.

This makes sure we are testing container-to-container networking, not a local Unix socket.

### `-h "$WORDPRESS_DB_HOST"`

Host.

This should eventually be:

```text
mariadb
```

### `-u "$WORDPRESS_DB_USER"`

Database username.

Example:

```text
wpuser
```

### `"-p$WORDPRESS_DB_PASSWORD"`

Database password.

Important:

```text
-pPASSWORD
```

has no space.

### `"$WORDPRESS_DB_NAME"`

Database name.

Example:

```text
wordpress
```

### `-e "SELECT 1;"`

Run this SQL and exit.

`SELECT 1;` is harmless.

It proves:

```text
DNS works
network works
MariaDB is listening
user/password work
database exists
query works
```

---

## Step 10.4 — Explain `/dev/null 2>&1`

```sh
>/dev/null 2>&1
```

means:

```text
discard normal output
and discard error output
```

Why?

During retry, MariaDB may not be ready yet.

We do not want 30 noisy error messages.

We only care whether the command succeeds.

---

## Step 10.5 — Why `sleep 2` is allowed

Forbidden fake keep-alive:

```sh
sleep infinity
```

Allowed readiness wait:

```sh
sleep 2
```

Why?

This `sleep 2` is temporary and bounded.

It is only between DB connection attempts.

The container is eventually kept alive by:

```text
php-fpm8.2 -F
```

not by sleep.

---

# PART 11 — MariaDB side check before WordPress can work

Yesterday you created:

```text
wpuser@%
```

That is good.

It means the DB user is not limited to only local connections.

But MariaDB also has to listen on a network address reachable by WordPress.

If MariaDB listens only on:

```text
127.0.0.1:3306
```

then only processes inside the MariaDB container can connect.

For inter-container traffic, MariaDB should listen on:

```text
0.0.0.0:3306
```

or otherwise the container network interface.

## Check this before changing it

When MariaDB is running:

```bash
docker exec mariadb ss -lntp
```

If `ss` is not installed:

```bash
docker exec mariadb mariadbd --verbose --help 2>/dev/null | grep -A1 bind-address
```

If you discover it is bound only to localhost, your MariaDB final `exec` may need:

```sh
exec mariadbd --user=mysql --bind-address=0.0.0.0
```

Do not randomly change it before checking.

---

# PART 12 — Create `wp-config.php`

Add:

```sh
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "Creating wp-config.php..."

    wp config create \
        --allow-root \
        --path="$WP_PATH" \
        --dbname="$WORDPRESS_DB_NAME" \
        --dbuser="$WORDPRESS_DB_USER" \
        --dbpass="$WORDPRESS_DB_PASSWORD" \
        --dbhost="$WORDPRESS_DB_HOST"
fi
```

---

## Step 12.1 — What is `wp-config.php`?

It is WordPress's main configuration file.

It contains the database connection settings:

```text
database name
database username
database password
database host
```

Without it, WordPress does not know how to connect to MariaDB.

---

## Step 12.2 — Why generate it at runtime?

Do not bake real secrets into the Docker image.

Bad:

```dockerfile
RUN echo "DB_PASSWORD=secret" ...
```

Better:

```text
.env / secrets
    ↓
docker compose environment
    ↓
container runtime
    ↓
init.sh creates wp-config.php
```

This matches the evaluation concern that credentials must not be exposed in the Git repository outside allowed env/secrets files.

---

## Step 12.3 — Explain `wp config create`

`wp` is WP-CLI.

`config create` creates `wp-config.php`.

Options:

```text
--path
    where WordPress files live

--dbname
    database name

--dbuser
    database user

--dbpass
    database password

--dbhost
    database host
```

---

## Step 12.4 — Why DB host is `mariadb`, not `localhost`

Inside WordPress container:

```text
localhost
=
WordPress container itself
```

MariaDB is in another container.

So:

```text
localhost ❌
mariadb   ✅
```

The name `mariadb` works because both services are on the same Docker network and Docker DNS resolves service names.

---

## Step 12.5 — Explain `--allow-root`

The init script starts as root.

WP-CLI normally warns about running as root.

In this controlled container initialization, we explicitly allow it:

```text
--allow-root
```

Then PHP-FPM workers themselves run as:

```text
www-data
```

---

# PART 13 — Install WordPress automatically

Add:

```sh
if ! wp core is-installed \
    --allow-root \
    --path="$WP_PATH" \
    >/dev/null 2>&1

then
    echo "Installing WordPress..."

    wp core install \
        --allow-root \
        --path="$WP_PATH" \
        --url="https://$DOMAIN_NAME" \
        --title="Inception" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email
fi
```

---

## Step 13.1 — Why this matters for evaluation

The evaluation checks that when the site is opened, you do **not** see the WordPress installation page.

This command is how you avoid the browser wizard.

The container installs WordPress automatically.

---

## Step 13.2 — Explain `wp core is-installed`

This checks whether the WordPress database tables/site installation already exist.

If WordPress is already installed:

```text
skip
```

If not installed:

```text
install
```

---

## Step 13.3 — Explain `if ! command`

```sh
if ! wp core is-installed ...
```

means:

```text
if WordPress is NOT installed
```

The `!` negates the command result.

---

## Step 13.4 — Explain `wp core install`

This performs the installation normally done in the browser.

Options:

```text
--url
    the site URL, for example https://<login>.42.fr

--title
    site title

--admin_user
    first administrator username

--admin_password
    administrator password

--admin_email
    administrator email

--skip-email
    do not try to send installation email
```

---

# PART 14 — Create normal WordPress user

Add:

```sh
if ! wp user get "$WP_USER" \
    --allow-root \
    --path="$WP_PATH" \
    >/dev/null 2>&1

then
    echo "Creating normal WordPress user..."

    wp user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --allow-root \
        --path="$WP_PATH" \
        --role=author \
        --user_pass="$WP_USER_PASSWORD"
fi
```

---

## Step 14.1 — Why a normal user?

The evaluation asks you to use an available WordPress user to add a comment.

It also checks the administrator dashboard separately.

So you want at least:

```text
one administrator
one normal user
```

---

## Step 14.2 — Why check first?

If you blindly create the user every restart, the second run may fail or duplicate logic.

Instead:

```text
user exists?
    yes → skip
    no  → create
```

Idempotence again.

---

## Step 14.3 — Why role `author`?

`author` is a non-admin WordPress role.

That is enough to demonstrate a normal user separate from the administrator.

---

# PART 15 — File ownership

Add:

```sh
chown -R www-data:www-data "$WP_PATH"
```

Explain:

`chown` changes ownership.

`-R` means recursively.

```text
www-data:www-data
```

means:

```text
user www-data
group www-data
```

Why?

PHP-FPM workers run as `www-data`.

WordPress may need to write to places such as:

```text
wp-content/
uploads/
plugins/
themes/
```

---

# PART 16 — Start PHP-FPM as the real foreground process

Add the final line:

```sh
exec php-fpm8.2 -F
```

This is one of the most important lines in the entire service.

---

## Step 16.1 — Explain `php-fpm8.2`

This starts PHP-FPM.

---

## Step 16.2 — Explain `-F`

`-F` means foreground.

Docker containers should run the real service in the foreground.

---

## Step 16.3 — Explain `exec`

Without `exec`:

```text
PID 1
init.sh shell
    └── php-fpm child
```

With `exec`:

```text
PID 1
php-fpm8.2
```

`exec` replaces the shell with PHP-FPM.

This makes PHP-FPM the main process of the container.

---

## Step 16.4 — Evaluation reason

The evaluation checks that you are not using fake keep-alive commands such as:

```text
tail -f
sleep infinity
background process + bash
```

Your container stays alive because:

```text
PHP-FPM is alive
```

not because of:

```text
tail
sleep
bash
```

Correct answer:

> The entrypoint finishes with `exec php-fpm8.2 -F`, so PHP-FPM runs in the foreground as the main container process.

---

# PART 17 — Review complete `tools/init.sh`

Only now compare your file with the complete reference.

```sh
#!/bin/sh

set -eu

WP_PATH="/var/www/html"

require_env()
{
    variable_name="$1"
    eval "variable_value=\${$variable_name:-}"

    if [ -z "$variable_value" ]; then
        echo "ERROR: required environment variable '$variable_name' is missing."
        exit 1
    fi
}

for variable in \
    WORDPRESS_DB_HOST \
    WORDPRESS_DB_NAME \
    WORDPRESS_DB_USER \
    WORDPRESS_DB_PASSWORD \
    DOMAIN_NAME \
    WP_ADMIN_USER \
    WP_ADMIN_PASSWORD \
    WP_ADMIN_EMAIL \
    WP_USER \
    WP_USER_PASSWORD \
    WP_USER_EMAIL

do
    require_env "$variable"
done

admin_lowercase="$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')"

case "$admin_lowercase" in
    *admin*)
        echo "ERROR: WP_ADMIN_USER must not contain 'admin'."
        exit 1
        ;;
esac

if [ ! -f "$WP_PATH/wp-load.php" ]; then
    echo "WordPress files not found. Copying files..."
    cp -a /usr/src/wordpress/. "$WP_PATH/"
fi

echo "Waiting for MariaDB at $WORDPRESS_DB_HOST..."

attempt=1

while [ "$attempt" -le 30 ]
do
    if mariadb \
        --protocol=TCP \
        -h "$WORDPRESS_DB_HOST" \
        -u "$WORDPRESS_DB_USER" \
        "-p$WORDPRESS_DB_PASSWORD" \
        "$WORDPRESS_DB_NAME" \
        -e "SELECT 1;" \
        >/dev/null 2>&1
    then
        echo "MariaDB is ready."
        break
    fi

    echo "MariaDB not ready yet: attempt $attempt/30"
    attempt=$((attempt + 1))
    sleep 2
done

if [ "$attempt" -gt 30 ]; then
    echo "ERROR: MariaDB did not become ready."
    exit 1
fi

if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "Creating wp-config.php..."

    wp config create \
        --allow-root \
        --path="$WP_PATH" \
        --dbname="$WORDPRESS_DB_NAME" \
        --dbuser="$WORDPRESS_DB_USER" \
        --dbpass="$WORDPRESS_DB_PASSWORD" \
        --dbhost="$WORDPRESS_DB_HOST"
fi

if ! wp core is-installed \
    --allow-root \
    --path="$WP_PATH" \
    >/dev/null 2>&1

then
    echo "Installing WordPress..."

    wp core install \
        --allow-root \
        --path="$WP_PATH" \
        --url="https://$DOMAIN_NAME" \
        --title="Inception" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email
fi

if ! wp user get "$WP_USER" \
    --allow-root \
    --path="$WP_PATH" \
    >/dev/null 2>&1

then
    echo "Creating normal WordPress user..."

    wp user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --allow-root \
        --path="$WP_PATH" \
        --role=author \
        --user_pass="$WP_USER_PASSWORD"
fi

chown -R www-data:www-data "$WP_PATH"

echo "Starting PHP-FPM..."

exec php-fpm8.2 -F
```

Then make the host copy executable:

```bash
chmod +x srcs/requirements/wordpress/tools/init.sh
```

---

# PART 18 — Finish Dockerfile gradually

Return to:

```text
srcs/requirements/wordpress/Dockerfile
```

---

## Step 18.1 — Copy init script

Add:

```dockerfile
COPY tools/init.sh /usr/local/bin/init.sh
```

Explain:

This copies your runtime script from your project into the image.

Host file:

```text
tools/init.sh
```

Image file:

```text
/usr/local/bin/init.sh
```

---

## Step 18.2 — Make init executable

Add:

```dockerfile
RUN chmod +x /usr/local/bin/init.sh
```

Explain:

Docker will execute this file when the container starts.

It needs executable permission.

---

## Step 18.3 — Set working directory

Add:

```dockerfile
WORKDIR /var/www/html
```

Explain:

`WORKDIR` sets the default current directory inside the container.

It is similar to:

```bash
cd /var/www/html
```

This is useful because WordPress commands usually operate from the WordPress root.

---

## Step 18.4 — Document port 9000

Add:

```dockerfile
EXPOSE 9000
```

Explain carefully:

`EXPOSE` does **not** publish a port to your Mac/VM host.

It is metadata saying:

```text
this container is intended to listen on port 9000
```

Publishing would be done with Compose `ports:`.

For WordPress/PHP-FPM, we do not publish 9000 to the host.

NGINX will reach it internally.

---

## Step 18.5 — Set entrypoint

Add:

```dockerfile
ENTRYPOINT ["/usr/local/bin/init.sh"]
```

Explain:

When the WordPress container starts, Docker runs this script first.

Flow:

```text
container starts
↓
/usr/local/bin/init.sh
↓
prepare WordPress
↓
wait for MariaDB
↓
install/configure WordPress
↓
exec php-fpm8.2 -F
```

This mirrors your MariaDB design.

---

# PART 19 — Complete Dockerfile reference

Only now your Dockerfile should look like this:

```dockerfile
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

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/init.sh"]
```

Evaluation check:

```text
FROM debian:bookworm       ✅
own Dockerfile             ✅
not FROM wordpress         ✅
no NGINX                   ✅
no tail -f                 ✅
no sleep infinity          ✅
real foreground process    ✅ through init.sh ending in exec php-fpm8.2 -F
```

---

# PART 20 — Test image before Compose

From:

```text
srcs/requirements/wordpress
```

run:

```bash
docker build -t wordpress-test .
```

Then test:

```bash
docker run --rm wordpress-test php --version
```

```bash
docker run --rm wordpress-test php-fpm8.2 -t
```

```bash
docker run --rm wordpress-test php -m | grep mysqli
```

```bash
docker run --rm wordpress-test ls /usr/src/wordpress
```

```bash
docker run --rm wordpress-test wp --info
```

Do not simply run:

```bash
docker run wordpress-test
```

because the final entrypoint expects:

```text
environment variables
MariaDB
network
```

Those come from Compose.

---

# PART 21 — Docker network understanding

Now networking finally has a reason.

WordPress needs to connect to MariaDB.

Bad idea:

```text
WordPress connects to 172.20.0.2
```

Why bad?

Container IPs can change.

Good idea:

```text
WordPress connects to mariadb
```

Why good?

Docker's internal DNS resolves service/container names on the same user-defined network.

Conceptually:

```text
WordPress asks Docker DNS:
"Where is mariadb?"

Docker DNS answers:
"mariadb is currently at this container IP."
```

You do not hard-code the IP.

Evaluation answer:

> A Docker network lets containers communicate privately. On a user-defined network, Docker DNS lets services find each other by name. WordPress uses `mariadb` as the database host instead of a hard-coded IP because container IPs can change.

---

# PART 22 — `.env` and credentials

The evaluation allows `.env` or secrets, but real credentials must not be exposed in the Git repository outside allowed secret/env files.

Create:

```text
srcs/.env
```

Add `.env` to root `.gitignore`:

```gitignore
srcs/.env
```

If `srcs/.env` was already committed, remove it from Git tracking:

```bash
git rm --cached srcs/.env
```

Then change any passwords that were exposed.

---

## Step 22.1 — Example `.env`

Use your real values, not these placeholders:

```env
LOGIN=your42login

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=replace_with_real_password
MYSQL_ROOT_PASSWORD=replace_with_real_root_password

DOMAIN_NAME=your42login.42.fr

WP_ADMIN_USER=siteowner
WP_ADMIN_PASSWORD=replace_with_real_admin_password
WP_ADMIN_EMAIL=owner@example.com

WP_USER=author1
WP_USER_PASSWORD=replace_with_real_user_password
WP_USER_EMAIL=author1@example.com
```

Important:

```text
WP_ADMIN_USER must not contain admin/Admin
```

---

# PART 23 — Compose step by step

Open:

```text
srcs/docker-compose.yml
```

We build it gradually.

---

## Step 23.1 — Start with services

Add:

```yaml
services:
```

Compose organizes containers under services.

Today:

```text
mariadb
wordpress
```

Later:

```text
nginx
```

---

## Step 23.2 — MariaDB service

Add:

```yaml
  mariadb:
    build:
      context: ./requirements/mariadb
    image: mariadb
    container_name: mariadb
```

Explain:

### `mariadb:`

This is the Compose service name.

It is also the DNS name WordPress will use.

### `build.context`

Compose builds the MariaDB image from:

```text
srcs/requirements/mariadb
```

### `image: mariadb`

The evaluation checks that images have the same name as their service.

So:

```text
service name = mariadb
image name   = mariadb
```

### `container_name: mariadb`

The actual container name will be `mariadb`.

---

## Step 23.3 — MariaDB environment

Use the variable names your current MariaDB `init.sh` expects.

If your MariaDB script expects `MYSQL_*`, add:

```yaml
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
```

If your script expects different variable names, map them accordingly.

Important:

```text
MariaDB must receive the same DB name/user/password
that WordPress will use.
```

---

## Step 23.4 — MariaDB volume

Evaluation checks MariaDB volume path under:

```text
/home/<login>/data/
```

Add:

```yaml
    volumes:
      - mariadb:/var/lib/mysql
```

Explain:

Inside MariaDB container:

```text
/var/lib/mysql
```

is the database data directory.

This must persist.

The named volume `mariadb` will be defined later.

---

## Step 23.5 — MariaDB network

Add:

```yaml
    networks:
      - inception
```

This connects MariaDB to the shared project network.

---

## Step 23.6 — MariaDB restart

Add:

```yaml
    restart: unless-stopped
```

This restart policy does not replace correct foreground processes.

The container still needs real `mariadbd` running in foreground.

---

## Step 23.7 — WordPress service

Add:

```yaml
  wordpress:
    build:
      context: ./requirements/wordpress
    image: wordpress
    container_name: wordpress
```

Evaluation connection:

```text
service name = wordpress
image name   = wordpress
```

Good.

---

## Step 23.8 — WordPress environment

Add:

```yaml
    environment:
      WORDPRESS_DB_HOST: mariadb
      WORDPRESS_DB_NAME: ${MYSQL_DATABASE}
      WORDPRESS_DB_USER: ${MYSQL_USER}
      WORDPRESS_DB_PASSWORD: ${MYSQL_PASSWORD}

      DOMAIN_NAME: ${DOMAIN_NAME}

      WP_ADMIN_USER: ${WP_ADMIN_USER}
      WP_ADMIN_PASSWORD: ${WP_ADMIN_PASSWORD}
      WP_ADMIN_EMAIL: ${WP_ADMIN_EMAIL}

      WP_USER: ${WP_USER}
      WP_USER_PASSWORD: ${WP_USER_PASSWORD}
      WP_USER_EMAIL: ${WP_USER_EMAIL}
```

Important chain:

```text
.env
MYSQL_DATABASE=wordpress
        ↓
Compose
        ↓
WordPress container env
WORDPRESS_DB_NAME=wordpress
        ↓
init.sh
        ↓
wp config create
        ↓
wp-config.php
```

---

## Step 23.9 — Explain `WORDPRESS_DB_HOST: mariadb`

This is the key network connection.

`mariadb` is not a hard-coded IP.

It is the service name.

Docker DNS resolves it inside the shared Docker network.

Do not use:

```yaml
WORDPRESS_DB_HOST: localhost
```

Why?

Inside WordPress container:

```text
localhost = WordPress container itself
```

MariaDB is another container.

---

## Step 23.10 — WordPress volume

Evaluation checks WordPress has a volume and that volume inspect output contains:

```text
/home/<login>/data/
```

Add:

```yaml
    volumes:
      - wordpress:/var/www/html
```

Inside WordPress container:

```text
/var/www/html
```

is the live WordPress filesystem.

This is where:

```text
wp-config.php
wp-content/
uploads/
themes/
plugins/
```

live.

This must persist.

---

## Step 23.11 — `depends_on`

Add:

```yaml
    depends_on:
      - mariadb
```

Explain carefully:

`depends_on` helps Compose start MariaDB before WordPress.

But it does not guarantee MariaDB is ready for SQL queries.

That is why `init.sh` still waits using:

```sql
SELECT 1;
```

Difference:

```text
depends_on
    → startup order

SELECT 1 retry loop
    → real database readiness
```

---

## Step 23.12 — WordPress network

Add:

```yaml
    networks:
      - inception
```

Now both services share:

```text
inception
```

---

## Step 23.13 — WordPress restart

Add:

```yaml
    restart: unless-stopped
```

Again:

```text
restart policy
```

does not replace:

```text
real foreground process
```

---

## Step 23.14 — Define network

At the bottom:

```yaml
networks:
  inception:
    name: inception
    driver: bridge
```

Explain:

This creates a user-defined Docker bridge network named:

```text
inception
```

Evaluation checks that Docker network is used.

It also checks that you do not use:

```yaml
network: host
links:
```

So do not use those.

---

## Step 23.15 — Define volumes

At the bottom, after networks:

```yaml
volumes:
  mariadb:
    name: mariadb
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${LOGIN}/data/mariadb

  wordpress:
    name: wordpress
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${LOGIN}/data/wordpress
```

Explain:

These are named volumes backed by host directories.

Evaluation wants volume inspect output to contain:

```text
/home/<login>/data/
```

So the device paths are:

```text
/home/${LOGIN}/data/mariadb
/home/${LOGIN}/data/wordpress
```

Your `.env` must contain:

```env
LOGIN=your42login
```

Important:

The host directories must exist before Compose starts.

You can create them manually today:

```bash
mkdir -p /home/$USER/data/mariadb
mkdir -p /home/$USER/data/wordpress
```

For final Makefile, you should automate this.

On your Mac, `/home/$USER/...` may not exist in the same way. The evaluation target is your Linux VM/school machine.

---

# PART 24 — Complete Compose reference

Only now compare your Compose file to this.

Adjust MariaDB environment names if your MariaDB script uses different names.

```yaml
services:

  mariadb:
    build:
      context: ./requirements/mariadb
    image: mariadb
    container_name: mariadb

    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}

    volumes:
      - mariadb:/var/lib/mysql

    networks:
      - inception

    restart: unless-stopped


  wordpress:
    build:
      context: ./requirements/wordpress
    image: wordpress
    container_name: wordpress

    environment:
      WORDPRESS_DB_HOST: mariadb
      WORDPRESS_DB_NAME: ${MYSQL_DATABASE}
      WORDPRESS_DB_USER: ${MYSQL_USER}
      WORDPRESS_DB_PASSWORD: ${MYSQL_PASSWORD}

      DOMAIN_NAME: ${DOMAIN_NAME}

      WP_ADMIN_USER: ${WP_ADMIN_USER}
      WP_ADMIN_PASSWORD: ${WP_ADMIN_PASSWORD}
      WP_ADMIN_EMAIL: ${WP_ADMIN_EMAIL}

      WP_USER: ${WP_USER}
      WP_USER_PASSWORD: ${WP_USER_PASSWORD}
      WP_USER_EMAIL: ${WP_USER_EMAIL}

    volumes:
      - wordpress:/var/www/html

    depends_on:
      - mariadb

    networks:
      - inception

    restart: unless-stopped


networks:
  inception:
    name: inception
    driver: bridge


volumes:
  mariadb:
    name: mariadb
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${LOGIN}/data/mariadb

  wordpress:
    name: wordpress
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${LOGIN}/data/wordpress
```

---

# PART 25 — What should NOT be in Compose

Do not use:

```yaml
network_mode: host
```

Do not use:

```yaml
links:
```

Do not use scripts containing:

```bash
--link
```

Do not publish MariaDB port:

```yaml
ports:
  - "3306:3306"
```

Do not publish WordPress PHP-FPM port:

```yaml
ports:
  - "9000:9000"
```

Why?

MariaDB and WordPress communicate inside the Docker network.

Later only NGINX should expose:

```text
443
```

to the host.

---

# PART 26 — Prepare volume directories

On the final Linux VM/school machine:

```bash
mkdir -p /home/$USER/data/mariadb
mkdir -p /home/$USER/data/wordpress
```

If your 42 login and `$USER` differ, use the login expected by the subject/evaluation.

Check:

```bash
ls -la /home/$USER/data
```

Expected:

```text
mariadb
wordpress
```

Later your Makefile should do this automatically before `docker compose up`.

---

# PART 27 — Validate Compose

From:

```text
srcs/
```

run:

```bash
docker compose config
```

This parses and expands Compose.

Check the output.

Look for:

```text
image: mariadb
image: wordpress
WORDPRESS_DB_HOST: mariadb
networks: inception
volumes with /home/<login>/data/
```

If variables are empty, check `.env`.

---

# PART 28 — Build through Compose

From `srcs/`:

```bash
docker compose build
```

The evaluation expects services to be built through Docker Compose / Makefile eventually.

For Day 3, this is good:

```bash
docker compose build wordpress
```

but before defense, the Makefile should run the whole stack.

---

# PART 29 — Remove old manual test container if needed

You may have a manual MariaDB container from Day 2.

Check:

```bash
docker ps -a
```

If a container named `mariadb` already exists, Compose cannot create another with the same name.

If it was only a disposable test container and your MariaDB setup is reproducible through Dockerfile/init script, remove it:

```bash
docker rm -f mariadb
```

Explain:

```text
docker rm
    remove container

-f
    force, stopping it first if needed
```

This does not delete your source code.

If you have important non-reproducible DB data in it, do not delete until you understand what you are doing.

---

# PART 30 — Start MariaDB and WordPress

From `srcs/`:

```bash
docker compose up -d mariadb wordpress
```

Explain:

```text
up
    create/start services

-d
    detached mode, terminal returns

mariadb wordpress
    start only these services
```

Then:

```bash
docker compose ps
```

Goal:

```text
mariadb     running
wordpress   running
```

If WordPress exits, do not add sleep/tail.

Read logs.

---

# PART 31 — Read logs

```bash
docker compose logs mariadb
```

Then:

```bash
docker compose logs wordpress
```

Expected WordPress story:

```text
WordPress files not found. Copying files...
Waiting for MariaDB at mariadb...
MariaDB is ready.
Creating wp-config.php...
Installing WordPress...
Creating normal WordPress user...
Starting PHP-FPM...
```

The exact log words may differ.

The important result:

```text
WordPress stays running because PHP-FPM is running.
```

---

# PART 32 — Test Docker network

Run:

```bash
docker network ls
```

Look for:

```text
inception
```

Then:

```bash
docker network inspect inception
```

You should see both:

```text
mariadb
wordpress
```

Evaluation answer:

> The services are connected to a user-defined bridge network called `inception`. Containers on that network can communicate privately, and Docker DNS lets WordPress resolve the name `mariadb`.

---

# PART 33 — Test Docker DNS

Enter WordPress:

```bash
docker compose exec wordpress sh
```

Run:

```bash
getent hosts mariadb
```

Expected concept:

```text
172.x.x.x mariadb
```

Do not memorize the IP.

The point is that Docker resolves the name.

Exit:

```bash
exit
```

---

# PART 34 — Test MariaDB connection from WordPress container

Run:

```bash
docker compose exec wordpress sh
```

Then:

```bash
mariadb \
    --protocol=TCP \
    -h "$WORDPRESS_DB_HOST" \
    -u "$WORDPRESS_DB_USER" \
    "-p$WORDPRESS_DB_PASSWORD" \
    "$WORDPRESS_DB_NAME" \
    -e "SELECT 1;"
```

Expected:

```text
1
1
```

or similar successful result.

Exit:

```bash
exit
```

This proves:

```text
WordPress container has MariaDB client
DNS works
network works
MariaDB accepts network connection
credentials work
database exists
```

---

# PART 35 — Test PHP mysqli connection

Run:

```bash
docker compose exec wordpress php -r '
$mysqli = new mysqli(
    getenv("WORDPRESS_DB_HOST"),
    getenv("WORDPRESS_DB_USER"),
    getenv("WORDPRESS_DB_PASSWORD"),
    getenv("WORDPRESS_DB_NAME")
);

if ($mysqli->connect_error) {
    fwrite(STDERR, $mysqli->connect_error . PHP_EOL);
    exit(1);
}

echo "DB connection OK" . PHP_EOL;
'
```

Expected:

```text
DB connection OK
```

This proves:

```text
PHP works
php-mysql/mysqli works
environment variables exist
Docker DNS works
MariaDB credentials work
```

---

# PART 36 — Verify WordPress installed

Run:

```bash
docker compose exec wordpress \
    wp core is-installed \
    --path=/var/www/html \
    --allow-root
```

Then:

```bash
echo $?
```

Expected:

```text
0
```

Unix exit status:

```text
0
    success

non-zero
    failure
```

This is your Day 3 proof that the browser installation wizard should not be needed once NGINX exists.

---

# PART 37 — Check site URL

Run:

```bash
docker compose exec wordpress \
    wp option get siteurl \
    --path=/var/www/html \
    --allow-root
```

Expected:

```text
https://yourlogin.42.fr
```

or your configured domain.

---

# PART 38 — Verify WordPress files

Run:

```bash
docker compose exec wordpress ls -la /var/www/html
```

Look for:

```text
index.php
wp-config.php
wp-load.php
wp-admin/
wp-content/
wp-includes/
```

Important:

```text
/var/www/html
```

is the live WordPress directory and volume mount point.

---

# PART 39 — Verify WordPress users

Run:

```bash
docker compose exec wordpress \
    wp user list \
    --path=/var/www/html \
    --allow-root
```

Expected concept:

```text
user_login    roles
siteowner     administrator
author1       author
```

Check:

```text
admin user exists                         ✅
admin username does not contain admin     ✅
normal user exists                        ✅
```

---

# PART 40 — Verify PHP-FPM is the main process

Run:

```bash
docker compose exec wordpress cat /proc/1/comm
```

Expected concept:

```text
php-fpm8.2
```

Also:

```bash
docker compose exec wordpress ps aux
```

Look for PHP-FPM master/worker processes.

Bad:

```text
PID 1 = tail
PID 1 = sleep
PID 1 = bash
```

Good:

```text
PID 1 = php-fpm
```

---

# PART 41 — Verify volumes

Run:

```bash
docker volume ls
```

Look for:

```text
mariadb
wordpress
```

Then:

```bash
docker volume inspect wordpress
```

You want the output to contain a device/mount path like:

```text
/home/<login>/data/wordpress
```

Then:

```bash
docker volume inspect mariadb
```

You want:

```text
/home/<login>/data/mariadb
```

This is specifically evaluation-related.

---

# PART 42 — Restart/idempotence test

Run:

```bash
docker compose restart wordpress
```

Then:

```bash
docker compose logs --tail=60 wordpress
```

It should not recreate duplicate users or reinstall WordPress from zero.

Then:

```bash
docker compose exec wordpress \
    wp user list \
    --path=/var/www/html \
    --allow-root
```

You should still have the same administrator and normal user.

Why?

Because `init.sh` checks:

```text
wp-load.php exists?
wp-config.php exists?
wp core is-installed?
normal user exists?
```

before creating things.

---

# PART 43 — What Day 3 still cannot fully prove

Without NGINX, you cannot fully prove:

```text
https://login.42.fr works
HTTP port 80 is blocked
TLS v1.2 or TLS v1.3 is used
website is reachable from browser
admin dashboard works in browser
normal user can comment through browser
admin can edit page through browser
```

Those are NGINX/browser tasks.

But Day 3 prepares them by ensuring:

```text
WordPress is already installed
admin exists
normal user exists
PHP-FPM listens on 9000
NGINX will be able to reach wordpress:9000
```

So Day 4/NGINX should connect to a ready WordPress, not a wizard page.

---

# PART 44 — Troubleshooting by layer

## WordPress says MariaDB not ready

Check:

```bash
docker compose ps
docker compose logs mariadb
docker network inspect inception
```

Then from WordPress:

```bash
getent hosts mariadb
```

Then test MariaDB client manually.

---

## `Access denied for user 'wpuser'`

This usually means MariaDB was reached.

Problem likely:

```text
wrong password
wrong username
user host permissions
```

Check that MariaDB user is:

```text
wpuser@%
```

and check `.env`.

---

## `Unknown database 'wordpress'`

This means MariaDB was reached but the database does not exist.

Check MariaDB init script.

---

## `Can't connect to server on 'mariadb'`

Possible causes:

```text
MariaDB not running
wrong network
Docker DNS issue
MariaDB listening only on 127.0.0.1
wrong service name
```

---

## `wp: command not found`

Check:

```bash
ls -l /usr/local/bin/wp
```

and Dockerfile WP-CLI installation.

---

## `mysqli` missing

Check:

```bash
php -m | grep mysqli
```

If absent, check Dockerfile package:

```text
php-mysql
```

---

## WordPress container exits

Read:

```bash
docker compose logs wordpress
```

Do not fix by adding:

```text
tail -f
sleep infinity
```

The exit is useful evidence. Fix the actual failure.

---

# PART 45 — Evaluation drill

## Q1. What is WordPress?

Answer:

> WordPress is the PHP web application. Its files live in `/var/www/html` in the WordPress container, and its site data such as users, posts, comments, and settings is stored in MariaDB.

---

## Q2. What is PHP-FPM?

Answer:

> PHP-FPM is PHP's FastCGI Process Manager. It keeps PHP worker processes running and executes WordPress PHP files when NGINX sends FastCGI requests.

---

## Q3. Why is there no NGINX in the WordPress Dockerfile?

Answer:

> NGINX is a separate service. The WordPress container is only responsible for WordPress files and PHP-FPM. NGINX handles HTTPS and forwards PHP requests to PHP-FPM through FastCGI.

---

## Q4. What is port 9000?

Answer:

> Port 9000 is where PHP-FPM listens for FastCGI requests from NGINX.

---

## Q5. Why is PHP-FPM not exposed to the host?

Answer:

> PHP-FPM is an internal FastCGI service. The browser does not talk directly to it. NGINX will talk to `wordpress:9000` inside the Docker network.

---

## Q6. Why does WordPress use DB host `mariadb`?

Answer:

> `mariadb` is the Compose service name. Docker DNS resolves that name to the MariaDB container's current IP on the shared user-defined network.

---

## Q7. Why not use `localhost`?

Answer:

> Inside the WordPress container, `localhost` means the WordPress container itself. MariaDB is in a different container.

---

## Q8. Why not hard-code the MariaDB IP?

Answer:

> Container IPs can change when containers are recreated. Service names are stable and resolved dynamically by Docker DNS.

---

## Q9. Why do we use WP-CLI?

Answer:

> WP-CLI lets the init script create `wp-config.php`, install WordPress, create the administrator, and create a normal user automatically. This prevents the WordPress browser installation page.

---

## Q10. Why must the admin username not contain `admin`?

Answer:

> The evaluation explicitly checks this. The init script rejects any administrator username containing `admin` after converting it to lowercase.

---

## Q11. What keeps the container alive?

Answer:

> PHP-FPM keeps it alive. The init script ends with `exec php-fpm8.2 -F`, so PHP-FPM runs in the foreground as the main process.

---

## Q12. Why is `sleep 2` okay but `sleep infinity` bad?

Answer:

> `sleep 2` is a bounded wait between MariaDB readiness checks. `sleep infinity` is a fake keep-alive. Our real long-running process is PHP-FPM.

---

## Q13. Where is WordPress persistent data?

Answer:

> WordPress runtime files are in `/var/www/html`, which is mounted to a volume backed by `/home/<login>/data/wordpress`.

---

## Q14. Where is MariaDB persistent data?

Answer:

> MariaDB data is in `/var/lib/mysql`, which is mounted to a volume backed by `/home/<login>/data/mariadb`.

---

# PART 46 — Final Day 3 checklist

## WordPress Dockerfile

- [ ] `FROM debian:bookworm`
- [ ] installs PHP-FPM
- [ ] installs PHP CLI
- [ ] installs `php-mysql`
- [ ] installs MariaDB client, not server
- [ ] downloads WordPress source manually
- [ ] installs WP-CLI
- [ ] copies PHP-FPM config
- [ ] copies `tools/init.sh`
- [ ] no NGINX
- [ ] no ready-made WordPress image
- [ ] no `tail -f`
- [ ] no fake keep-alive

## PHP-FPM

- [ ] `www.conf` exists
- [ ] workers run as `www-data`
- [ ] listens on `0.0.0.0:9000`
- [ ] not only `127.0.0.1`
- [ ] `php-fpm8.2 -t` works

## WordPress init

- [ ] validates env variables
- [ ] rejects admin username containing admin/Admin
- [ ] copies WordPress files if missing
- [ ] waits for MariaDB with real SQL query
- [ ] creates `wp-config.php`
- [ ] installs WordPress if not installed
- [ ] creates normal user if missing
- [ ] `chown`s `/var/www/html`
- [ ] ends with `exec php-fpm8.2 -F`

## Compose/network

- [ ] service name `mariadb`
- [ ] image name `mariadb`
- [ ] service name `wordpress`
- [ ] image name `wordpress`
- [ ] both on `inception` network
- [ ] no `network_mode: host`
- [ ] no `links:`
- [ ] no `--link`
- [ ] WordPress DB host is `mariadb`
- [ ] no hard-coded IP

## Volumes

- [ ] MariaDB volume mounts to `/var/lib/mysql`
- [ ] WordPress volume mounts to `/var/www/html`
- [ ] volume inspect shows `/home/<login>/data/mariadb`
- [ ] volume inspect shows `/home/<login>/data/wordpress`

## Verification

- [ ] `docker compose config`
- [ ] `docker compose build`
- [ ] `docker compose up -d mariadb wordpress`
- [ ] `docker compose ps`
- [ ] `docker network inspect inception`
- [ ] `getent hosts mariadb` works from WordPress
- [ ] MariaDB client `SELECT 1` works from WordPress
- [ ] PHP mysqli test says `DB connection OK`
- [ ] `wp core is-installed` succeeds
- [ ] `wp user list` shows admin + normal user
- [ ] `/proc/1/comm` shows PHP-FPM
- [ ] restart does not duplicate installation/users

---

# Minimum win for today

If you are tired, focus on these:

```text
1. WordPress image builds from debian:bookworm
2. WordPress container starts through Compose
3. PHP-FPM runs in foreground
4. WordPress and MariaDB share Docker network
5. WordPress connects to MariaDB using host "mariadb"
6. WordPress installs automatically with WP-CLI
7. Admin username does not contain admin/Admin
8. Normal user exists
9. WordPress files are in /var/www/html
10. WordPress volume is planned/mounted for /home/<login>/data/wordpress
```

That is a solid Day 3.

---

# Final mental model

```text
Dockerfile
    builds image
    installs software
    copies config/scripts

init.sh
    runs when container starts
    prepares runtime state
    waits for dependencies
    then execs real service

docker-compose.yml
    builds services
    injects environment variables
    connects services to network
    mounts persistent volumes

Docker network
    lets containers communicate privately
    provides DNS names like mariadb and wordpress

WordPress container
    contains WordPress files and PHP-FPM
    no NGINX

MariaDB container
    contains database server
    no NGINX

NGINX container later
    exposes only 443
    forwards PHP requests to wordpress:9000
```
