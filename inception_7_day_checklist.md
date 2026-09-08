# Inception — 7-Day Build & Evaluation Checklist

**Week:** Monday 2026-09-07 → Sunday 2026-09-13  
**Strategy:** build one working layer at a time on the laptop, then reproduce and verify it inside the school VM.  
**Rule:** do not create files just because a guide has them. Create each file when you understand the problem it solves.

---

## Evaluation-critical rules to keep visible all week

These are not optional polish. Any one of several of these can end the evaluation immediately.

- [ ] Repository root contains `Makefile`
- [ ] Repository root contains `README.md`
- [ ] Repository root contains `USER_DOC.md`
- [ ] Repository root contains `DEV_DOC.md`
- [ ] All application configuration files are under root-level `srcs/`
- [ ] One non-empty Dockerfile per mandatory service: `nginx`, `wordpress`, `mariadb`
- [ ] Every Dockerfile uses the **penultimate stable Alpine or Debian**
- [ ] Images are built by us; no ready-made NGINX/WordPress/MariaDB service images from Docker Hub
- [ ] Final Docker image names match their service names
- [ ] `docker-compose.yml` contains an explicit Docker network
- [ ] No `network: host`
- [ ] No Compose `links:`
- [ ] No Docker `--link`
- [ ] No `tail -f`, `sleep infinity`, or other fake keep-alive infinite loops
- [ ] No background service tricks such as `nginx & bash`
- [ ] If ENTRYPOINT runs a script, that script eventually runs the real foreground process
- [ ] No passwords, API keys, or credentials committed in Git
- [ ] Real secrets/credentials are kept in an allowed local `.env` and/or Docker secrets, according to the subject/evaluation rules
- [ ] NGINX is the only public entry point and is reachable on **port 443 only**
- [ ] Port 80 / plain HTTP does **not** serve the site
- [ ] TLS 1.2 or TLS 1.3 is demonstrably enabled
- [ ] WordPress Dockerfile does **not** contain NGINX
- [ ] MariaDB Dockerfile does **not** contain NGINX
- [ ] WordPress has persistent storage
- [ ] MariaDB has persistent storage
- [ ] On the school VM, volume inspection shows storage under `/home/<login>/data/`
- [ ] WordPress is already installed/configured; browser never lands on WordPress installation page
- [ ] WordPress administrator username does **not** contain `admin` or `Admin`
- [ ] A normal WordPress user can add a comment
- [ ] Admin can edit a page and the website reflects the change
- [ ] MariaDB is non-empty and I know how to log into it
- [ ] Rebooting the VM and relaunching Compose preserves WordPress + MariaDB data
- [ ] I can change one service configuration/port during evaluation, rebuild, restart, and keep it functional

---

# Day 1 — Monday — 2 hours
## Goal: Build my first MariaDB image and understand every line

### 0. Keep today's scope tiny
- [ ] Create a working folder for today's experiment
- [ ] Do **not** create the full Inception skeleton yet
- [ ] Do **not** start WordPress, NGINX, Compose, or Makefile yet

Suggested temporary structure:

```text
inception/
└── mariadb/
    └── Dockerfile
```

### 1. Understand the minimum MariaDB container problem
- [x] I can explain what MariaDB is in one sentence
- [x] I know which base OS I am choosing: Alpine or Debian
- [x] I check that the final version I use will satisfy the evaluation requirement: **penultimate stable release**
- [x] I understand what `FROM` does
- [x] I understand what `RUN` does
- [ ] I know which package installs MariaDB on my chosen base image

### 2. Write the first Dockerfile myself
- [x] Create `mariadb/Dockerfile`
- [x] Add only the lines I currently understand
- [x] Install MariaDB
- [x] Build the image successfully
- [x] Inspect it with `docker images`
- [x] Start a temporary container if possible
- [ ] Inspect what files/processes MariaDB added

### 3. Learn one thing about container lifetime
- [x] Find the actual MariaDB server process/command
- [ ] Understand why a container exits when its main process exits
- [x] Understand why fake keep-alives such as `tail -f` are forbidden in this project

