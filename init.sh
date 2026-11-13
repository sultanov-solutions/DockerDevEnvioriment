#!/bin/sh
# Первичная подготовка на новой машине: .env с секретами и каталоги хранилища.
# Повторный запуск безопасен: существующий .env не перезаписывается.
set -eu
cd "$(dirname "$0")"

if [ ! -f .env ]; then
    # GNU/busybox stat; на macOS падает, тогда берём свою группу
    shared_gid=$(stat -c %g . 2>/dev/null || id -g)

    # Подсеть, не занятая другими сетями docker. Идём сверху вниз: docker сам раздаёт снизу.
    # shortcut: сравниваются только сети 172.x/16 в docker; VPN и маршруты хоста не видны,
    # при пересечении поправить SUBNET_PREFIX в .env вручную.
    used=$(docker network ls -q 2>/dev/null | xargs -r docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null || true)
    subnet=
    for n in 29 30 31 28 27 26 25 24 23 22 21 20; do
        case " $used" in *" 172.$n."*) ;; *) subnet=172.$n; break ;; esac
    done

    umask 077
    awk -v uid="$(id -u)" -v gid="$(id -g)" -v sgid="$shared_gid" -v subnet="$subnet" '
        /^USER_ID=/    { print "USER_ID=" uid; next }
        /^GROUP_ID=/   { print "GROUP_ID=" gid; next }
        /^SHARED_GID=/ { print "SHARED_GID=" sgid; next }
        /^SUBNET_PREFIX=/ && subnet != "" { print "SUBNET_PREFIX=" subnet; next }
        /=__GENERATE__$/ {
            cmd = "head -c 32 /dev/urandom | od -An -tx1 | tr -d \" \\n\""
            secret = ""; cmd | getline secret; close(cmd)
            if (length(secret) != 64) { print "init.sh: не удалось сгенерировать секрет" > "/dev/stderr"; exit 1 }
            sub(/__GENERATE__$/, secret)
        }
        { print }
    ' .env.example > .env.tmp
    mv .env.tmp .env
    echo "создан .env"
fi

umask 022
. ./.env

# Каталоги создаём сами: иначе docker создаст их от root и контейнеры
# с user ${USER_ID} (playwright) не смогут в них писать.
mkdir -p \
    "$TRAEFIK_STORAGE_PATH/certs" \
    "$PGSQL_STORAGE_PATH/init" "$PGSQL_STORAGE_PATH/tmp" \
    "$PLAYWRIGHT_STORAGE_PATH" \
    "$SITES_PATH"

# Порты, уже опубликованные контейнерами других проектов: предупреждаем, .env не трогаем.
others=$(docker ps --format '{{.Label "com.docker.compose.project"}} {{.Names}} {{.Ports}}' 2>/dev/null | grep -v "^$COMPOSE_PROJECT_NAME " || true)
for var in HTTP_PORT HTTPS_PORT PGSQL_PORT REDIS_PORT; do
    eval "port=\$$var"
    holder=$(printf '%s\n' "$others" | awk -v p=":$port->" 'index($0, p) { print $2; exit }')
    [ -z "$holder" ] || echo "ВНИМАНИЕ: порт $port занят контейнером $holder, поменяйте $var в .env"
done

cat <<MSG
готово. дальше:
  docker compose run --rm mkcert      # сертификат для хостов из mkcert-hosts.txt
  docker compose up -d
MSG
