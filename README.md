# Docker Dev Environment

English · [Русский](READMERU.md)

A local development environment on Docker Compose: one Traefik with HTTPS on local domains,
databases and supporting services, and ready-made images for PHP, Node, Go, Python and Java.
Each project describes itself in its own `compose.yml` and is connected with a single line.
It runs the same way on Linux, macOS and Windows; all image versions are pinned.

## What's inside

Services:

| Service | Version | Profile | Address |
|---|---|---|---|
| Traefik | 3.7.18 | always | `https://traefik.<DOMAIN>/dashboard/` |
| PostgreSQL | 17.12 | `db` | `localhost:5432`, inside the network `postgres:5432` |
| Redis | 8.10.3 | `db` | `localhost:6379`, inside the network `redis:6379` |
| RedisInsight | 3.8.0 | `db` | `https://redis.<DOMAIN>` |
| MeiliSearch | 1.56.2 | `db` | `https://meilisearch.<DOMAIN>`, inside the network `meilisearch:7700` |
| Garage (S3) + WebUI | 2.5.0 / 1.1.0 | `s3` | `https://s3.<DOMAIN>`, `https://garage.<DOMAIN>` |
| Forgejo | 17.0.1 | `git` | `https://git.<DOMAIN>` |
| forgejo-mcp | pinned by digest | `git-mcp` | `https://git.<DOMAIN>/_mcp/<key>` |
| Portainer | 2.45.3 LTS | `tools` | `https://portainer.<DOMAIN>` |

Images for projects (they do not run on their own; project `compose.yml` files use them):

| Image | Contents | Profile |
|---|---|---|
| `<project>-php85` | PHP 8.5.12, nginx, php-fpm, supervisor, composer 2.11.2, swoole 6.2.5, ffmpeg, vips | `php` |
| `<project>-node` | Node.js 26.13.1 LTS, pnpm 12.18.0, pm2 7.1.2 | `node` |
| `<project>-go` | Go 1.27.4, air 1.67.4, goravel installer | `go` |
| `<project>-python` | Python 3.15.2, fastapi 0.162.7, uvicorn 0.54.0 | `python` |
| `<project>-java` | Temurin 25 LTS, Maven 3.9.16 | `java` |

`<DOMAIN>` defaults to `alp`; `<project>` is `COMPOSE_PROJECT_NAME`, `devkit` by default.

Every service and image has its own `Containers/<name>/Dockerfile`: the version is set in its `FROM`,
and that is also where a service is extended (packages, configs, plugins). After editing: `docker compose up -d --build`.

## Requirements

- Docker Engine 25+ and Docker Compose 2.24+ (tested on Engine 29.9, Compose 5.6).
- Free ports 80, 443, 5432, 6379 (configurable in `.env`).
- For `init.sh`: any POSIX shell. On Windows: Git Bash, WSL, or fill in `.env` by hand.

## Quick start

```sh
git clone https://github.com/cljamal/DockerDevEnvioriment.git devkit && cd devkit
./init.sh                         # .env with secrets, a free subnet, storage/ directories
docker compose run --rm mkcert    # issues a certificate for the hosts in mkcert-hosts.txt
docker compose up -d
```

Then, on the machine where the browser runs:

1. Add `storage/Traefik/certs/rootCA.pem` to the trusted root certificates (Firefox keeps its own store, separate from the system one).
2. Add the hosts from `mkcert-hosts.txt` to the `hosts` file: `127.0.0.1` if Docker runs on the same machine, otherwise the IP of the machine or VM running Docker.

Check: `https://traefik.alp/dashboard/` opens without a certificate warning.

Without a shell: copy `.env.example` to `.env`, replace every `__GENERATE__` with your own value
(`GARAGE_RPC_SECRET`: exactly 64 hex characters), and create the `storage/Traefik/certs` directory.

## Layout