### Minimum win for today
- [x] **I personally built a MariaDB image**
- [x] **I understand every Dockerfile line currently present**

### Stop here if distracted/tired
Do not compensate by copying a finished MariaDB setup from a guide.

---

# Day 2 — Tuesday — 5 hours
## Goal: Turn MariaDB into a proper self-initializing, persistent service

### 1. Make MariaDB run correctly
- [ ] Make the real MariaDB server run in the foreground
- [ ] Verify the container remains running because MariaDB is running
- [ ] Verify there is no fake keep-alive loop
- [ ] Verify no process is started with `&`

### 2. Understand and create startup initialization
Only create a startup script when I understand why it is needed.

- [ ] Learn what must happen on the **first** MariaDB startup
- [ ] Create the WordPress database
- [ ] Create the WordPress database user
- [ ] Set appropriate permissions
- [ ] Understand root/database credentials
- [ ] Make initialization idempotent: restarting must not destroy/recreate everything incorrectly
- [ ] If using an entrypoint script, ensure it finishes by launching the actual MariaDB foreground process

### 3. Credentials safety
- [ ] Decide how secrets will be supplied in the final project
- [ ] Do not hard-code passwords in the Dockerfile
- [ ] Do not commit real passwords to Git
- [ ] Add the correct secret/local-env files to `.gitignore` if required by the chosen approach
- [ ] Later provide safe templates/placeholders only, if useful

### 4. Learn MariaDB persistence manually first
- [ ] Find MariaDB's data directory
- [ ] Understand why container filesystem data is not sufficient for project persistence
- [ ] Create/test a Docker volume manually
- [ ] Create something in MariaDB
- [ ] Stop/remove the container
- [ ] Start a new container with the same volume
- [ ] Confirm the data remains

### 5. Database inspection
- [ ] Learn the command to enter/log into MariaDB
- [ ] List databases
- [ ] Inspect the WordPress database/user
- [ ] Be able to explain this out loud

### Minimum win for Tuesday
- [ ] **MariaDB starts correctly**
- [ ] **The WordPress DB/user are created automatically**
- [ ] **Database data survives container replacement**

---

# Day 3 — Wednesday — 5 hours
## Goal: Build WordPress + PHP-FPM and connect it to MariaDB

### 1. Understand the service before building it
- [ ] Explain what WordPress is
- [ ] Explain what PHP-FPM is
- [ ] Explain why WordPress/PHP-FPM is separate from NGINX
- [ ] Remember: WordPress Dockerfile must contain **no NGINX**

### 2. Build the WordPress image
- [ ] Create `wordpress/Dockerfile`
- [ ] Use the same compliant Alpine/Debian strategy
- [ ] Install PHP-FPM and required PHP extensions/tools
- [ ] Obtain/configure WordPress without using a ready-made WordPress service image
- [ ] Make PHP-FPM run as the real foreground process
- [ ] No `tail -f`
- [ ] No `sleep infinity`
- [ ] No `& bash`

### 3. Introduce networking because we now need it
Now there are two services that need to communicate, so networking finally has a purpose.

- [ ] Learn what a Docker network is
- [ ] Create a user-defined Docker network manually OR introduce a minimal Compose file
- [ ] Connect MariaDB and WordPress to the same network
- [ ] Make WordPress reach MariaDB using a service/container name, not a hard-coded IP
- [ ] Be able to explain Docker DNS/service-name resolution simply

### 4. Configure WordPress automatically
- [ ] WordPress receives DB host/name/user/password safely
- [ ] WordPress does not require the browser installation wizard
- [ ] Create the WordPress administrator automatically
- [ ] Admin username does **not** contain `admin` or `Admin`
- [ ] Create at least one normal WordPress user
- [ ] Verify WordPress files/data are stored in a place that can later be mounted persistently

### Minimum win for Wednesday
- [ ] **WordPress/PHP-FPM container runs**
- [ ] **WordPress can talk to MariaDB**
- [ ] **No WordPress installation wizard is needed**

---

# Day 4 — Thursday — flexible 3–4 hours
## Goal: Add NGINX + TLS and reach the site through HTTPS

