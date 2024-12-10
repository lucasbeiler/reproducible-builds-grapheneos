#!/bin/bash
set -euo pipefail
# Script used for the server to delete itself from inside when everything is done (or failed).

server_id="$(curl -sL http://169.254.169.254/hetzner/v1/metadata/instance-id)"
curl -sL --fail -X DELETE -H "Authorization: Bearer $HETZNER_API_TOKEN" --url "https://api.hetzner.cloud/v1/servers/${server_id}"