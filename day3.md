# Inception — Day 3 — Wednesday — 5 hours
## Goal: Build WordPress + PHP-FPM and connect it to your existing MariaDB container

> **Important:** This guide is written to match your existing MariaDB setup.
>
> Your MariaDB uses:
>
> ```dockerfile
> FROM debian:bookworm
> ```
>
> and a runtime script:
>
> ```text
> mariadb/tools/init.sh
> ```
>
> So WordPress will also use **Debian Bookworm**, `apt-get`, and a `tools/init.sh` entrypoint.
>
> Also: this guide does **not** show you a huge finished file first. We build one small piece, explain it, test it, and only then move on.

---

# 0. What you should have at the end of Day 3

By the end of today:

```text
                    Docker network: inception

       ┌───────────────────────────────┐
       │                               │
       │   wordpress container         │
       │                               │
       │   /var/www/html               │
       │   WordPress PHP files         │
       │          │                    │
       │          ▼                    │
       │      PHP-FPM :9000            │
       │          │                    │
       │          │ SQL connection     │
       │          ▼                    │
       │      mariadb:3306             │
       │                               │
       └───────────────────────────────┘
```

Later, when NGINX exists:

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

The minimum win for today is:

- [ ] WordPress image builds from `debian:bookworm`
- [ ] WordPress container runs PHP-FPM in foreground
- [ ] WordPress and MariaDB share one Docker network
- [ ] WordPress reaches MariaDB using the name `mariadb`
- [ ] WordPress installs automatically with WP-CLI
- [ ] No browser installation wizard is needed
- [ ] Admin user exists and its username does not contain `admin`
- [ ] A second normal WordPress user exists

---

# 1. First understand the service before touching the Dockerfile

## 1.1 What is WordPress?

WordPress is **not a web server**.

WordPress is mainly a collection of PHP files such as:

```text
index.php
wp-login.php
wp-admin/
wp-content/
wp-includes/
```

A browser cannot execute PHP source code.

NGINX also does not execute PHP source code.

Something has to execute the PHP.

That something is PHP itself, and in our architecture PHP is managed by **PHP-FPM**.

Mental model:

```text
WordPress = application code
PHP       = executes the code
PHP-FPM   = keeps PHP ready as a long-running service
```

---

## 1.2 What is PHP-FPM?

FPM means:

```text
FastCGI Process Manager
```

PHP-FPM is a long-running process that manages PHP worker processes.

Conceptually:

```text
PHP-FPM master process
        │
        ├── PHP worker
        ├── PHP worker
        └── PHP worker
```

Later NGINX will send a request like:

```text
"Please execute /var/www/html/index.php"
```

PHP-FPM runs the PHP file and sends the result back to NGINX.

---

## 1.3 Why is WordPress separate from NGINX?

Your project should separate responsibilities:

```text
NGINX container
→ HTTPS / HTTP / TLS / routing

WordPress container
→ WordPress PHP files + PHP-FPM

MariaDB container
→ database server
```

Therefore your WordPress Dockerfile must contain:

```text
WordPress
PHP
PHP-FPM
```

and **no NGINX**.

### Evaluation answer

If the evaluator asks:

> Why didn't you install NGINX in your WordPress container?

You should be able to answer:

> NGINX and WordPress/PHP-FPM are separate services. NGINX handles HTTPS and HTTP requests. PHP-FPM executes WordPress PHP code. They communicate through FastCGI over the Docker network.

---

## 1.4 What is FastCGI?

You have already seen different protocols/connections:

```text
Browser → NGINX       HTTP/HTTPS
PHP → MariaDB         database connection / SQL
Docker CLI → daemon   Docker API through socket
```

NGINX and PHP-FPM use another protocol:

```text
FastCGI
```

So later:

```text
Browser ──HTTPS────► NGINX
NGINX   ──FastCGI──► PHP-FPM
PHP     ──SQL──────► MariaDB
```

---

## 1.5 Why port 9000?

PHP-FPM will listen on:

```text
9000
```

Later NGINX will contain something like:

```nginx
fastcgi_pass wordpress:9000;
```

Read it as:

```text
Send this FastCGI request
→ to the service called "wordpress"
→ on port 9000
```

PHP-FPM is **not HTTP**, so this is not something you browse directly.

---

# 2. Prepare the WordPress folder

You already created:

```text
srcs/requirements/wordpress/Dockerfile
```

From:

```bash
cd srcs/requirements/wordpress
```

create two folders:

```bash
mkdir -p conf tools
```

Now create the files:

```bash
touch conf/www.conf
touch tools/init.sh
```

Check:

```bash
find . -maxdepth 2 -type f
```

You should see:

```text
./Dockerfile
./conf/www.conf
./tools/init.sh
```

### Why `mkdir -p`?

`mkdir` means:

```text
make directory
```

`-p` means:

```text
create missing parent directories
and do not fail if the directory already exists
```

---

# 3. Build the WordPress Dockerfile slowly

Open:

```text
srcs/requirements/wordpress/Dockerfile
```

Do **not** paste the full final file yet.

---

# Step 3.1 — Add only the base image

Add:

```dockerfile
FROM debian:bookworm
```

Stop here.

## What does `FROM` mean?

Every Docker image needs a starting filesystem.

This says:

> Start from Debian Bookworm.

Before this line:

```text
no WordPress image filesystem exists yet
```

After this line the image starts with a minimal Debian filesystem containing normal Linux paths such as:

```text
/etc
/usr
/var
/bin
```

## Why Debian Bookworm?

Because your MariaDB already uses:

```dockerfile
FROM debian:bookworm
```

So now:

```text
MariaDB   → Debian Bookworm
WordPress → Debian Bookworm
```

That means the same package manager and similar system layout:

```text
apt-get
/etc/
/var/
/usr/local/bin/
```

No need to suddenly learn Alpine and `apk` in the middle of the project.

---

# Step 3.2 — Build the one-line Dockerfile once

From:

```text
srcs/requirements/wordpress
```

run:

```bash
docker build -t wordpress-test .
```

Break it down:

```text
docker build
→ build an image

-t wordpress-test
→ give the resulting image the temporary tag/name "wordpress-test"

.
→ use the current directory as Docker's build context
```

If this succeeds, your base image is valid.

---

# Step 3.3 — Add package installation

Now add underneath `FROM`:

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

Stop again.

We now explain this **line by line**.

---

## Step 3.3.1 — What does `RUN` mean?

You already wrote a useful note in your MariaDB Dockerfile:

```text
RUN = do something while CREATING the image
```

Exactly.

```dockerfile
RUN ...
```

means:

