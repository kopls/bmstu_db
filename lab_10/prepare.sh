#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
psql -X -v ON_ERROR_STOP=1 -d "${PGDATABASE:-warehouse}" \
    -v grafana_password="${GRAFANA_DB_PASSWORD:-grafana12345}" -f setup.sql
docker compose up -d
