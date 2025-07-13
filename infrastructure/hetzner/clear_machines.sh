#!/bin/bash
set -euo pipefail

# ~/gos_create_server_secrets.sh exports some secrets. Useful when testing locally. Do not expose it.
# On GitHub Actions, they're already set as secret environment variables.
CURL_OUTPUT="-o /dev/null"
if [[ -f ~/gos_create_server_secrets.sh ]]; then
  source ~/gos_create_server_secrets.sh
  CURL_OUTPUT=""
fi

TIME_THRESHOLD=$((6 * 60 * 60))
CURRENT_TIME=$(date +%s)

# Fetch the server data from Hetzner API and filter servers created more than 6 hours ago
SERVER_IDS=$(curl -sL -H "Authorization: Bearer $HETZNER_API_TOKEN" --url "https://api.hetzner.cloud/v1/servers" | \
  jq -r ".servers[] | select((.created | fromdateiso8601) < ($CURRENT_TIME - $TIME_THRESHOLD) and (.labels.can_be_deleted_by_actions_job == \"sure\")) | .id")

# Delete machines.
for SERVER_ID in $SERVER_IDS; do
  curl -fsL ${CURL_OUTPUT} -X DELETE -H "Authorization: Bearer $HETZNER_API_TOKEN" --url "https://api.hetzner.cloud/v1/servers/${SERVER_ID}" && echo "Deleted machine!"
done;