> Execute this command during `docker build` and save the resulting filesystem changes into the image.

This is **build time**.

Compare:

```text
Dockerfile RUN
→ build time

init.sh
→ container runtime
```

---

## Step 3.3.2 — `apt-get update`

```bash
apt-get update
```

downloads Debian's current package indexes.

It does **not** install PHP.

Think:

```text
apt-get update
→ refresh the list of packages Debian knows about
```

Then `apt-get install` can find them.

---

## Step 3.3.3 — What does `&&` mean?

```bash
command1 && command2
```

means:

> Run `command2` only if `command1` succeeded.

So:

```text
apt-get update succeeds?
        │
        ├── yes → install packages
        └── no  → stop
```

---

## Step 3.3.4 — What does `\` mean?

Example:

```dockerfile
RUN apt-get update && \
    apt-get install ...
```

The backslash means:

> Continue this same shell command on the next physical line.

It is mainly for readability.

---

## Step 3.3.5 — `apt-get install -y`

```bash
apt-get install
```

means:

```text
install packages
```

`-y` means:

```text
automatically answer yes to installation confirmation
```

A Docker build should not stop waiting for someone to type `y`.

---

## Step 3.3.6 — `--no-install-recommends`

Debian packages have:

```text
required dependencies
```

and sometimes optional recommended packages.

This flag says:

> Install what is necessary, but do not automatically install every recommended extra package.

This keeps the image smaller and more intentional.

---

## Step 3.3.7 — `ca-certificates`

```text
ca-certificates
```

lets programs verify HTTPS certificates.

We will download WordPress and WP-CLI over HTTPS.

---

## Step 3.3.8 — `curl`

```text
curl
```

is a command-line download/HTTP tool.

We will use it to obtain:

```text
WordPress
WP-CLI
```

---

## Step 3.3.9 — `tar`

WordPress is downloaded as a compressed archive.

`tar` lets us extract it.

---

## Step 3.3.10 — `mariadb-client`

This is important.

You are **not** installing another MariaDB server in WordPress.

Compare:

```text
mariadb-server
→ actually runs a MariaDB database server

mariadb-client
→ provides commands that CONNECT to a MariaDB server
```

Your database server stays in the MariaDB container.

The WordPress container gets only the client so it can test:

```text
Can I reach MariaDB?
```

---

## Step 3.3.11 — `php-fpm`

This installs PHP-FPM.

On Debian Bookworm, the normal PHP-FPM version is PHP 8.2.

This is the long-running service that will eventually become PID 1.

---

## Step 3.3.12 — `php-cli`

CLI means:

```text
Command Line Interface
```

This gives you the command:

```bash
php
```

WP-CLI itself is PHP software, so it needs the PHP command-line runtime.

---

## Step 3.3.13 — `php-mysql`

This is one of the most important PHP packages today.

WordPress needs PHP to communicate with MariaDB.

`php-mysql` provides extensions such as:

```text
mysqli
```

Mental model:

```text
WordPress PHP
     │
     │ php-mysql / mysqli
     ▼
MariaDB
```

Without this, PHP may work but WordPress cannot properly use the database.

---

## Step 3.3.14 — Other PHP extensions

```text
php-curl
php-gd
php-intl
php-mbstring
php-xml
php-zip
```

These provide common features WordPress expects.

Examples:

```text
php-curl
→ HTTP requests from PHP

php-gd
→ image processing

php-mbstring
→ multibyte / Unicode string support

php-xml
→ XML handling

php-zip
→ ZIP archive support

php-intl
→ internationalization functionality
```

You do not need to memorize all of them today.

---

## Step 3.3.15 — Why remove `/var/lib/apt/lists/*`?

At the end:

```bash
rm -rf /var/lib/apt/lists/*
```

`apt-get update` downloaded package index files.

Once packages are installed, those index files are not needed for the running WordPress service.

So we clean them from the image layer.

---

# Step 3.4 — Build and inspect these packages

Build again:

```bash
docker build -t wordpress-test .
```

Start a temporary shell:

```bash
docker run --rm -it wordpress-test sh
```

Inside the container:

```bash
php --version
```

You should see PHP 8.2.x.

Then:

```bash
php-fpm8.2 --version
```

Then:

```bash
php -m | grep mysqli
```

Expected:

```text
mysqli
```

Then:

```bash
mariadb --version
```

Remember:

```text
mariadb command here = client
not server
```

Exit:

```bash
exit
```

Before moving on, you should be able to answer:

```text
Why php-fpm?
Why php-cli?
Why php-mysql?
Why mariadb-client rather than mariadb-server?
```

---

# 4. Add WordPress source files to the image

Before writing commands, understand the two directories we want.

```text
/usr/src/wordpress
```

will hold a clean copy of WordPress inside the image.

```text
/var/www/html
```

will be the live/runtime WordPress directory.

Later `/var/www/html` will be mounted persistently.

Why not download only into `/var/www/html`?

Because when Docker mounts an empty volume over `/var/www/html`, files baked into that path in the image become hidden behind the mount.

So we use:

```text
/usr/src/wordpress
→ clean image copy

/var/www/html
→ runtime / future persistent copy
```

---

# Step 4.1 — Add the download block

Append this to the Dockerfile:

```dockerfile
RUN mkdir -p /usr/src/wordpress /var/www/html && \
    curl -fsSL https://wordpress.org/latest.tar.gz \
        -o /tmp/wordpress.tar.gz && \
    tar -xzf /tmp/wordpress.tar.gz \
        -C /usr/src/wordpress \
        --strip-components=1 && \
    rm /tmp/wordpress.tar.gz
```

Now understand each piece.

---

## Step 4.1.1 — `mkdir -p`

```bash
mkdir -p /usr/src/wordpress /var/www/html
```

creates both directories.

`-p` means:

```text
create them if missing
and do not fail if they already exist
```

---

## Step 4.1.2 — Understand `curl -fsSL`

```bash
curl -fsSL ...
```

The flags are:

```text
-f
→ fail on HTTP errors

-s
→ silent normal progress output

-S
→ still show real error messages

-L
→ follow redirects
```

Then:

```bash
-o /tmp/wordpress.tar.gz
```

means:

```text
save the downloaded file at this path
```

---

## Step 4.1.3 — Understand `tar -xzf`

```bash
tar -xzf /tmp/wordpress.tar.gz
```

means:

```text
-x → extract
-z → gzip compressed archive
-f → use the following filename
```

Then:

```bash
-C /usr/src/wordpress
```

means:

```text
extract into /usr/src/wordpress
```

---

## Step 4.1.4 — `--strip-components=1`

The archive normally contains:

```text
wordpress/
    index.php
    wp-admin/
    wp-content/
```

