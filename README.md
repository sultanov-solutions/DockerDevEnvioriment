# Docker Dev Environment

Локальное окружение разработки на Docker Compose: один Traefik с HTTPS на локальных доменах,
общие контейнеры под PHP, Node, Go, Java и Python, базы и вспомогательные сервисы.
Запускается одинаково на Linux, macOS и Windows; версии всех образов закреплены.

## Состав

| Сервис | Версия | Профиль | Адрес |
|---|---|---|---|
| Traefik | 3.7.18 | всегда | `https://traefik.<DOMAIN>/dashboard/` |
| PostgreSQL | 17.12 | `db` | `localhost:5432`, в сети `postgres:5432` |
| Redis | 8.10.3 | `db` | `localhost:6379`, в сети `redis:6379` |
| RedisInsight | 3.8.0 | `db` | `https://redis.<DOMAIN>` |
| MeiliSearch | 1.56.2 | `db` | `https://meilisearch.<DOMAIN>` |
| PHP 8.5 + nginx + supervisor | 8.5.12, swoole 6.2.5, composer 2.11.2 | `php` | роуты сайтов |
| Node.js + pm2 + pnpm | 26.13.1 LTS, pm2 7.1.2, pnpm 12.18.0 | `node` | роуты приложений |
| Go + air | 1.27.4, air 1.67.4 | `go` | роуты приложений |
| Java + Maven | Temurin 25 LTS, Maven 3.9.16 | `java` | роуты приложений |
| Python + FastAPI + uvicorn | 3.15.2, fastapi 0.162.7, uvicorn 0.54.0 | `python` | роуты приложений |
| Garage (S3) + WebUI | 2.5.0 / 1.1.0 | `s3` | `https://s3.<DOMAIN>`, `https://garage.<DOMAIN>` |
| Forgejo | 17.0.1 | `git` | `https://git.<DOMAIN>` |
| forgejo-mcp | по digest | `git-mcp` | `https://git.<DOMAIN>/_mcp/<ключ>` |
| Portainer | 2.45.3 LTS | `tools` | `https://portainer.<DOMAIN>` |
| Playwright (Chromium) | 1.65.0 | `tools` | без адреса, `docker compose exec` |

`<DOMAIN>` по умолчанию `alp`.

## Требования

- Docker Engine 25+ и Docker Compose 2.24+ (проверено на Engine 29.9, Compose 5.6).
- Свободные порты 80, 443, 5432, 6379 (меняются в `.env`).
- Для `init.sh`: любой POSIX shell. На Windows: Git Bash, WSL или ручное заполнение `.env`.

## Быстрый старт

