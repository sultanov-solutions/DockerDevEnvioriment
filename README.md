# Docker Dev Environment

Локальное окружение разработки на Docker Compose: один Traefik с HTTPS на локальных доменах,
базы и вспомогательные сервисы, готовые образы для PHP, Node, Go, Python и Java.
Каждый проект описывает себя в собственном `compose.yml` и подключается одной строкой.
Запускается одинаково на Linux, macOS и Windows; версии всех образов закреплены.

## Состав

Сервисы:

| Сервис | Версия | Профиль | Адрес |
|---|---|---|---|
| Traefik | 3.7.18 | всегда | `https://traefik.<DOMAIN>/dashboard/` |
| PostgreSQL | 17.12 | `db` | `localhost:5432`, в сети `postgres:5432` |
| Redis | 8.10.3 | `db` | `localhost:6379`, в сети `redis:6379` |
| RedisInsight | 3.8.0 | `db` | `https://redis.<DOMAIN>` |
| MeiliSearch | 1.56.2 | `db` | `https://meilisearch.<DOMAIN>`, в сети `meilisearch:7700` |
| Garage (S3) + WebUI | 2.5.0 / 1.1.0 | `s3` | `https://s3.<DOMAIN>`, `https://garage.<DOMAIN>` |
| Forgejo | 17.0.1 | `git` | `https://git.<DOMAIN>` |
| forgejo-mcp | по digest | `git-mcp` | `https://git.<DOMAIN>/_mcp/<ключ>` |
| Portainer | 2.45.3 LTS | `tools` | `https://portainer.<DOMAIN>` |
| Playwright (Chromium) | 1.65.0 | `tools` | без адреса, `docker compose exec` |

Образы для проектов (сами не запускаются, их используют `compose.yml` проектов):

| Образ | Что внутри | Профиль |
|---|---|---|
| `<проект>-php85` | PHP 8.5.12, nginx, php-fpm, supervisor, composer 2.11.2, swoole 6.2.5, ffmpeg, vips | `php` |
| `<проект>-node` | Node.js 26.13.1 LTS, pnpm 12.18.0, pm2 7.1.2 | `node` |
| `<проект>-go` | Go 1.27.4, air 1.67.4, goravel installer | `go` |
| `<проект>-python` | Python 3.15.2, fastapi 0.162.7, uvicorn 0.54.0 | `python` |
| `<проект>-java` | Temurin 25 LTS, Maven 3.9.16 | `java` |

`<DOMAIN>` по умолчанию `alp`, `<проект>` это `COMPOSE_PROJECT_NAME`, по умолчанию `devkit`.

## Требования

- Docker Engine 25+ и Docker Compose 2.24+ (проверено на Engine 29.9, Compose 5.6).
- Свободные порты 80, 443, 5432, 6379 (меняются в `.env`).
- Для `init.sh`: любой POSIX shell. На Windows: Git Bash, WSL или ручное заполнение `.env`.

## Быстрый старт

```sh
git clone https://github.com/cljamal/DockerDevEnvioriment.git devkit && cd devkit
./init.sh                         # .env с секретами, свободная подсеть, каталоги storage/
docker compose run --rm mkcert    # выпускает сертификат для хостов из mkcert-hosts.txt
docker compose up -d
```

Затем на машине, где открыт браузер:

1. Добавить `storage/Traefik/certs/rootCA.pem` в доверенные корневые сертификаты (Firefox хранит их отдельно от системы).
2. Прописать хосты из `mkcert-hosts.txt` в файл `hosts`: `127.0.0.1`, если Docker на этой же машине, иначе IP машины или виртуалки с Docker.

Проверка: `https://traefik.alp/dashboard/` открывается без предупреждения о сертификате.

Без shell: скопировать `.env.example` в `.env`, заменить каждое `__GENERATE__` своим значением
(`GARAGE_RPC_SECRET`: ровно 64 hex-символа), создать каталог `storage/Traefik/certs`.

## Структура

| Путь | Что это | В git |
|---|---|---|
| `docker-compose.yml` | инфраструктура и сборка образов; под проекты не правится | да |
| `docker-compose.override.yml` | список подключённых проектов | нет |
| `docker-compose.override.example.yml` | образец списка | да |
| `examples/` | образцы `compose.yml` для проектов на каждом рантайме | да |
| `.env` / `.env.example` | настройки и секреты / образец | нет / да |
| `init.sh` | первичная подготовка машины | да |
| `mkcert-hosts.txt` | список хостов для сертификата | да |
| `Containers/` | Dockerfile и конфиги | да |
| `Sites/` | место для проектов по умолчанию (`SITES_PATH`) | нет |
| `storage/` | сертификаты, дампы Postgres, вывод Playwright | нет |