Without stripping, you would get:

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

removes the outer `wordpress/` folder while extracting.

---

## Step 4.1.5 — Remove the temporary archive

```bash
rm /tmp/wordpress.tar.gz
```

After extraction, the compressed archive is no longer needed.

---

# Step 4.2 — Test WordPress source

Build:

```bash
docker build -t wordpress-test .
```

Then:

```bash
docker run --rm wordpress-test ls -la /usr/src/wordpress
```

You should see files/directories such as:

```text
index.php
wp-admin
wp-content
wp-includes
wp-load.php
```

---

# 5. Install WP-CLI

## 5.1 Why do we need WP-CLI?

Normally WordPress installation is:

```text
open browser
↓
installation wizard
↓
enter admin username/password
↓
click install
```

For Inception, we want automatic initialization.

WP-CLI lets us do things such as:

```bash
wp config create
wp core install
wp user create
```

So the container can configure WordPress without needing the browser wizard.

---

# Step 5.2 — Add WP-CLI to Dockerfile

Append:

```dockerfile
RUN curl -fsSL \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /usr/local/bin/wp && \
    chmod +x /usr/local/bin/wp
```

You already understand `curl -fsSL` and `-o`.

The new thing is:

```bash
chmod +x /usr/local/bin/wp
```

---

## Step 5.2.1 — `chmod +x`

`chmod` changes permissions.

`+x` means:

```text
add executable permission
```

After this, `/usr/local/bin/wp` can be run as a command.

---

## Step 5.2.2 — Why `/usr/local/bin`?

`/usr/local/bin` is normally part of the shell's `PATH`.

So when you type:

```bash
wp
```

Linux can find:

```text
/usr/local/bin/wp
```

---

# Step 5.3 — Test WP-CLI

Build:

```bash
docker build -t wordpress-test .
```

Then:

```bash
docker run --rm wordpress-test wp --info
```

You want WP-CLI information, not:

```text
wp: command not found
```

---

# 6. Configure PHP-FPM step by step

Open:

```text
conf/www.conf
```

We will build it line by line.

---

# Step 6.1 — Pool name

Add:

```ini
[www]
```

PHP-FPM manages pools of worker processes.

`www` is simply the name of our pool.

Conceptually:

```text
PHP-FPM
   │
   └── pool "www"
          ├── worker
          ├── worker
          └── worker
```

---

# Step 6.2 — Worker user and group

Add:

```ini
user = www-data
group = www-data
```

PHP workers should not normally execute WordPress as root.

Debian already provides the web-service user/group:

```text
www-data
```

So PHP workers will run as `www-data`.

---

# Step 6.3 — Listening address

Add:

```ini
listen = 0.0.0.0:9000
```

This line matters a lot.

`9000` is the TCP port PHP-FPM will listen on.

`0.0.0.0` means:

> Listen on the container's available IPv4 network interfaces.

Why not:

```ini
listen = 127.0.0.1:9000
```

Because `127.0.0.1` means:

```text
this container itself
```

NGINX will later live in another container, so it must be able to reach PHP-FPM across the Docker network.

Therefore:

```text
127.0.0.1:9000 ❌
0.0.0.0:9000   ✅
```

---

# Step 6.4 — Process manager settings

Add:

```ini
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

You do not need to become a PHP-FPM tuning expert today.

Understand only the architecture:

```text
PHP-FPM master
    │
    ├── PHP worker
    ├── PHP worker
    └── PHP worker
```

`pm = dynamic` means PHP-FPM dynamically manages workers within limits.

`pm.max_children = 5` means at most five worker processes for this pool.

---

# Step 6.5 — Environment behavior

Add:

```ini
clear_env = no
```

This keeps environment variables available to PHP-FPM processes instead of clearing them.

---

# Step 6.6 — Worker output

Add:

```ini
catch_workers_output = yes
```

This makes worker output easier to surface through logs and helps debugging.

---

# Step 6.7 — Now review the whole `www.conf`

Only now compare your file to:

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

# 7. Copy `www.conf` into the image

Return to the Dockerfile and append:

```dockerfile
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
```

## What does Dockerfile `COPY` mean?

Syntax:

```text
COPY source destination
```

Here:

```text
source:
conf/www.conf

↓

destination inside the image:
/etc/php/8.2/fpm/pool.d/www.conf
```

Because Debian Bookworm uses PHP 8.2, the FPM config path contains:

```text
/etc/php/8.2/fpm/
```

---

# Step 7.1 — Test PHP-FPM config

Build:

```bash
docker build -t wordpress-test .
```

Then test config syntax:

```bash
docker run --rm wordpress-test php-fpm8.2 -t
```

`-t` means:

```text
test the PHP-FPM configuration
```

Do this before trying Compose.

---

# 8. Build `tools/init.sh` slowly

This is the runtime script.

It mirrors your MariaDB design:

```text
MariaDB container starts
↓
tools/init.sh
↓
initialize if necessary
↓
exec mariadbd
```

WordPress will be:

```text
WordPress container starts
↓
tools/init.sh
↓
initialize if necessary
↓
exec php-fpm8.2 -F
```

Open:

```text
tools/init.sh
```

---

# Step 8.1 — Shebang

Add:

```sh
#!/bin/sh
```

This tells Linux:

```text
run this script using /bin/sh
```

Same idea as your MariaDB script.

---

# Step 8.2 — Strict shell mode

Add:

```sh
set -eu
```

You already used this in MariaDB.

`-e`:

```text
stop when an important command fails
```

`-u`:

```text
using an undefined variable is an error
```

This catches mistakes early.

---

# Step 8.3 — WordPress runtime path

Add:

```sh
WP_PATH="/var/www/html"
```

Now instead of repeatedly typing:

```text
/var/www/html
```

we can use:

```sh
"$WP_PATH"
```

---

# 9. Environment variables: understand before coding

WordPress needs to know:

```text
MariaDB host
MariaDB database name
MariaDB user
MariaDB password

site domain
administrator username/password/email
normal user username/password/email
```

We will use:

```text
WORDPRESS_DB_HOST
WORDPRESS_DB_NAME
WORDPRESS_DB_USER
WORDPRESS_DB_PASSWORD

DOMAIN_NAME

WP_ADMIN_USER
WP_ADMIN_PASSWORD
WP_ADMIN_EMAIL