```sh
git clone https://github.com/cljamal/DockerDevEnvioriment.git devkit && cd devkit
./init.sh                         # .env с секретами, свободная подсеть, каталоги storage/
docker compose run --rm mkcert    # выпускает сертификат для хостов из mkcert-hosts.txt
docker compose up -d --build
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
| `docker-compose.yml` | общие сервисы; под проекты не правится | да |
| `docker-compose.override.yml` | проектный слой: роуты, тома, свои сервисы | нет |
| `docker-compose.override.example.yml` | образец проектного слоя | да |
| `.env` / `.env.example` | настройки и секреты / образец | нет / да |
| `init.sh` | первичная подготовка машины | да |
| `mkcert-hosts.txt` | список хостов для сертификата | да |
| `Containers/` | Dockerfile и конфиги сервисов | да |
| `Hosts/` | nginx-конфиги PHP-сайтов (`*.conf`) | только `default.conf` |
| `Sites/` | код проектов, в контейнерах это `/var/www` | нет |
| `storage/` | сертификаты, логи PHP, дампы Postgres, вывод Playwright | нет |

Данные Postgres, Redis, MeiliSearch, Garage, Forgejo, Portainer и кэши Go/Maven/pip лежат
в именованных томах Docker, а не в `storage/`: так они работают одинаково на любой ОС.

## Настройка: `.env`

| Переменная | Назначение |
|---|---|
| `COMPOSE_PROFILES` | какие группы сервисов поднимать, через запятую |
| `DOMAIN` | локальная зона. При смене поправить `mkcert-hosts.txt` и перевыпустить сертификат |
| `HTTP_PORT`, `HTTPS_PORT`, `PGSQL_PORT`, `REDIS_PORT` | порты на хосте |
| `COMPOSE_PROJECT_NAME` | имя окружения строчными буквами: префикс томов, сети, образов и значение метки для Traefik |
| `CONTAINER_PREFIX` | префикс имён контейнеров (`DEVKIT_REDIS`); пустой, если других стеков на машине нет |
| `SUBNET_PREFIX` | первые два октета подсети `/16`. `init.sh` подбирает свободную. Traefik всегда на `<SUBNET_PREFIX>.0.100` |
| `USER_ID`, `GROUP_ID` | владелец файлов на хосте. После смены пересобрать `php85` |
| `SHARED_GID` | группа-владелец общей папки (`vboxsf`), иначе равна `GROUP_ID` |
| `SITES_PATH`, `GO_SITES_PATH` | где лежит код |
| `*_CONTAINER_NAME` | полные имена контейнеров. Внутри сети надёжнее обращаться по имени сервиса: `postgres`, `redis`, `garage`, `forgejo`, `meilisearch` |

Изменения в `.env` применяются командой `docker compose up -d`.

## Профили

Сервис запускается, только если его профиль указан в `COMPOSE_PROFILES`.
Разово, не меняя `.env`: `docker compose --profile php up -d`.

| Профиль | Сервисы |
|---|---|
| (нет) | traefik |
| `db` | postgres, redis, redisinsight, meilisearch |
| `php` | php85 |
| `node` | node |
| `go` | go |
| `java` | java |
| `python` | python |
| `s3` | garage, garage-webui |
| `git` | forgejo |
| `git-mcp` | forgejo-mcp |
| `tools` | portainer, playwright |
| `init` | mkcert (только через `docker compose run`) |

## Подключение проектов

Всё проектное пишется в `docker-compose.override.yml`. Compose подхватывает этот файл сам, без `-f`:

```sh
cp docker-compose.override.example.yml docker-compose.override.yml
```

Для любого нового домена:

1. Добавить хост в `mkcert-hosts.txt` и выполнить `docker compose run --rm mkcert`.
2. Добавить хост в файл `hosts` на машине с браузером.
3. Если домен нужен Playwright, добавить его в `extra_hosts` сервиса `playwright` в override.

Роут в Traefik задаётся метками (labels) на контейнере:

- `devenv.traefik=${COMPOSE_PROJECT_NAME}`: без неё Traefik контейнер не видит;
- `traefik.http.routers.<имя>.*` и `traefik.http.services.<имя>.*`: сам роут, `<имя>` уникально в пределах окружения.

Метки читаются при создании контейнера,
поэтому после правки: `docker compose up -d`.

### PHP-сайт (общий контейнер `php85`)

1. Код положить в `Sites/<project>`.
2. Скопировать `Hosts/example.conf.sample` в `Hosts/<host>.conf`, задать свободный порт и `root`.
3. В override добавить роут на этот порт:

```yaml
services:
  php85:
    labels:
      - "devenv.traefik=${COMPOSE_PROJECT_NAME}"
      - "traefik.http.routers.shopApi.service=shopApi"
      - "traefik.http.routers.shopApi.entrypoints=websecure"
      - "traefik.http.routers.shopApi.tls=true"
      - "traefik.http.routers.shopApi.rule=Host(`api.shop.${DOMAIN}`)"
      - "traefik.http.services.shopApi.loadbalancer.server.port=8095"