Данные Postgres, Redis, MeiliSearch, Garage, Forgejo, Portainer и кэши сборки лежат
в именованных томах Docker, а не в `storage/`: так они работают одинаково на любой ОС.

## Настройка: `.env`

| Переменная | Назначение |
|---|---|
| `COMPOSE_PROFILES` | какие сервисы поднимать и какие образы собирать, через запятую |
| `DOMAIN` | локальная зона. При смене поправить `mkcert-hosts.txt` и перевыпустить сертификат |
| `HTTP_PORT`, `HTTPS_PORT`, `PGSQL_PORT`, `REDIS_PORT` | порты на хосте |
| `COMPOSE_PROJECT_NAME` | имя окружения строчными буквами: префикс томов, сети, образов и значение метки для Traefik |
| `CONTAINER_PREFIX` | префикс имён контейнеров инфраструктуры (`DEVKIT_REDIS`); пустой, если других стеков на машине нет |
| `SUBNET_PREFIX` | первые два октета подсети `/16`. `init.sh` подбирает свободную. Traefik всегда на `<SUBNET_PREFIX>.0.100` |
| `USER_ID`, `GROUP_ID` | владелец файлов на хосте; от него работает PHP. После смены: `docker compose up -d` |
| `SHARED_GID` | группа-владелец общей папки с кодом (`vboxsf`), иначе равна `GROUP_ID` |
| `SITES_PATH` | папка с проектами, используется в путях `include` |

Изменения в `.env` применяются командой `docker compose up -d`.

## Профили

Профиль включается в `COMPOSE_PROFILES`. Профили сервисов запускают контейнеры,
профили рантаймов только собирают образ.

| Профиль | Что даёт |
|---|---|
| (нет) | traefik |
| `db` | postgres, redis, redisinsight, meilisearch |
| `s3` | garage, garage-webui |
| `git` | forgejo |
| `git-mcp` | forgejo-mcp |
| `tools` | portainer, playwright |
| `php`, `node`, `go`, `python`, `java` | образ соответствующего рантайма |
| `init` | mkcert (только через `docker compose run`) |

## Подключение проекта

Проект подключается своим `compose.yml`. В самом окружении меняется одна строка.

1. Включить профиль рантайма в `COMPOSE_PROFILES` (например, `db,tools,python`).
2. Скопировать образец из `examples/<рантайм>/compose.yml` в корень проекта и заменить в нём `example` на имя проекта.
3. Добавить домен проекта в `mkcert-hosts.txt`, выполнить `docker compose run --rm mkcert`, прописать домен в файл `hosts`.
4. Добавить проект в `docker-compose.override.yml` (создаётся копированием `docker-compose.override.example.yml`; compose подхватывает его сам, без `-f`):

```yaml
include:
  - ${SITES_PATH}/shop/compose.yml
  # - ${SITES_PATH}/blog/compose.yml   # заморожен
```

5. `docker compose up -d`.

Управление: проект включён, пока его строка есть в `include`. Заморозить: закомментировать строку
и выполнить `docker compose up -d --remove-orphans`. Удалить: убрать строку и папку проекта.
Если строка указывает на отсутствующий файл, compose сообщит об этом и не запустится.

### Что должно быть в `compose.yml` проекта

```yaml
services:
  shop:                                        # уникальное имя сервиса
    image: ${COMPOSE_PROJECT_NAME}-python      # образ окружения
    pull_policy: never
    restart: unless-stopped
    working_dir: /app
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    environment:
      DATABASE_URL: postgres://${PGSQL_ROOT_USER}:${PGSQL_ROOT_PASSWORD}@postgres:5432/shop
    volumes:
      - ./:/app                                # путь от папки проекта
      - pip_cache:/root/.cache/pip             # общий кэш окружения
    networks: [local]                          # общая сеть окружения
    labels:
      - "devenv.traefik=${COMPOSE_PROJECT_NAME}"
      - "traefik.http.routers.shop.entrypoints=websecure"
      - "traefik.http.routers.shop.tls=true"
      - "traefik.http.routers.shop.rule=Host(`shop.${DOMAIN}`)"
      - "traefik.http.services.shop.loadbalancer.server.port=8000"
```