WP_USER
WP_USER_PASSWORD
WP_USER_EMAIL
```

These names are ours. Docker does not invent them automatically.

Compose will inject values into the container later.

---

# Step 9.1 — Add a helper that checks environment variables

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

Now understand it.

---

## Step 9.1.1 — Shell function

```sh
require_env()
{
    ...
}
```

defines reusable shell behavior.

Later:

```sh
require_env WORDPRESS_DB_NAME
```

means:

```text
check that WORDPRESS_DB_NAME is not empty
```

---

## Step 9.1.2 — `$1`

Inside a shell function:

```text
$1
```

means:

```text
the first argument passed to the function
```

So:

```sh
require_env WORDPRESS_DB_NAME
```

makes:

```sh
variable_name="$1"
```

become conceptually:

```text
variable_name=WORDPRESS_DB_NAME
```

---

## Step 9.1.3 — `-z`

```sh
[ -z "$variable_value" ]
```

means:

```text
is this string empty?
```

If yes, we print a useful error and exit.

This is **fail fast** behavior.

---

# Step 9.2 — Require every variable

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

The loop checks each variable one at a time.

Mental model:

```text
missing DB password?
→ stop immediately

missing admin email?
→ stop immediately
```

Better than continuing in a broken state.

---

# 10. Enforce the admin username rule

Your evaluation requires the WordPress administrator username to not contain:

```text
admin
```

including different capitalization.

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

## Why lowercase it first?

So all of these are rejected:

```text
admin
Admin
ADMIN
myAdminUser
administrator
```

`*admin*` means:

```text
anything before "admin"
+
admin
+
anything after
```

---

# 11. Populate `/var/www/html` only when needed

Add:

```sh
if [ ! -f "$WP_PATH/wp-load.php" ]; then
    echo "WordPress files not found. Copying files..."
    cp -a /usr/src/wordpress/. "$WP_PATH/"
fi
```

Now understand it.

---

## Step 11.1 — `[ ! -f ... ]`

You already used similar tests in MariaDB.

```text
-f
→ does this regular file exist?

!
→ NOT
```

So:

```sh
[ ! -f "$WP_PATH/wp-load.php" ]
```

means:

> If `wp-load.php` does not exist...

then copy WordPress into the runtime directory.

---

## Step 11.2 — Why check `wp-load.php`?

Because `/var/www/html` may exist as an empty directory.

Checking only whether the directory exists would not tell us whether WordPress is actually there.

`wp-load.php` is a good marker for a populated WordPress installation directory.

---

## Step 11.3 — `cp -a`

```bash
cp -a /usr/src/wordpress/. "$WP_PATH/"
```

`cp` means copy.

`-a` means archive mode, which recursively copies and preserves useful filesystem properties.

The source:

```text
/usr/src/wordpress/.
```

means:

```text
copy the contents of this directory
```

not:

```text
create /var/www/html/wordpress/
```

So we get:

```text
/var/www/html/index.php
```

not:

```text
/var/www/html/wordpress/index.php
```

---

## Step 11.4 — Idempotence

First startup:

```text
wp-load.php missing
→ copy WordPress
```

Second startup:

```text
wp-load.php exists
→ skip copy
```

This is the same idea you used in MariaDB with:

```sh
if [ ! -d "/var/lib/mysql/mysql" ]; then
```

Initialization happens only when needed.

---

# 12. Wait for MariaDB to become ready

Compose can start two containers very close together.

But:

```text
container started
```

does not always mean:

```text
database ready to execute queries
```

So WordPress should perform a real database readiness check.

Add:

```sh
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
```

Now unpack it.

---

## Step 12.1 — Loop mental model

```text
try MariaDB
    │
    ├── works → continue
    │
    └── fails
          ↓
       sleep 2 sec
          ↓
       try again
```

Maximum is roughly:

```text
30 × 2 seconds ≈ 60 seconds
```

Then fail rather than hang forever.

---

## Step 12.2 — `mariadb`

This is the **client** installed in the WordPress image.

It connects to your separate MariaDB server container.

---

## Step 12.3 — `--protocol=TCP`

This forces a network connection.

We specifically want to test:

```text
WordPress container
→ Docker network
→ MariaDB container
```

not a local Unix socket.

---

## Step 12.4 — `-h`

```bash
-h "$WORDPRESS_DB_HOST"
```

`-h` means:

```text
host
```

Later this value will be:

```text
mariadb
```

---

## Step 12.5 — `-u`

```bash
-u "$WORDPRESS_DB_USER"
```

means:

```text
database username
```

For you this will likely be `wpuser`.

---

## Step 12.6 — `-pPASSWORD`

```bash
"-p$WORDPRESS_DB_PASSWORD"
```

supplies the password to the MariaDB client.

Notice there is no space between `-p` and the password value.

---

## Step 12.7 — `-e "SELECT 1;"`

`-e` means:

```text
execute this SQL statement and exit
```

`SELECT 1;` is harmless.

It proves a lot:

```text
Docker DNS worked
network worked
MariaDB accepted TCP connection
credentials worked
database was selectable
SQL query worked
```

---

## Step 12.8 — `/dev/null` again

You learned `/dev/null` yesterday.

Here:

```sh
>/dev/null 2>&1
```

means:

```text
discard standard output
and discard error output
```

Inside this retry loop, we care only about success or failure.

---

## Step 12.9 — Is `sleep 2` allowed?

Yes.

Bad fake keep-alive:

```sh
sleep infinity
```

Our use:

```text
DB not ready
→ wait two seconds
→ try again
```

The final container remains alive because PHP-FPM runs in foreground, **not** because `sleep` runs forever.

---

# 13. Check your MariaDB before blaming WordPress

Yesterday you confirmed your database user exists as:

```text
wpuser@%
```

That is useful now because WordPress connects from another container.

But the MariaDB **server itself** also needs to accept network connections.

If MariaDB listens only on:

```text
127.0.0.1:3306
```

then only processes inside the MariaDB container can connect.

WordPress needs MariaDB reachable through the Docker network.

So if connection fails later, inspect before changing anything.

When MariaDB is running, you can inspect its listening behavior with available tools/configuration.

Your final MariaDB server should effectively be reachable on the container network, commonly via a bind address such as:

```text
0.0.0.0
```

If your existing `mariadbd` startup already works over the Docker network, do not change it just for the sake of changing it.

Understand and test first.

---

# 14. Create `wp-config.php` automatically

Once MariaDB is ready, WordPress needs its database settings.

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

## Step 14.1 — What is `wp-config.php`?

It is a major WordPress configuration file.

It contains database configuration such as:

```text
database name
database user
database password
database host
```

---

## Step 14.2 — Why generate it at runtime?

We do not want real credentials baked into the Dockerfile/image.

Better flow:

```text
image
→ generic

container starts
→ receives environment values

init.sh
→ creates wp-config.php
```

---

## Step 14.3 — `wp config create`

```text
wp
→ WP-CLI