| Path | What it is | In git |
|---|---|---|
| `docker-compose.yml` | infrastructure and image builds; not edited per project | yes |
| `docker-compose.override.yml` | the list of connected projects | no |
| `docker-compose.override.example.yml` | a sample of that list | yes |
| `examples/` | sample `compose.yml` files for projects on each runtime | yes |
| `.env` / `.env.example` | settings and secrets / sample | no / yes |
| `init.sh` | first-time machine setup | yes |
| `mkcert-hosts.txt` | the list of hosts for the certificate | yes |
| `Containers/` | the Dockerfile of every service and image, configs | yes |
| `Sites/` | default location for projects (`SITES_PATH`) | no |
| `storage/` | certificates, Postgres dumps and init scripts | no |

The data of Postgres, Redis, MeiliSearch, Garage, Forgejo and Portainer, and the build caches, live
in named Docker volumes rather than in `storage/`, so they behave the same on every OS.

## Configuration: `.env`

| Variable | Purpose |
|---|---|
| `COMPOSE_PROFILES` | which services to start and which images to build, comma-separated |
| `DOMAIN` | the local zone. When changing it, update `mkcert-hosts.txt` and reissue the certificate |
| `HTTP_PORT`, `HTTPS_PORT`, `PGSQL_PORT`, `REDIS_PORT` | ports on the host |
| `COMPOSE_PROJECT_NAME` | the environment name, lowercase: prefix for volumes, the network and images, and the value of the Traefik label |
| `CONTAINER_PREFIX` | prefix for infrastructure container names (`DEVKIT_REDIS`); leave empty if there are no other stacks on the machine |
| `SUBNET_PREFIX` | the first two octets of the `/16` subnet. `init.sh` picks a free one. Traefik is always at `<SUBNET_PREFIX>.0.100` |
| `USER_ID`, `GROUP_ID` | the owner of files on the host; PHP runs as this user. After changing: `docker compose up -d` |
| `SHARED_GID` | the group that owns a shared code folder (`vboxsf`); otherwise equal to `GROUP_ID` |
| `SITES_PATH` | the projects folder, used in `include` paths |

Changes to `.env` are applied with `docker compose up -d`.

## Profiles

A profile is enabled by listing it in `COMPOSE_PROFILES`. Service profiles start containers;
runtime profiles only build an image.

| Profile | What it gives |
|---|---|
| (none) | traefik |
| `db` | postgres, redis, redisinsight, meilisearch |
| `s3` | garage, garage-webui |
| `git` | forgejo |
| `git-mcp` | forgejo-mcp |
| `tools` | portainer |
| `php`, `node`, `go`, `python`, `java` | the image of that runtime |
| `init` | mkcert (only through `docker compose run`) |

## Connecting a project

A project is connected through its own `compose.yml`. In the environment itself only one line changes.

1. Enable the runtime profile in `COMPOSE_PROFILES` (for example `db,tools,python`).
2. Copy the sample from `examples/<runtime>/compose.yml` to the project root and replace `example` in it with the project name.
3. Add the project domain to `mkcert-hosts.txt`, run `docker compose run --rm mkcert`, and add the domain to the `hosts` file.
4. Add the project to `docker-compose.override.yml` (create it by copying `docker-compose.override.example.yml`; compose picks it up automatically, no `-f` needed):

```yaml
include:
  - ${SITES_PATH}/shop/compose.yml
  # - ${SITES_PATH}/blog/compose.yml   # frozen
```

5. `docker compose up -d`.

Managing projects: a project is active while its line is in `include`. To freeze it, comment the line out
and run `docker compose up -d --remove-orphans`. To remove it, delete the line and the project folder.
If a line points to a missing file, compose reports it and does not start.

### What a project's `compose.yml` must contain

```yaml
services:
  shop:                                        # a unique service name
    image: ${COMPOSE_PROJECT_NAME}-python      # an environment image
    pull_policy: never
    restart: unless-stopped
    working_dir: /app
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    environment:
      DATABASE_URL: postgres://${PGSQL_ROOT_USER}:${PGSQL_ROOT_PASSWORD}@postgres:5432/shop
    volumes:
      - ./:/app                                # path relative to the project folder
      - pip_cache:/root/.cache/pip             # a shared cache of the environment
    networks: [local]                          # the shared network of the environment
    labels:
      - "devenv.traefik=${COMPOSE_PROJECT_NAME}"
      - "traefik.http.routers.shop.entrypoints=websecure"
      - "traefik.http.routers.shop.tls=true"
      - "traefik.http.routers.shop.rule=Host(`shop.${DOMAIN}`)"
      - "traefik.http.services.shop.loadbalancer.server.port=8000"
```