- **Пути** считаются от папки проекта, а не от корня окружения.
- **Переменные** из `.env` окружения доступны; `.env` в папке проекта тоже читается.
- **Сеть `local`** и общие тома кэшей (`go_mod`, `go_build`, `maven_m2`, `pip_cache`, `pnpm_store`) объявлены в окружении, повторно объявлять не нужно. Свои тома проект объявляет сам.
- **Имена** сервисов, томов и роутов уникальны среди подключённых проектов.
- **Метка `devenv.traefik=${COMPOSE_PROJECT_NAME}`** обязательна: без неё Traefik контейнер не видит.
- **Сервисы окружения** доступны по именам: `postgres`, `redis`, `meilisearch`, `garage`, `forgejo`.
- **Свой Dockerfile** вместо образа окружения: `build: .` вместо `image` и `pull_policy`.

Сервис проекта управляется обычными командами: `docker compose logs -f shop`, `docker compose exec shop sh`,
`docker compose restart shop`.

### Особенности рантаймов

| Рантайм | Порт в образце | Что учесть |
|---|---|---|
| PHP | 8080 | Код монтируется в `/var/www/html`. Для Laravel/Symfony (корень в `public/`) положить в проект `examples/php/nginx.conf` и раскомментировать его монтирование. Правки кода видны на следующем запросе (`opcache.revalidate_freq=0`). Воркеры очередей и Octane: конфиги supervisor в `/etc/supervisor/custom.d`, перезапуск `docker compose exec <сервис> supervisorctl restart <имя>` |
| Node | 3000 | Dev-сервер должен слушать `0.0.0.0`. `node_modules` держится в томе: симлинки pnpm не работают на общих папках |
| Go | 8000 | Запускается `air`; настройки в `.air.toml` проекта |
| Python | 8000 | Свои зависимости ставить в `.venv` проекта: `python -m venv --system-site-packages .venv` (на общей папке добавить `--copies`), в команде `.venv/bin/python -m uvicorn` |
| Java | 8080 | Запускается `mvn spring-boot:run`; образец на реальном проекте не проверялся |

### Hot reload

WebSocket через Traefik работает без настроек. Dev-сервер должен разрешать свой домен:
`server.allowedHosts` в vite, `allowedDevOrigins` в next.

На общих папках (vboxsf, диск Windows в WSL) события изменения файлов не приходят, нужен режим опроса:
`WATCHPACK_POLLING=true` (next/webpack), `CHOKIDAR_USEPOLLING=true`, `server.watch.usePolling` (vite),
`poll = true` в `.air.toml` (air), `WATCHFILES_FORCE_POLLING=true` (uvicorn).

### Playwright и проектные домены

Чтобы Playwright открывал домен проекта изнутри сети, добавить в `docker-compose.override.yml`:

```yaml
services:
  playwright:
    extra_hosts:
      - "shop.${DOMAIN}:${SUBNET_PREFIX}.0.100"
```

## Сертификаты

- Локальный центр сертификации и сертификат лежат в `storage/Traefik/certs`.
- `rootCA.pem` устанавливается в доверенные на каждой машине, с которой открывают сайты.
- `rootCA-key.pem` никому не передавать: им можно подписать сертификат для любого сайта.
- Перевыпуск после правки `mkcert-hosts.txt`: `docker compose run --rm mkcert`. Traefik подхватит новый сертификат сам, центр сертификации остаётся прежним.
- Wildcard на зону первого уровня (`*.alp`) браузеры не принимают, поэтому хосты перечисляются явно.

## Данные и перенос

Список томов: `docker volume ls`, имя тома: `<COMPOSE_PROJECT_NAME>_<том>`.

Базы надёжнее переносить дампом. Каталог `storage/PgSQL/tmp` виден в контейнере как `/var/tmp-l`:

```sh
docker compose exec postgres sh -c 'pg_dump -U pgsql -Fc shop > /var/tmp-l/shop.dump'
docker compose exec postgres pg_restore -U pgsql -d shop /var/tmp-l/shop.dump
```

Остальные тома: архивом.

```sh
docker run --rm -v devkit_forgejo_data:/v -v "$PWD":/b alpine tar czf /b/forgejo_data.tgz -C /v .
docker run --rm -v devkit_forgejo_data:/v -v "$PWD":/b alpine tar xzf /b/forgejo_data.tgz -C /v
```

Перенос на другую машину: скопировать каталог окружения с `.env` и `docker-compose.override.yml`,
перенести нужные тома, выполнить `docker compose up -d`. Если uid/gid другие:
поправить `USER_ID`, `GROUP_ID`, `SHARED_GID` и выполнить `sudo chown -R <uid>:<gid> storage`.

