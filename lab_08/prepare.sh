#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p input loaded rejected drivers
if [ ! -s drivers/postgresql-42.7.8.jar ]; then
    curl --fail --location --retry 3 \
        https://jdbc.postgresql.org/download/postgresql-42.7.8.jar \
        --output drivers/postgresql-42.7.8.jar
fi
docker compose up -d
