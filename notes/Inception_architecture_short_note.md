# Inception Architecture — Short Note

## Main architecture

```text
Browser
   ↓ HTTPS :443
NGINX
   ↓ FastCGI :9000
WordPress + PHP-FPM
   ↓ SQL :3306
MariaDB
```

## What each part does

### NGINX
- The **front door** of the website.
- Receives browser requests over **HTTPS on port 443**.
- Handles TLS/HTTPS.
- Does **not** execute PHP itself.
- Sends PHP requests to PHP-FPM.

### WordPress
- The actual **web application**.
- Mostly made of PHP files.
- Contains the logic for posts, login, users, admin pages, comments, etc.

### PHP-FPM
- The program that **runs/executes WordPress PHP code**.
- It waits for requests from NGINX.
- In Inception it listens internally on **port 9000**.

Easy mental model:

```text
WordPress = PHP code
PHP-FPM   = program that executes that PHP code
```

### FastCGI
- The **communication protocol** used between NGINX and PHP-FPM.
- NGINX receives an HTTP/HTTPS request, then sends the PHP job to PHP-FPM using FastCGI.

```text
Browser --HTTPS--> NGINX --FastCGI--> PHP-FPM
```

You do NOT need to know the internal FastCGI protocol yet.

For now remember:

> FastCGI is the language/mechanism NGINX uses to ask PHP-FPM to execute PHP.

### MariaDB
- The **database server**.
- Stores WordPress data such as posts, users, comments, settings, etc.
- WordPress communicates with it using SQL.
- MariaDB normally listens on **port 3306**.

## Ports to remember

```text
443  = Browser → NGINX       (HTTPS)
9000 = NGINX → PHP-FPM       (FastCGI)
3306 = WordPress → MariaDB    (SQL/database)
```

## One complete request

When you open:

```text
https://yourlogin.42.fr
```

the simplified flow is:

1. Browser sends HTTPS request to NGINX on port 443.
2. NGINX receives the request.
3. If PHP needs to run, NGINX sends the request to PHP-FPM on port 9000 using FastCGI.
4. PHP-FPM executes the WordPress PHP code.
5. WordPress may ask MariaDB for data on port 3306.
6. MariaDB returns the data.
7. WordPress/PHP-FPM produces the response.
8. NGINX sends the response back to the browser.

## Why separate services?

This is **separation of concerns**:

- NGINX → web traffic / HTTPS / forwarding
- WordPress + PHP-FPM → application logic / PHP execution
- MariaDB → persistent database data

Each service has one main responsibility.

## The one sentence to remember

> NGINX receives the web request, PHP-FPM runs the WordPress PHP code, and MariaDB stores the WordPress data.