### 1. Understand the request path
- [ ] Explain this flow:

```text
Browser
  ↓ HTTPS :443
NGINX
  ↓ FastCGI
WordPress / PHP-FPM
  ↓ SQL
MariaDB
```

- [ ] Explain FastCGI at a basic level
- [ ] Explain why NGINX is a separate container

### 2. Build NGINX
- [ ] Create `nginx/Dockerfile`
- [ ] Install/configure NGINX myself
- [ ] Do not use a ready-made NGINX service image
- [ ] Run NGINX as the real foreground process
- [ ] No fake keep-alive

### 3. Configure FastCGI
- [ ] NGINX forwards PHP requests to the WordPress/PHP-FPM service
- [ ] NGINX does not use a hard-coded WordPress container IP
- [ ] Static/WordPress content is served correctly

### 4. Configure TLS
- [ ] Generate/use the certificate required by the subject
- [ ] Configure TLS
- [ ] Explicitly support TLS 1.2 and/or TLS 1.3 as required
- [ ] Site works over HTTPS
- [ ] Plain HTTP/port 80 does not serve the site
- [ ] Only NGINX is externally exposed on 443

### 5. Functional WordPress checks
- [ ] Website displays
- [ ] WordPress installation page does **not** appear
- [ ] Log into WordPress admin dashboard
- [ ] Log into/use normal WordPress user
- [ ] Add a test comment
- [ ] Edit a page as admin
- [ ] Confirm the public page changes

### Minimum win for Thursday
- [ ] **Browser → HTTPS NGINX → PHP-FPM → MariaDB works end to end**

---

# Day 5 — Friday — flexible 3–4 hours
## Goal: Turn working experiments into the exact project structure the evaluator expects

### 1. Create the final repository structure only now
- [ ] Root-level `Makefile`
- [ ] Root-level `README.md`
- [ ] Root-level `USER_DOC.md`
- [ ] Root-level `DEV_DOC.md`
- [ ] Root-level `srcs/`
- [ ] Move all infrastructure configuration under `srcs/`
- [ ] Create final `srcs/docker-compose.yml`
- [ ] Organize each service under `srcs/requirements/...`

Example final direction:

```text
repository/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── docker-compose.yml
    ├── ...
    └── requirements/
        ├── mariadb/
        ├── wordpress/
        └── nginx/
```

### 2. Final Compose requirements
- [ ] Three mandatory services exist
- [ ] Each is built from our Dockerfile
- [ ] Final image name is exactly the corresponding service name
- [ ] Explicit Docker network exists
- [ ] No `network: host`
- [ ] No `links:`
- [ ] No `--link` anywhere
- [ ] NGINX exposes only port 443 externally
- [ ] WordPress is not externally published unnecessarily
- [ ] MariaDB is not externally published unnecessarily
- [ ] Add restart policies if appropriate
- [ ] Add both persistent volumes

### 3. Volume requirements
- [ ] WordPress volume configured
- [ ] MariaDB volume configured
- [ ] Plan final host bind locations under `/home/<login>/data/`
- [ ] Know which directory belongs to WordPress
- [ ] Know which directory belongs to MariaDB

### 4. Makefile
- [ ] `make` sets up/builds the complete infrastructure via Docker Compose
- [ ] No service is secretly started outside Compose
- [ ] Add useful clean/down/rebuild targets only if I understand them
- [ ] Test `make` from a clean-enough state

### 5. README — evaluation gate
The README is mandatory and can stop the evaluation.

- [ ] `README.md` exists at repository root
- [ ] First line follows exactly the required format:
  - `*This project has been created as part of the 42 curriculum by <login...>*`
- [ ] Section: **Description**
- [ ] Section: **Instructions**
- [ ] Section: **Resources**
- [ ] Resources section explains how AI was used

### 6. USER_DOC.md — evaluation gate
- [ ] How to start stack
- [ ] How to stop stack
- [ ] How to access website
- [ ] How to access admin panel
- [ ] How credentials are managed
- [ ] Basic health/check commands

