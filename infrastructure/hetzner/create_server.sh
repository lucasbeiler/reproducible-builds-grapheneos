#!/bin/bash
set -euo pipefail

# ~/gos_create_server_secrets.sh exports some secrets. Useful when testing locally. Do not expose it.
# On GitHub Actions, they're already set as secret environment variables.
if [[ -f ~/gos_create_server_secrets.sh ]]; then
  source ~/gos_create_server_secrets.sh
fi

cd $(dirname "$(realpath "$0")")


# TODO: Create the S3 bucket here if it does not exist yet.

export HETZNER_LOCATION HETZNER_API_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION AWS_BUCKET_NAME GOS_BUILD_NUMBER GOS_BUILD_DATETIME
export STARTUP_SCRIPT_B64=$(cat "../../scripts/startup_script.sh" | base64 | tr -d '\n')
export DELETE_SERVER_B64=$(cat "../../scripts/delete_server.sh" | base64 | tr -d '\n')
export BUILD_GOS_B64=$(cat "../../scripts/build_gos.sh" | base64 | tr -d '\n')
export DETECT_DEVICE_B64=$(cat "../../scripts/detect_device.sh" | base64 | tr -d '\n')
export COMPARE_GOS_B64=$(cat "../../scripts/compare_gos.sh" | base64 | tr -d '\n')

for PIXEL_CODENAME in $PIXEL_CODENAMES; do
  read -r GOS_BUILD_NUMBER GOS_BUILD_DATETIME BUILD_ID _ < <(echo $(curl -sL "https://releases.grapheneos.org/${PIXEL_CODENAME}-alpha"))

  response_status_code=$(curl -sLI -w "%{http_code}" -o /dev/null "https://${AWS_BUCKET_NAME}.s3.${AWS_DEFAULT_REGION}.amazonaws.com/${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.html")

  if [[ "$response_status_code" -ge 400 && "$response_status_code" -lt 500 ]]; then
    export PIXEL_CODENAME GOS_BUILD_NUMBER GOS_BUILD_DATETIME  
    USER_DATA=$(envsubst < cloud-config.yaml.tpl | awk '{printf "%s\\n", $0}')

    SERVER_ID=$(curl -sL -H "Authorization: Bearer $HETZNER_API_TOKEN" --url "https://api.hetzner.cloud/v1/servers" | jq ".servers[] | select(.labels.pixel_codename == \"${PIXEL_CODENAME}\" and .labels.gos_build_number == \"${GOS_BUILD_NUMBER}\") | .id")
    [[ ! -z "${SERVER_ID}" ]] && echo "A machine for ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER} already exists!" && continue

    curl -sL -o /dev/null \
        -X POST \
        -H "Authorization: Bearer $HETZNER_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"user_data\":\"$USER_DATA\",\"image\":\"debian-12\",\"location\":\"${HETZNER_LOCATION}\",\"labels\":{\"pixel_codename\":\"$PIXEL_CODENAME\",\"gos_build_number\":\"$GOS_BUILD_NUMBER\"},\"name\":\"m-$(date +%s)\",\"public_net\":{\"enable_ipv4\":true,\"enable_ipv6\":true},\"server_type\":\"cpx51\",\"start_after_create\":true}" \
        "https://api.hetzner.cloud/v1/servers"
    echo "Created machine for ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}!"
  else
    echo "Already reproduced ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}!"
  fi
done;