- **Paths** are resolved from the project folder, not from the environment root.
- **Variables** from the environment's `.env` are available; a `.env` in the project folder is read as well.
- **The `local` network** and the shared cache volumes (`go_mod`, `go_build`, `maven_m2`, `pip_cache`, `pnpm_store`) are declared by the environment and must not be declared again. A project declares its own volumes itself.
- **Names** of services, volumes and routers must be unique across connected projects.
- **The `devenv.traefik=${COMPOSE_PROJECT_NAME}` label** is required: without it Traefik does not see the container.
- **Environment services** are reachable by name: `postgres`, `redis`, `meilisearch`, `garage`, `forgejo`.
- **Your own Dockerfile** instead of an environment image: use `build: .` in place of `image` and `pull_policy`.

A project service is managed with the usual commands: `docker compose logs -f shop`, `docker compose exec shop sh`,
`docker compose restart shop`.

### Runtime notes

| Runtime | Port in the sample | What to keep in mind |
|---|---|---|
| PHP | 8080 | Code is mounted at `/var/www/html`. For Laravel/Symfony (web root in `public/`) put `examples/php/nginx.conf` into the project and uncomment its mount. Code changes are visible on the next request (`opcache.revalidate_freq=0`). Queue workers and Octane: supervisor configs in `/etc/supervisor/custom.d`, restart with `docker compose exec <service> supervisorctl restart <name>` |
| Node | 3000 | The dev server must listen on `0.0.0.0`. `node_modules` is kept in a volume: pnpm symlinks do not work on shared folders |
| Go | 8000 | Started with `air`; settings in the project's `.air.toml` |
| Python | 8000 | Install project dependencies into the project's `.venv`: `python -m venv --system-site-packages .venv` (add `--copies` on a shared folder), and use `.venv/bin/python -m uvicorn` in the command |
| Java | 8080 | Started with `mvn spring-boot:run`; the sample has not been tested on a real project |

### Hot reload

WebSocket through Traefik works without extra settings. The dev server must allow its own domain:
`server.allowedHosts` in vite, `allowedDevOrigins` in next.

On shared folders (vboxsf, a Windows drive in WSL) file change events do not arrive, so polling is needed:
`WATCHPACK_POLLING=true` (next/webpack), `CHOKIDAR_USEPOLLING=true`, `server.watch.usePolling` (vite),
`poll = true` in `.air.toml` (air), `WATCHFILES_FORCE_POLLING=true` (uvicorn).

## Certificates

- The local certificate authority and the certificate are in `storage/Traefik/certs`.
- `rootCA.pem` is installed as trusted on every machine that opens the sites.
- Never share `rootCA-key.pem`: it can sign a certificate for any site.
- Reissue after editing `mkcert-hosts.txt`: `docker compose run --rm mkcert`. Traefik picks up the new certificate on its own; the certificate authority stays the same.
- Browsers do not accept a wildcard for a top-level zone (`*.alp`), so hosts are listed explicitly.

## Data and migration

List of volumes: `docker volume ls`; a volume is named `<COMPOSE_PROJECT_NAME>_<volume>`.

Databases are best moved as dumps. The `storage/PgSQL/tmp` directory is visible in the container as `/var/tmp-l`:

```sh
docker compose exec postgres sh -c 'pg_dump -U pgsql -Fc shop > /var/tmp-l/shop.dump'
docker compose exec postgres pg_restore -U pgsql -d shop /var/tmp-l/shop.dump
```

Other volumes: as an archive.

```sh
docker run --rm -v devkit_forgejo_data:/v -v "$PWD":/b alpine tar czf /b/forgejo_data.tgz -C /v .
docker run --rm -v devkit_forgejo_data:/v -v "$PWD":/b alpine tar xzf /b/forgejo_data.tgz -C /v
```