### 7. DEV_DOC.md — evaluation gate
- [ ] Prerequisites
- [ ] Setup
- [ ] Makefile usage
- [ ] Docker Compose commands
- [ ] Data persistence explanation

### Minimum win for Friday
- [ ] **The project now has the evaluator-required structure**
- [ ] **`make` builds/starts the full stack**
- [ ] **Mandatory documentation exists and is non-empty**

---

# Day 6 — Saturday — School VM day
## Goal: Reproduce the project in the actual evaluation environment

### 1. VM setup
- [ ] Create/install the Linux VM on the school computer
- [ ] Use the practical school storage location for the VM
- [ ] A graphical desktop is optional; use it if it helps
- [ ] Install Docker Engine
- [ ] Install Docker Compose plugin
- [ ] Verify Docker works inside the VM

### 2. Evaluation-style repository setup
- [ ] Use `git clone` into an **empty directory**
- [ ] Verify the repository is mine and contains only submitted project files
- [ ] Do not depend on uncommitted laptop-only project files
- [ ] Review any helper/testing scripts so I can explain them

### 3. Prepare required host storage
- [ ] Create the required directories under:

```text
/home/<login>/data/
```

- [ ] WordPress persistent data resolves somewhere under `/home/<login>/data/`
- [ ] MariaDB persistent data resolves somewhere under `/home/<login>/data/`

### 4. Domain/host configuration
- [ ] Configure the VM/host resolution needed for `https://<login>.42.fr`
- [ ] Verify the browser resolves the expected name correctly

### 5. Build from the school VM
- [ ] Run `make`
- [ ] All images build inside the VM
- [ ] `docker compose ps` shows all mandatory containers running
- [ ] `docker images` shows image names matching the service names
- [ ] `docker network ls` shows the project network
- [ ] `docker volume ls` shows both required volumes
- [ ] `docker volume inspect <wordpress-volume>` shows `/home/<login>/data/`
- [ ] `docker volume inspect <mariadb-volume>` shows `/home/<login>/data/`

### 6. Full functional test
- [ ] `https://<login>.42.fr` opens the configured site
- [ ] `http://<login>.42.fr` does not serve it
- [ ] TLS 1.2/1.3 can be demonstrated
- [ ] WordPress installation screen does not appear
- [ ] Admin dashboard works
- [ ] Admin username contains no `admin` / `Admin`
- [ ] Normal user can add a comment
- [ ] Admin can edit a page
- [ ] Change is visible publicly
- [ ] I can enter MariaDB
- [ ] Database is non-empty

### 7. Fix platform-specific problems now
- [ ] Fix Linux/Mac path differences
- [ ] Fix permissions
- [ ] Fix volume ownership
- [ ] Fix hostname/domain issues
- [ ] Fix anything that only appeared outside Docker Desktop

### Minimum win for Saturday
- [ ] **The mandatory project works inside the school VM**

---

# Day 7 — Sunday — Full evaluation rehearsal
## Goal: Make it survive the exact tests in the evaluation sheet

## A. Start from a clean Docker state
Be careful: this destroys Docker containers/images/volumes/networks on the machine.

- [ ] Understand the evaluator cleanup command before using it:

```bash
docker stop $(docker ps -qa)
docker rm $(docker ps -qa)
docker rmi -f $(docker images -qa)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q) 2>/dev/null
```

- [ ] Run the appropriate clean-state rehearsal in the school VM
- [ ] Clone/rebuild only from submitted repository
- [ ] Run `make`
- [ ] Everything rebuilds without manual hidden steps

## B. Static rule audit
### Compose
- [ ] No `network: host`
- [ ] No `links:`
- [ ] Explicit network exists

### Makefile/scripts
- [ ] No `--link`

### Dockerfiles/entrypoints/scripts
- [ ] Correct penultimate Alpine/Debian base
- [ ] No `tail -f`
- [ ] No `sleep infinity`
- [ ] No infinite loops
- [ ] No background-process hacks
- [ ] No `bash`/`sh` used merely to keep a container alive
- [ ] Entrypoint scripts ultimately run the real service correctly