config create
→ create wp-config.php

--path
→ WordPress directory

--dbname
→ database name

--dbuser
→ database username

--dbpass
→ database password

--dbhost
→ database host
```

---

## Step 14.4 — Why DB host is not `localhost`

Inside the WordPress container:

```text
localhost
```

means:

```text
WordPress container itself
```

But MariaDB is a different container.

So later:

```text
WORDPRESS_DB_HOST=mariadb
```

Correct:

```text
mariadb ✅
```

Wrong:

```text
localhost ❌
```

---

## Step 14.5 — Why `--allow-root`?

The initialization script starts as root.

WP-CLI protects against running as root by default.

For this controlled container initialization we explicitly allow it:

```text
--allow-root
```

PHP-FPM workers themselves will run as `www-data`.

---

# 15. Install WordPress automatically

Creating `wp-config.php` is not the same as installing WordPress tables in the database.

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

## Step 15.1 — `wp core is-installed`

This asks:

```text
Is WordPress already installed in the database?
```

If yes:

```text
skip installation
```

If no:

```text
install it
```

This makes restart behavior idempotent.

---

## Step 15.2 — `if ! command`

`!` means NOT.

So:

```sh
if ! wp core is-installed
```

means:

```text
if WordPress is NOT installed
```

---

## Step 15.3 — `wp core install`

This replaces the browser installation wizard.

It creates:

```text
WordPress DB tables
site URL
site title
administrator user
administrator password
administrator email
```

So when NGINX is added later, the browser should not ask you to run the WordPress installer.

---

# 16. Create a normal WordPress user

Your project also expects another user that is not the administrator.

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

## Why check first?

Without the check, a restart would try to create the same user again.

With the check:

```text
user exists?
    │
    ├── yes → skip
    └── no  → create
```

Again: idempotence.

---

# 17. Fix WordPress file ownership

Add:

```sh
chown -R www-data:www-data "$WP_PATH"
```

You already learned `chown` yesterday.

Review:

```text
chown
→ change owner

-R
→ recursive

www-data:www-data
→ user : group
```

PHP-FPM workers run as `www-data`, so WordPress runtime files should be accessible to that service user.

---

# 18. Start the real foreground service

Add the final line:

```sh
exec php-fpm8.2 -F
```

This is one of the most important lines in the whole WordPress container.

---

## Step 18.1 — `php-fpm8.2`

Starts PHP-FPM.

---

## Step 18.2 — `-F`

Means:

```text
foreground
```

Docker wants the real service to remain in foreground rather than daemonize and disappear into the background.

---

## Step 18.3 — Why `exec`?

Without `exec`:

```text
PID 1
init.sh shell
    │
    └── PHP-FPM child
```

With:

```sh
exec php-fpm8.2 -F
```

PHP-FPM replaces the shell:

```text
PID 1
PHP-FPM
```

This is the same principle as your MariaDB container ending with the real `mariadbd` process.

---

## Step 18.4 — No fake keep-alive

Do not use:

```text
tail -f
sleep infinity
& bash
```

Your container stays alive because:

```text
PHP-FPM itself is alive
```

### Evaluation answer

> The WordPress container stays running because PHP-FPM runs in the foreground as the real service process. I do not use a fake keep-alive process.

---

# 19. Only now review the complete `tools/init.sh`

You built each part separately. Now compare your result to this reference:

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

---

# 20. Copy `init.sh` into the image

Return to the Dockerfile.

Append:

```dockerfile
COPY tools/init.sh /usr/local/bin/init.sh
```

Same Dockerfile `COPY` idea:

```text
host/build context:
tools/init.sh

↓

inside image:
/usr/local/bin/init.sh
```

Then add:

```dockerfile
RUN chmod +x /usr/local/bin/init.sh
```

Also on your host:

```bash
chmod +x tools/init.sh
```

---

# 21. Set the working directory

Add:

```dockerfile
WORKDIR /var/www/html
```

This sets the default working directory inside the image/container.

Think roughly:

```text
cd /var/www/html
```

for following commands/runtime behavior.

---

# 22. Document PHP-FPM's port

Add:

```dockerfile
EXPOSE 9000
```

Important:

`EXPOSE` does **not** publish port 9000 to your host.

It is mainly image metadata documenting:

```text
this service expects to listen on port 9000
```

Publishing is a separate Compose `ports:` concept.

We do not need to publish PHP-FPM to the host.

Later NGINX reaches it internally.

---

# 23. Set the entrypoint

Add:

```dockerfile
ENTRYPOINT ["/usr/local/bin/init.sh"]
```

Meaning:

```text
container starts
↓
/usr/local/bin/init.sh
↓
prepare WordPress
↓
wait for MariaDB
↓
configure/install WordPress
↓
exec PHP-FPM
```

This is consistent with your MariaDB structure.

---

# 24. Only now review the complete Dockerfile

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
    curl -fsSL https://wordpress.org/latest.tar.gz \
        -o /tmp/wordpress.tar.gz && \
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

At this point you should be able to explain every instruction rather than just recognize it.

---

# 25. Test the WordPress image before Compose

From:

```text
srcs/requirements/wordpress
```

build:

```bash
docker build -t wordpress-test .
```

Then test individual pieces.

## PHP

```bash
docker run --rm wordpress-test php --version
```

## PHP-FPM configuration

```bash
docker run --rm wordpress-test php-fpm8.2 -t
```

## mysqli

```bash
docker run --rm wordpress-test php -m | grep mysqli
```

Expected:

```text
mysqli
```

## WordPress source

```bash
docker run --rm wordpress-test ls /usr/src/wordpress
```

## WP-CLI

```bash
docker run --rm wordpress-test wp --info
```

Your final container cannot fully start yet without environment variables and MariaDB. That is normal.

---

# 26. Now networking finally has a purpose

Yesterday you had one service:

```text
MariaDB
```

Today:

```text
WordPress
    ↓
needs MariaDB
```

Now Docker networking matters.

---

# 27. What is a Docker network?

Think of a normal LAN:

```text
Laptop A ─── router/network ─── Laptop B
```

Docker creates a virtual private network:

```text
┌──────────────────────────────┐
│ inception network            │
│                              │
│ mariadb          wordpress   │
│    ●────────────────●        │
│                              │
└──────────────────────────────┘
```

Each container gets a network interface and an internal IP.

---

# 28. Why not hard-code MariaDB's IP?

MariaDB might receive:

```text
172.20.0.2
```

But after recreation it might become:

```text
172.20.0.5
```

So hard-coding:

```text
172.20.0.2
```

is fragile.

Instead WordPress uses:

```text
mariadb
```

---

# 29. Docker DNS

Docker provides internal name resolution on a user-defined network.

Conceptually:

```text
WordPress asks:
"Where is mariadb?"

        ↓

