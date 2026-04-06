#!/usr/bin/env bash
set -euo pipefail

# Deploy the edge functions that must bypass gateway JWT verification because
# they verify the Supabase user token inside the function via auth.getUser().
#
# Usage:
#   SUPABASE_ACCESS_TOKEN=... ./scripts/deploy_supabase_edge_functions.sh
# Optional:
#   SUPABASE_PROJECT_REF=... ./scripts/deploy_supabase_edge_functions.sh

PROJECT_REF="${SUPABASE_PROJECT_REF:-jfegfylztwwdttoufhua}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Missing SUPABASE_ACCESS_TOKEN"
  echo "Create one in Supabase Dashboard -> Account -> Access Tokens"
  exit 1
fi

echo "Logging in Supabase CLI..."
supabase login --token "${SUPABASE_ACCESS_TOKEN}"

echo "Deploying generate-wordlist without gateway JWT verification..."
supabase functions deploy generate-wordlist \
  --project-ref "${PROJECT_REF}" \
  --no-verify-jwt

echo "Deploying verify-premium without gateway JWT verification..."
supabase functions deploy verify-premium \
  --project-ref "${PROJECT_REF}" \
  --no-verify-jwt

echo "Done."