Полное удаление вместе с данными: `docker compose --profile '*' down -v`.

## Первичная настройка сервисов

**PostgreSQL.** Суперпользователь и пароль: `PGSQL_ROOT_USER`, `PGSQL_ROOT_PASSWORD`.
Файлы `*.sql` и `*.sh` из `storage/PgSQL/init` выполняются один раз, при создании пустой базы.

**Garage.** Один раз назначить раскладку узла, затем создавать ключи и бакеты в `https://garage.<DOMAIN>`:

```sh
docker compose exec garage /garage status                            # взять ID узла
docker compose exec garage /garage layout assign -z dc1 -c 10G <node_id>
docker compose exec garage /garage layout apply --version 1
```

**Forgejo.** Регистрация закрыта, администратор создаётся командой:

```sh
docker compose exec forgejo forgejo admin user create --admin --username <user> --email <email> --random-password
```

**forgejo-mcp.** Создать токен в Forgejo, вписать в `FORGEJOMCP_TOKEN`, добавить профиль `git-mcp`.
Адрес: `https://git.<DOMAIN>/_mcp/<GIT_MCP_PATH_KEY>`.

**Playwright.** `docker compose exec playwright sh`; рабочий каталог `/out` это `storage/Playwright` на хосте.
Chromium и Node в контейнере доверяют локальному центру сертификации, локальные домены ведут на Traefik.
Контейнер запускать после выпуска сертификата.

## Особенности платформ

| Платформа | Что учесть |
|---|---|
| Linux | Работает как есть. Контейнеры Node, Go, Python и Java работают от root: созданные ими файлы в папке проекта принадлежат root |
| Linux в VirtualBox, код на vboxsf | `SHARED_GID` = gid группы `vboxsf` (`init.sh` определяет сам). Нужен режим опроса для hot reload |
| macOS (Docker Desktop) | Работает как есть, включая Apple Silicon: у всех образов есть сборка arm64 |
| Windows | Окружение и код держать внутри WSL, не на диске `C:`. Иначе: медленно, нет симлинков, нужен режим опроса |

## Команды

```sh
docker compose up -d                      # применить изменения compose, .env и Dockerfile
docker compose up -d --remove-orphans     # то же и убрать контейнеры отключённых проектов
docker compose logs -f --tail 100 shop    # логи сервиса
docker compose ps                         # состояние
docker compose config                     # итоговый конфиг со всеми проектами
docker compose down                       # остановить, данные остаются
docker compose exec shop sh               # shell в контейнере
```

## Изоляция от других стеков

Окружение не пересекается с другими compose-проектами и контейнерами на той же машине:

| Ресурс | Как изолирован |
|---|---|
| Контейнеры | имена с префиксом `CONTAINER_PREFIX` (инфраструктура) и `COMPOSE_PROJECT_NAME` (проекты) |
| Тома, образы, сеть | имена с префиксом `COMPOSE_PROJECT_NAME` |
| Подсеть | `init.sh` выбирает `172.x.0.0/16`, не занятую другими сетями Docker |
| Роутинг | Traefik обслуживает только контейнеры с меткой `devenv.traefik=<проект>`. Метки `traefik.enable=true` у контейнеров нет, поэтому чужой Traefik их не подхватывает |
| Порты хоста | единственное, что делится между стеками. `init.sh` предупреждает, если 80, 443, 5432 или 6379 уже опубликованы другим контейнером; порт меняется в `.env` |

При нестандартном `HTTPS_PORT` адреса получают порт: `https://traefik.alp:8443/dashboard/`.

Второй экземпляр окружения на той же машине: другой каталог, другие `COMPOSE_PROJECT_NAME`,
`CONTAINER_PREFIX` и порты; подсеть `init.sh` подберёт сам.

Чего `init.sh` не видит: порты, занятые программами вне Docker, и подсети VPN.
В этих случаях `docker compose up` сообщит об ошибке, значения правятся в `.env`.

## Ограничения

- Только для разработки. Traefik и Portainer имеют доступ к сокету Docker; порты Postgres и Redis открыты на всех интерфейсах, Redis без пароля. Не запускать на машине, доступной из недоверенной сети.
- Системные пакеты образов (`apk`, `apt`) ставятся из репозиториев на момент сборки. Для побитно одинаковых образов на разных машинах собрать один раз и переносить через реестр или `docker save`.
- Образы рантаймов проверяются на актуальность при каждом `docker compose up` (из кэша это секунды; первая сборка PHP занимает несколько минут).