Docker DNS

        ↓

"mariadb currently has this IP"
```

Compare with normal DNS:

```text
google.com
   ↓ DNS
IP address
```

Docker:

```text
mariadb
   ↓ Docker DNS
container IP
```

### Evaluation sentence

> WordPress uses the MariaDB service name rather than a hard-coded IP. Docker's internal DNS resolves that service name to the container's current IP on the shared user-defined network.

---

# 30. Create `.env` safely

Go to:

```text
srcs/
```

Create if needed:

```bash
touch .env
```

At your Git repository root, add:

```gitignore
srcs/.env
```

to `.gitignore`.

Do not commit real passwords.

---

# Step 30.1 — Example environment values

Use values matching your existing MariaDB variables.

For example:

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=replace_with_real_password
MYSQL_ROOT_PASSWORD=replace_with_real_root_password

DOMAIN_NAME=yourlogin.42.fr

WP_ADMIN_USER=siteowner
WP_ADMIN_PASSWORD=replace_with_real_admin_password
WP_ADMIN_EMAIL=owner@example.com

WP_USER=author1
WP_USER_PASSWORD=replace_with_real_user_password
WP_USER_EMAIL=author1@example.com
```

Important:

```text
WP_ADMIN_USER must not contain admin/Admin/ADMIN
```

---

# 31. Build Compose step by step

Open:

```text
srcs/docker-compose.yml
```

If you already have one, modify it instead of blindly replacing working parts.

---

# Step 31.1 — Start with `services`

```yaml
services:
```

Compose organizes containers as services.

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

# Step 31.2 — MariaDB service

Add/adapt:

```yaml
  mariadb:
    build:
      context: ./requirements/mariadb
    container_name: mariadb
```

`build.context` tells Compose where MariaDB's Dockerfile/build context lives.

---

# Step 31.3 — MariaDB environment

Use the variable names your existing MariaDB `init.sh` actually expects.

If it uses `MYSQL_*`, for example:

```yaml
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
```

Understand:

```yaml
MYSQL_DATABASE: ${MYSQL_DATABASE}
```

Left side:

```text
name inside the container
```

Right side:

```text
value read by Compose from .env/shell
```

---

# Step 31.4 — Put MariaDB on the network

Add:

```yaml
    networks:
      - inception
```

Meaning:

```text
attach MariaDB to the inception network
```

---

# Step 31.5 — WordPress service

Add:

```yaml
  wordpress:
    build:
      context: ./requirements/wordpress
    container_name: wordpress
```

---

# Step 31.6 — WordPress DB environment

Add:

```yaml
    environment:
      WORDPRESS_DB_HOST: mariadb
      WORDPRESS_DB_NAME: ${MYSQL_DATABASE}
      WORDPRESS_DB_USER: ${MYSQL_USER}
      WORDPRESS_DB_PASSWORD: ${MYSQL_PASSWORD}
```

This is the key connection.

---

## Understand `WORDPRESS_DB_HOST: mariadb`

```text
WORDPRESS_DB_HOST
→ variable our init.sh reads

mariadb
→ Compose service name / Docker DNS name
```

Full chain:

```text
docker-compose.yml
WORDPRESS_DB_HOST=mariadb
        ↓
WordPress container environment
        ↓
init.sh
        ↓
wp config create
        ↓
wp-config.php
        ↓
WordPress connects to "mariadb"
        ↓
Docker DNS resolves it
        ↓
MariaDB container
```

---

# Step 31.7 — Add WordPress user/site variables

```yaml
      DOMAIN_NAME: ${DOMAIN_NAME}

      WP_ADMIN_USER: ${WP_ADMIN_USER}
      WP_ADMIN_PASSWORD: ${WP_ADMIN_PASSWORD}
      WP_ADMIN_EMAIL: ${WP_ADMIN_EMAIL}

      WP_USER: ${WP_USER}
      WP_USER_PASSWORD: ${WP_USER_PASSWORD}
      WP_USER_EMAIL: ${WP_USER_EMAIL}
```

---

# Step 31.8 — `depends_on`

Add:

```yaml
    depends_on:
      - mariadb
```

This expresses the service dependency/startup relationship.

But simple `depends_on` does **not** prove MariaDB is ready for SQL queries.

That is why your `init.sh` still performs the real `SELECT 1` readiness loop.

Different jobs:

```text
depends_on
→ startup relationship

SELECT 1 loop
→ actual database readiness
```

---

# Step 31.9 — Put WordPress on the same network

```yaml
    networks:
      - inception
```

Now:

```text
mariadb
wordpress
```

share:

```text
inception
```

---

# Step 31.10 — Define the network

At the bottom, outside `services:`:

```yaml
networks:
  inception:
    name: inception
    driver: bridge
```

A user-defined bridge network is Docker's normal private network mechanism for containers communicating on one Docker host.

---

# 32. Only now review the Compose reference

Adapt MariaDB environment names if your existing script uses different names.

```yaml
services:

  mariadb:
    build:
      context: ./requirements/mariadb
    container_name: mariadb

    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}

    networks:
      - inception

    restart: unless-stopped


  wordpress:
    build:
      context: ./requirements/wordpress
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

    depends_on:
      - mariadb

    networks:
      - inception

    restart: unless-stopped


networks:
  inception:
    name: inception
    driver: bridge
```

---

# 33. Why no published MariaDB or WordPress ports?

Do **not** add just because a tutorial does:

```yaml
ports:
  - "3306:3306"
```

MariaDB needs to be reached internally by WordPress.

Do not publish:

```yaml
ports:
  - "9000:9000"
```

for PHP-FPM either.

Your intended architecture is:

```text
Host/browser
    │
    │ 443
    ▼
NGINX
    │
    │ internal 9000
    ▼
WordPress/PHP-FPM
    │
    │ internal 3306
    ▼
MariaDB
```

Only NGINX will eventually need the public host-facing HTTPS port.

---

# 34. Validate Compose before starting containers

From:

```text
srcs/
```

run:

```bash
docker compose config
```

This parses the YAML and resolves environment values.

Check specifically:

```text
WORDPRESS_DB_HOST is mariadb
DB database names match
DB usernames match
```

---

# 35. Build using Compose

```bash
docker compose build wordpress
```

or:

```bash
docker compose build
```

Because you already tested the WordPress image manually, errors here are more likely to be Compose path/configuration issues.

---

# 36. Deal with yesterday's manually created MariaDB container

Check:

