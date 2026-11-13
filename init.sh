#!/bin/sh
# First-time setup on a new machine: .env with secrets and the storage directories.
# Safe to run again: an existing .env is not overwritten.
set -eu
cd "$(dirname "$0")"

if [ ! -f .env ]; then
    # GNU/busybox stat; fails on macOS, then fall back to our own group
    shared_gid=$(stat -c %g . 2>/dev/null || id -g)

    # A subnet no other docker network uses. Go top-down: docker itself allocates bottom-up.
    # shortcut: only 172.x/16 docker networks are compared; VPNs and host routes are not seen,
    # on a clash fix SUBNET_PREFIX in .env by hand.
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
            if (length(secret) != 64) { print "init.sh: failed to generate a secret" > "/dev/stderr"; exit 1 }
            sub(/__GENERATE__$/, secret)
        }
        { print }
    ' .env.example > .env.tmp
    mv .env.tmp .env
    echo "created .env"
fi

umask 022
. ./.env

# Create the directories ourselves: otherwise docker creates them as root.
mkdir -p \
    "$TRAEFIK_STORAGE_PATH/certs" \
    "$PGSQL_STORAGE_PATH/init" "$PGSQL_STORAGE_PATH/tmp" \
    "$SITES_PATH"

# Ports already published by containers of other projects: warn, leave .env alone.
others=$(docker ps --format '{{.Label "com.docker.compose.project"}} {{.Names}} {{.Ports}}' 2>/dev/null | grep -v "^$COMPOSE_PROJECT_NAME " || true)
for var in HTTP_PORT HTTPS_PORT PGSQL_PORT REDIS_PORT; do
    eval "port=\$$var"
    holder=$(printf '%s\n' "$others" | awk -v p=":$port->" 'index($0, p) { print $2; exit }')
    [ -z "$holder" ] || echo "WARNING: port $port is taken by container $holder, change $var in .env"
done

cat <<MSG
done. next:
  docker compose run --rm mkcert      # certificate for the hosts in mkcert-hosts.txt
  docker compose up -d
MSG
