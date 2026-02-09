#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   SUPABASE_ACCESS_TOKEN=... SUPABASE_PROJECT_REF=... ./scripts/supabase_cli_connect.sh
# Optional:
#   SUPABASE_DB_PASSWORD=... SUPABASE_PUSH=1 ./scripts/supabase_cli_connect.sh

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Missing SUPABASE_ACCESS_TOKEN"
  echo "Create one in Supabase Dashboard -> Account -> Access Tokens"
  exit 1
fi

if [[ -z "${SUPABASE_PROJECT_REF:-}" ]]; then
  echo "Missing SUPABASE_PROJECT_REF"
  echo "Example format: abcdefghijklmnopqrs"
  exit 1
fi

echo "Logging in Supabase CLI profile..."
supabase login --token "${SUPABASE_ACCESS_TOKEN}"

echo "Linking local repo to project ${SUPABASE_PROJECT_REF}..."
if [[ -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
  supabase link \
    --project-ref "${SUPABASE_PROJECT_REF}" \
    --password "${SUPABASE_DB_PASSWORD}" \
    --yes
else
  supabase link \
    --project-ref "${SUPABASE_PROJECT_REF}" \
    --yes
fi

if [[ "${SUPABASE_PUSH:-0}" == "1" ]]; then
  echo "Pushing migrations to remote..."
  supabase db push --yes
fi

echo "Done."