```bash
docker ps -a
```

If you already have a test container literally named:

```text
mariadb
```

Compose cannot create another one with the exact same name.

If yesterday's container is only a disposable test container and all behavior is reproducible from your Dockerfile + `init.sh`, you can remove the old test container:

```bash
docker rm -f mariadb
```

Remember:

```text
rm
→ remove container

-f
→ force-stop it first if necessary
```

This does not delete your source code.

---

# 37. Start MariaDB + WordPress

From `srcs/`:

```bash
docker compose up -d mariadb wordpress
```

`-d` means detached mode.

Then:

```bash
docker compose ps
```

Goal:

```text
mariadb      running
wordpress    running
```

If WordPress exits, do not add `sleep infinity`.

Read the logs.

---

# 38. Read logs in the correct order

MariaDB:

```bash
docker compose logs mariadb
```

WordPress:

```bash
docker compose logs wordpress
```

A successful first WordPress startup should conceptually be:

```text
copy WordPress files
↓
wait for MariaDB
↓
MariaDB ready
↓
create wp-config.php
↓
install WordPress
↓
create normal user
↓
start PHP-FPM
```

---

# 39. Test the Docker network

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

You want to see both:

```text
mariadb
wordpress
```

attached to it.

---

# 40. Test Docker DNS

Enter WordPress:

```bash
docker compose exec wordpress sh
```

Try:

```bash
getent hosts mariadb
```

If available, you should see an internal IP associated with `mariadb`.

Do not memorize the IP.

The whole point is that Docker handles it for you.

Exit:

```bash
exit
```

---

# 41. Test MariaDB from inside WordPress

Enter WordPress:

```bash
docker compose exec wordpress sh
```

Run:

```bash
mariadb \
    --protocol=TCP \
    -h "$WORDPRESS_DB_HOST" \
    -u "$WORDPRESS_DB_USER" \
    "-p$WORDPRESS_DB_PASSWORD" \
    "$WORDPRESS_DB_NAME" \
    -e "SELECT 1;"
```

If it works, you have proved:

```text
Docker DNS ✅
Docker network ✅
MariaDB TCP listening ✅
wpuser authentication ✅
database exists ✅
```

Exit:

```bash
exit
```

---

# 42. Test PHP itself connecting to MariaDB

This proves PHP + `mysqli`, not just the MariaDB CLI.

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
PHP works ✅
mysqli exists ✅
Docker DNS works ✅
Docker network works ✅
MariaDB works ✅
credentials work ✅
```

---

# 43. Verify WordPress is installed

```bash
docker compose exec wordpress \
    wp core is-installed \
    --path=/var/www/html \
    --allow-root
```

The command may print nothing when successful.

Check status:

```bash
echo $?
```

Expected:

```text
0
```

Unix convention:

```text
0 → success
non-zero → failure
```

---

# 44. Verify site URL

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

# 45. Verify WordPress files

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

Remember:

```text
/usr/src/wordpress
→ clean source inside image

/var/www/html
→ live runtime WordPress
→ future persistent mount target
```

---

# 46. Verify both WordPress users

```bash
docker compose exec wordpress \
    wp user list \
    --path=/var/www/html \
    --allow-root
```

You want:

```text
one administrator
one normal user
```

and the admin username must not contain `admin`.

---

# 47. Verify PHP-FPM is the real running service

```bash
docker top wordpress
```

or:

```bash
docker compose exec wordpress ps aux
```

You should see PHP-FPM master/worker processes.

Most important question:

> What keeps the WordPress container alive?

Answer:

```text
PHP-FPM
```

Not:

```text
tail
sleep
bash
```

---

# 48. Check PID 1

You did this with MariaDB.

Run:

```bash
docker compose exec wordpress cat /proc/1/comm
```

You should see a PHP-FPM process name such as:

```text
php-fpm8.2
```

Mental symmetry:

```text
MariaDB container
PID 1 → mariadbd

WordPress container
PID 1 → php-fpm8.2
```

That is exactly the Docker foreground-process idea you have been learning.

---

# 49. Restart test: idempotence

Restart WordPress:

```bash
docker compose restart wordpress
```

Then:

```bash
docker compose logs --tail=50 wordpress
```

It should not:

```text
create duplicate users
reinstall WordPress destructively
overwrite everything every time
```

Because the script checks:

```text
wp-load.php exists?
wp-config.php exists?
WordPress already installed?
normal user already exists?
```

Then verify users again:

```bash
docker compose exec wordpress \
    wp user list \
    --path=/var/www/html \
    --allow-root