```

4. `docker compose up -d`. Если менялся только nginx-конфиг: `docker compose exec php85 nginx -s reload`.

Правки PHP-кода видны на следующем запросе (`opcache.revalidate_freq=0`).
Воркеры очередей и Swoole/Octane загружают код один раз: описать их в
`storage/PHP/php85/supervisor/*.conf` и перезапускать через `docker compose exec php85 supervisorctl restart <имя>`.

### Node-приложение (общий контейнер `node`)

1. Код положить в `Sites/<project>`.
2. Описать процесс в `Containers/NodeJS/pm2-loader.cjs` (образец в файле).
3. В override добавить роут на порт приложения и тома под `node_modules` и кэш сборки (образец в `.example`).

`node_modules` и `.next` держатся в томах Docker: симлинки pnpm и turbopack не работают
на общих папках (vboxsf, диск Windows), а на macOS так быстрее.

### Go-приложение (общий контейнер `go`)

В override задать команду и роут; контейнер запускает один проект:

```yaml
services:
  go:
    command: sh -c "cd /var/www/<project> && air"
    labels:
      - "devenv.traefik=${COMPOSE_PROJECT_NAME}"
      - "traefik.http.routers.shopGo.service=shopGo"
      - "traefik.http.routers.shopGo.entrypoints=websecure"
      - "traefik.http.routers.shopGo.tls=true"
      - "traefik.http.routers.shopGo.rule=Host(`go.shop.${DOMAIN}`)"
      - "traefik.http.services.shopGo.loadbalancer.server.port=9222"
```

### Python-приложение (общий контейнер `python`)

В образе уже есть `fastapi` и `uvicorn`. В override задать команду и роут; контейнер запускает один проект:

```yaml
services:
  python:
    command: sh -c "cd /var/www/<project> && uvicorn main:app --host 0.0.0.0 --port 8000 --reload"
    labels:
      - "devenv.traefik=${COMPOSE_PROJECT_NAME}"
      - "traefik.http.routers.shopPy.service=shopPy"
      - "traefik.http.routers.shopPy.entrypoints=websecure"
      - "traefik.http.routers.shopPy.tls=true"
      - "traefik.http.routers.shopPy.rule=Host(`py.shop.${DOMAIN}`)"
      - "traefik.http.services.shopPy.loadbalancer.server.port=8000"
```

Свои зависимости проекта ставятся в `.venv` в его папке, иначе они пропадут при пересоздании контейнера:

```sh
docker compose exec -w /var/www/<project> python python -m venv --system-site-packages .venv
docker compose exec -w /var/www/<project> python .venv/bin/pip install -r requirements.txt
```

После этого в команде вместо `uvicorn` писать `.venv/bin/python -m uvicorn`.
На общей папке без симлинков (vboxsf, диск Windows) добавить к `venv` ключ `--copies`.

### Проект со своим compose-файлом

Проект с собственным контейнером подключается одной строкой в override:

```yaml
include:
  - ${SITES_PATH}/shop/compose.yml
  # - ${SITES_PATH}/blog/compose.yml   # заморожен
```

`Sites/shop/compose.yml`:

```yaml
services:
  shop:
    build: .
    restart: unless-stopped
    environment:
      DATABASE_URL: postgres://${PGSQL_ROOT_USER}:${PGSQL_ROOT_PASSWORD}@postgres:5432/shop
    volumes:
      - ./:/app
      - shop_node_modules:/app/node_modules
    networks: [local]
    labels:
      - "devenv.traefik=${COMPOSE_PROJECT_NAME}"
      - "traefik.http.routers.shop.entrypoints=websecure"
      - "traefik.http.routers.shop.tls=true"
      - "traefik.http.routers.shop.rule=Host(`shop.${DOMAIN}`)"
      - "traefik.http.services.shop.loadbalancer.server.port=3000"

volumes:
  shop_node_modules:
```

- Относительные пути считаются от папки проекта, а не от корня окружения.
- Переменные из основного `.env` доступны; `.env` в папке проекта тоже читается.
- Сеть `local` объявлена в основном файле, повторно её объявлять не нужно.
- Имена сервисов и томов должны быть уникальны между проектами.
- Удалили проект: удалите и строку в `include`, иначе compose сообщит об отсутствующем файле.

### Hot reload

WebSocket через Traefik работает без настроек. Dev-сервер должен слушать `0.0.0.0`
и разрешать свой домен: `server.allowedHosts` в vite, `allowedDevOrigins` в next.

На общих папках (vboxsf, диск Windows в WSL) события изменения файлов не приходят, нужен режим опроса:
`WATCHPACK_POLLING=true` (next/webpack), `CHOKIDAR_USEPOLLING=true`,
`server.watch.usePolling` (vite), `poll = true` в `.air.toml` (air), `WATCHFILES_FORCE_POLLING=true` (uvicorn).

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
перенести нужные тома, выполнить `docker compose up -d --build`. Если uid/gid другие:
поправить `USER_ID`, `GROUP_ID`, `SHARED_GID`, выполнить `sudo chown -R <uid>:<gid> storage` и пересобрать.

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
| Linux | Работает как есть. Контейнеры `node`, `go`, `java`, `python` работают от root: созданные ими файлы в `Sites/` принадлежат root |
| Linux в VirtualBox, код на vboxsf | `SHARED_GID` = gid группы `vboxsf` (`init.sh` определяет сам). Нужен режим опроса для hot reload |
| macOS (Docker Desktop) | Работает как есть, включая Apple Silicon: у всех образов есть сборка arm64 |
| Windows | Окружение и код держать внутри WSL, не на диске `C:`. Иначе: медленно, нет симлинков, нужен режим опроса |

## Команды

```sh
docker compose up -d                      # применить изменения compose и .env
docker compose up -d --build php85        # пересобрать и перезапустить сервис
docker compose logs -f --tail 100 php85   # логи
docker compose ps                         # состояние
docker compose config                     # итоговый конфиг со слитым override
docker compose down                       # остановить, данные остаются
docker compose exec php85 sh              # shell в контейнере
```

## Изоляция от других стеков

Окружение не пересекается с другими compose-проектами и контейнерами на той же машине:

| Ресурс | Как изолирован |
|---|---|
| Контейнеры | имена с префиксом `CONTAINER_PREFIX` |
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
- Одна версия PHP и один набор расширений на все PHP-сайты.
- Системные пакеты образов (`apk`, `apt`) ставятся из репозиториев на момент сборки. Для побитно одинаковых образов на разных машинах собрать один раз и переносить через реестр или `docker save`.