Moving to another machine: copy the environment directory together with `.env` and `docker-compose.override.yml`,
move the volumes you need, and run `docker compose up -d`. If the uid/gid differ:
update `USER_ID`, `GROUP_ID`, `SHARED_GID` and run `sudo chown -R <uid>:<gid> storage`.

Removing everything including data: `docker compose --profile '*' down -v`.

## First-time service setup

**PostgreSQL.** Superuser and password: `PGSQL_ROOT_USER`, `PGSQL_ROOT_PASSWORD`.
`*.sql` and `*.sh` files from `storage/PgSQL/init` run once, when an empty database is created.

**Garage.** Assign the node layout once, then create keys and buckets at `https://garage.<DOMAIN>`:

```sh
docker compose exec garage /garage status                            # take the node ID
docker compose exec garage /garage layout assign -z dc1 -c 10G <node_id>
docker compose exec garage /garage layout apply --version 1
```

**Forgejo.** Registration is closed; the administrator is created with a command:

```sh
docker compose exec forgejo forgejo admin user create --admin --username <user> --email <email> --random-password
```

**forgejo-mcp.** Create a token in Forgejo, put it into `FORGEJOMCP_TOKEN`, and add the `git-mcp` profile.
Address: `https://git.<DOMAIN>/_mcp/<GIT_MCP_PATH_KEY>`.

## Platform notes

| Platform | What to keep in mind |
|---|---|
| Linux | Works as is. Node, Go, Python and Java containers run as root: files they create in the project folder are owned by root |
| Linux in VirtualBox, code on vboxsf | `SHARED_GID` = the gid of the `vboxsf` group (`init.sh` detects it). Hot reload needs polling |
| macOS (Docker Desktop) | Works as is, including Apple Silicon: every image has an arm64 build |
| Windows | Keep the environment and the code inside WSL, not on the `C:` drive. Otherwise: slow, no symlinks, polling required |

## Commands

```sh
docker compose up -d                      # apply changes to compose and .env
docker compose up -d --build              # same, and rebuild images after editing a Dockerfile
docker compose up -d --remove-orphans     # same, and remove containers of disconnected projects
docker compose logs -f --tail 100 shop    # service logs
docker compose ps                         # status
docker compose config                     # the resulting config with all projects
docker compose down                       # stop; data is kept
docker compose exec shop sh               # a shell in the container
```

## Isolation from other stacks

The environment does not overlap with other compose projects and containers on the same machine:

| Resource | How it is isolated |
|---|---|
| Containers | names prefixed with `CONTAINER_PREFIX` (infrastructure) and `COMPOSE_PROJECT_NAME` (projects) |
| Volumes, images, network | names prefixed with `COMPOSE_PROJECT_NAME` |
| Subnet | `init.sh` picks a `172.x.0.0/16` that no other Docker network uses |
| Routing | Traefik serves only containers labelled `devenv.traefik=<project>`. The containers carry no `traefik.enable=true` label, so a foreign Traefik does not pick them up |
| Host ports | the only thing shared between stacks. `init.sh` warns if 80, 443, 5432 or 6379 is already published by another container; the port is changed in `.env` |

With a non-default `HTTPS_PORT` the addresses include the port: `https://traefik.alp:8443/dashboard/`.

A second copy of the environment on the same machine: another directory, different `COMPOSE_PROJECT_NAME`,
`CONTAINER_PREFIX` and ports; `init.sh` picks the subnet itself.

What `init.sh` cannot see: ports taken by programs outside Docker, and VPN subnets.
In those cases `docker compose up` reports an error and the values are fixed in `.env`.

## Limitations

- For development only. Traefik and Portainer have access to the Docker socket; the Postgres and Redis ports are open on all interfaces, and Redis has no password. Do not run it on a machine reachable from an untrusted network.
- System packages in the images (`apk`, `apt`) are installed from the repositories at build time. For bit-identical images on different machines, build once and distribute through a registry or `docker save`.
- Runtime images are checked for freshness on every `docker compose up` (seconds from cache; the first PHP build takes several minutes).