```

---

# 50. Why the website may still not open in your browser today

You do not have NGINX connected yet.

Browsers speak:

```text
HTTP / HTTPS
```

PHP-FPM speaks:

```text
FastCGI
```

So this is not the final path:

```text
Browser ──X──► PHP-FPM
```

Later:

```text
Browser
↓ HTTPS
NGINX
↓ FastCGI
PHP-FPM
```

will complete it.

Do **not** install NGINX inside the WordPress container just to make the browser work today.

---

# 51. Persistence preparation

Today we deliberately use:

```text
/var/www/html
```

as the live WordPress path.

Later a persistent volume/directory will mount there.

First startup with empty persistent storage:

```text
/var/www/html empty
↓
copy from /usr/src/wordpress
↓
configure
↓
install
```

Later startup:

```text
/var/www/html already contains WordPress
↓
skip copy/reinstall
↓
continue
```

That is why today's design is already preparing correctly for volumes.

---

# 52. Troubleshooting by meaning, not guessing

## Error: `Access denied for user 'wpuser'`

This often means networking worked far enough for MariaDB to answer.

Look at:

```text
username
password
MariaDB user host permissions
```

You already saw:

```text
wpuser@%
```

which is the right direction for cross-container access.

---

## Error: `Unknown database 'wordpress'`

This means WordPress probably reached MariaDB, but the requested database does not exist.

Check MariaDB initialization.

---

## Error: cannot connect to host `mariadb`

Check in this order:

```text
1. Is MariaDB container running?
2. Did MariaDB initialize successfully?
3. Are both containers on `inception` network?
4. Does Docker DNS resolve `mariadb`?
5. Is MariaDB listening on a network interface, not only loopback?
6. Are credentials correct?
```

Do not randomly edit PHP code first.

---

## Error: `wp: command not found`

Check:

```bash
ls -l /usr/local/bin/wp
wp --info
```

---

## Error: `mysqli` missing

Check:

```bash
php -m | grep mysqli
```

If missing, inspect `php-mysql` installation.

---

## Error: PHP-FPM config failure

Run:

```bash
php-fpm8.2 -t
```

and inspect:

```text
/etc/php/8.2/fpm/pool.d/www.conf
```

---

## WordPress container exits immediately

Read:

```bash
docker compose logs wordpress
```

Do not "fix" it with:

```text
sleep infinity
```

The exit means your real service or initialization failed. Fix that actual cause.

---

# 53. Evaluation drill

Try to answer these without looking at the answer first.

## What is WordPress?

> WordPress is the PHP web application. Its application files live in the WordPress container, while site data such as users, posts and settings is stored in MariaDB.

## What is PHP-FPM?

> PHP-FPM is PHP's FastCGI Process Manager. It manages PHP worker processes and executes WordPress PHP code when NGINX sends FastCGI requests.

## Why no NGINX in the WordPress container?

> NGINX is a separate web/TLS service. WordPress/PHP-FPM handles the PHP application. NGINX later talks to PHP-FPM over FastCGI.

## Why `0.0.0.0:9000`?

> NGINX will be in another container. Listening only on `127.0.0.1` would restrict PHP-FPM to connections from the WordPress container itself.

## Why DB host `mariadb` rather than `localhost`?

> `localhost` inside WordPress means the WordPress container itself. MariaDB is a separate container, so WordPress uses the MariaDB service name on the shared Docker network.

## How does `mariadb` become an IP address?

> Docker's internal DNS resolves the service name to the MariaDB container's current IP.

## Why no hard-coded container IP?

> Container IPs can change when containers are recreated. The service name is stable and Docker resolves it dynamically.

## What keeps the WordPress container alive?

> PHP-FPM itself, running in foreground with `exec php-fpm8.2 -F`.

## Why `exec`?

> It replaces the shell with PHP-FPM so the real service becomes the container's main process and handles Docker signals directly.

## Why is `sleep 2` in the readiness loop okay?

> It is only a short bounded retry delay. It does not keep the container alive. PHP-FPM is the real long-running process.

## How do you avoid the browser installation wizard?

> The startup script uses WP-CLI to generate `wp-config.php`, install WordPress, create the administrator and create a normal user automatically.

## Why both `/usr/src/wordpress` and `/var/www/html`?

> `/usr/src/wordpress` stores a clean copy inside the image. `/var/www/html` is the live runtime directory and future persistent mount. An empty volume can be populated from the clean copy.

## What is idempotence here?

> Restarting the service does not unnecessarily recreate or duplicate initialization. The script checks whether files, configuration, WordPress installation and users already exist.

---

# 54. Final Day 3 checklist

## Understanding

- [ ] WordPress is PHP application code, not a web server
- [ ] PHP executes WordPress
- [ ] PHP-FPM manages PHP workers
- [ ] NGINX → PHP-FPM uses FastCGI
- [ ] PHP-FPM is not HTTP
- [ ] NGINX stays out of the WordPress image
- [ ] PHP-FPM listens on port 9000

## Dockerfile

- [ ] `FROM debian:bookworm`
- [ ] understand `RUN`
- [ ] understand `apt-get update`
- [ ] understand `&&`
- [ ] understand `\`
- [ ] understand `-y`
- [ ] install `php-fpm`
- [ ] install `php-cli`
- [ ] install `php-mysql`
- [ ] install `mariadb-client`, not server
- [ ] download WordPress yourself
- [ ] understand `/usr/src/wordpress`
- [ ] understand `/var/www/html`
- [ ] install WP-CLI
- [ ] copy `www.conf`
- [ ] copy `init.sh`
- [ ] `WORKDIR /var/www/html`
- [ ] `EXPOSE 9000`
- [ ] `ENTRYPOINT ["/usr/local/bin/init.sh"]`

## PHP-FPM

- [ ] runs workers as `www-data`
- [ ] listens on `0.0.0.0:9000`
- [ ] understand why not `127.0.0.1`
- [ ] `php-fpm8.2 -t` succeeds

## Runtime initialization

- [ ] `#!/bin/sh`
- [ ] `set -eu`
- [ ] environment variables checked
- [ ] admin username containing `admin` rejected
- [ ] WordPress files copied only when needed
- [ ] MariaDB readiness checked with real SQL query
- [ ] `wp-config.php` created automatically
- [ ] WordPress installed automatically
- [ ] normal user created automatically
- [ ] `chown` runtime files
- [ ] `exec php-fpm8.2 -F`
- [ ] no `tail -f`
- [ ] no `sleep infinity`
- [ ] no `& bash`

## Networking

- [ ] understand Docker network
- [ ] understand Docker DNS
- [ ] MariaDB + WordPress share `inception`
- [ ] DB host is `mariadb`
- [ ] no hard-coded IP
- [ ] MariaDB reachable from WordPress over the Docker network
- [ ] no need to publish port 3306
- [ ] no need to publish port 9000

## Verification

- [ ] `docker compose config`
- [ ] WordPress image builds
- [ ] both containers run
- [ ] `docker network inspect inception` shows both
- [ ] MariaDB client `SELECT 1` works from WordPress
- [ ] PHP mysqli DB test works
- [ ] `wp core is-installed` succeeds
- [ ] `wp user list` shows administrator + normal user
- [ ] administrator username does not contain `admin`
- [ ] PID 1 is PHP-FPM
- [ ] restart does not duplicate users/reinstall destructively

---

# Day 3 minimum win

If you run out of time, prioritize:

```text
1. WordPress image builds from Debian Bookworm
                         ✅

2. PHP-FPM runs as the real foreground process
                         ✅

3. WordPress + MariaDB share the same Docker network
                         ✅

4. WordPress reaches MariaDB using host name `mariadb`
                         ✅

5. `wp core is-installed` succeeds
                         ✅

6. Administrator + normal user are created automatically
                         ✅
```

---

# Final mental model

```text
                 Docker network: inception

┌────────────────────────────────────────────────────┐
│                                                    │
│  WORDPRESS                         MARIADB          │
│                                                    │
│  /var/www/html                                     │
│  WordPress PHP                                     │
│       │                                            │
│       ▼                                            │
│  PHP-FPM                                           │
│  0.0.0.0:9000                                     │
│       │                                            │
│       │ DB host = mariadb                          │
│       │                                            │
│       ├──── Docker DNS ─────► container IP         │
│       │                           │                │
│       └───────────────────────────▼                │
│                              MariaDB :3306         │
│                                                    │
└────────────────────────────────────────────────────┘
```

Later:

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
  │ database connection
  ▼
mariadb:3306
```

The lesson to keep is:

```text
Each container runs one real service.
Initialization prepares state and then execs the real service.
Containers communicate through a private Docker network.
Services use stable names through Docker DNS instead of hard-coded IPs.
```