### Git/security
- [ ] Search Git repository for passwords/secrets
- [ ] No real credentials are committed
- [ ] Only allowed local env/secrets mechanism is used

## C. Docker basics defense
Practice explaining each in **simple language**.

- [ ] How Docker works
- [ ] How Docker Compose works
- [ ] Difference between using an image with Compose and without Compose
- [ ] Benefit of Docker compared with a VM
- [ ] Why this project's directory structure is useful
- [ ] What an image is
- [ ] What a container is
- [ ] What a Dockerfile is
- [ ] What a Docker network is
- [ ] Why service-name DNS works

## D. Service evaluation rehearsal
### NGINX
- [ ] Dockerfile exists and is non-empty
- [ ] Container is running
- [ ] Port 80 fails
- [ ] Port 443 succeeds
- [ ] Site is WordPress
- [ ] TLS 1.2/1.3 demonstrated

### WordPress/PHP-FPM
- [ ] Dockerfile exists and is non-empty
- [ ] No NGINX inside
- [ ] Container running
- [ ] Volume inspect shows `/home/<login>/data/`
- [ ] Normal user can comment
- [ ] Admin dashboard login works
- [ ] Admin username has no `admin`
- [ ] Edit page → public site reflects edit

### MariaDB
- [ ] Dockerfile exists and is non-empty
- [ ] No NGINX inside
- [ ] Container running
- [ ] Volume inspect shows `/home/<login>/data/`
- [ ] I can explain exactly how to log into database
- [ ] Database is non-empty

## E. Persistence test — mandatory
- [ ] Make a visible WordPress edit
- [ ] Ensure MariaDB contains the corresponding/current data
- [ ] Reboot the **virtual machine**
- [ ] Start the stack again
- [ ] Website still works
- [ ] WordPress remains configured
- [ ] Previous page edit remains
- [ ] MariaDB data remains

## F. Live configuration modification test — mandatory
The evaluator can ask for a service configuration change.

- [ ] Practice changing one service configuration/port
- [ ] Rebuild the affected service/project
- [ ] Restart correctly
- [ ] Verify it still works after the change
- [ ] Practice reverting the change
- [ ] Be able to explain exactly which file I changed and why

## G. Final documentation gate
- [ ] README exact first line is correct
- [ ] README has Description
- [ ] README has Instructions
- [ ] README has Resources + AI-use explanation
- [ ] `USER_DOC.md` exists and is useful
- [ ] `DEV_DOC.md` exists and is useful
- [ ] All required project config is under `srcs/`
- [ ] Root `Makefile` exists

### Minimum win for Sunday
- [ ] **Clean clone → `make` → working infrastructure**
- [ ] **VM reboot → data survives**
- [ ] **Live config change → rebuild → still works**
- [ ] **I can explain the architecture without reading a script**

---

# My final architecture mental model

```text
School computer
└── Virtual Machine
    └── Docker
        └── Docker Compose
            ├── NGINX
            │   └── public HTTPS :443 + TLS 1.2/1.3
            │
            ├── WordPress + PHP-FPM
            │   └── persistent WordPress volume
            │
            ├── MariaDB
            │   └── persistent database volume
            │
            └── private Docker network
```

Request flow:

```text
Browser
   │
   │ HTTPS :443
   ▼
NGINX
   │
   │ FastCGI
   ▼
WordPress / PHP-FPM
   │
   │ SQL
   ▼
MariaDB
```

Persistent host data on the school VM:

```text
/home/<login>/data/
├── wordpress/   # exact naming can follow our implementation
└── mariadb/
```

---

# When I get stuck

Use this order instead of randomly changing files:

- [ ] Read the exact error
- [ ] Identify which layer failed: build / container startup / network / PHP / DB / TLS / volume
- [ ] Inspect `docker compose ps`
- [ ] Inspect the failing service logs
- [ ] Inspect the Dockerfile/config/script involved
- [ ] Change one thing
- [ ] Rebuild/retest
- [ ] Write down what the bug actually was

**Do not solve problems by adding `sleep infinity`, `tail -f`, background services, host networking, links, or hard-coded IP addresses.**
