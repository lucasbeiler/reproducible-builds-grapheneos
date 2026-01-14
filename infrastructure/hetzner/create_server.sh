#!/bin/bash
set -euo pipefail
# NOTE: Replace "main_one" with the name of your SSH key as added to Hetzner.

# ~/gos_create_server_secrets.sh exports some secrets. Useful when testing locally. Do not expose it.
# On GitHub Actions, they're already set as secret environment variables.
CURL_OUTPUT="-o /dev/null"
FORCE_REPEAT_IF_ALREADY_REPRODUCED=false
if [[ -f ~/gos_create_server_secrets.sh ]]; then
  source ~/gos_create_server_secrets.sh
  CURL_OUTPUT=""
  FORCE_REPEAT_IF_ALREADY_REPRODUCED=true
fi

cd $(dirname "$(realpath "$0")")


# Need to export these so that envsubst can see them later.
export NONROOT_USER GIT_COOKIES_B64 HETZNER_LOCATION HETZNER_API_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION AWS_BUCKET_NAME GOS_BUILD_NUMBER GOS_BUILD_DATETIME
export STARTUP_SCRIPT_B64=$(cat "./startup_script.sh" | base64 | tr -d '\n')
export DOCKER_COMPOSE_FILE_B64=$(cat "../../docker-compose.yml" | base64 | tr -d '\n')

if ! aws s3api head-bucket --bucket "$AWS_BUCKET_NAME" --region "$AWS_DEFAULT_REGION" >/dev/null 2>&1; then
  if aws s3api create-bucket --bucket "$AWS_BUCKET_NAME" --region "$AWS_DEFAULT_REGION" >/dev/null 2>&1; then
    echo "S3 bucket created successfully: ${AWS_BUCKET_NAME}"
  else
    echo "S3 bucket ${AWS_BUCKET_NAME} does not exist and could not be created. Check your credentials and permissions."
  fi
else
  echo "Good! S3 bucket ${AWS_BUCKET_NAME} exists."
fi

for PIXEL_CODENAME in $PIXEL_CODENAMES; do
  read -r GOS_BUILD_NUMBER GOS_BUILD_DATETIME BUILD_ID _ < <(echo $(curl -sL "https://releases.grapheneos.org/${PIXEL_CODENAME}-alpha"))
  response_status_code=$(curl -sLI -w "%{http_code}" -o /dev/null "https://${AWS_BUCKET_NAME}.s3.${AWS_DEFAULT_REGION}.amazonaws.com/${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.html")

  # Check if $ARBITRARY_GOS_BUILD_NUMBER is set and that the release really does exist.
  if [ -n "${ARBITRARY_GOS_BUILD_NUMBER+x}" ]; then
    if ! curl -fsLI --url "https://releases.grapheneos.org/${PIXEL_CODENAME}-install-${ARBITRARY_GOS_BUILD_NUMBER}.zip" > /dev/null; then
      echo "${PIXEL_CODENAME}-install-${ARBITRARY_GOS_BUILD_NUMBER}.zip does not exist anymore on releases.grapheneos.org."
      exit 1
    fi
  else
    echo "Fine. \$ARBITRARY_GOS_BUILD_NUMBER is not set or is empty. The latest release will be automatically reproduced."
  fi

  if [[ "$response_status_code" -ge 400 && "$response_status_code" -lt 500 || $FORCE_REPEAT_IF_ALREADY_REPRODUCED == true ]]; then
    export GOS_BUILD_NUMBER=${ARBITRARY_GOS_BUILD_NUMBER:-$GOS_BUILD_NUMBER}
    export PIXEL_CODENAME GOS_BUILD_DATETIME
    USER_DATA=$(envsubst < cloud-config.tpl.yaml | awk '{printf "%s\\n", $0}')
    echo "DEBUG: Cloud-init userdata size: $(echo ${USER_DATA} | wc --bytes) bytes (limit: $(( 32*1024 )) bytes)"

    SERVER_ID=$(curl -sL -H "Authorization: Bearer $HETZNER_API_TOKEN" --url "https://api.hetzner.cloud/v1/servers" | jq ".servers[] | select(.labels.pixel_codename == \"${PIXEL_CODENAME}\" and .labels.gos_build_number == \"${GOS_BUILD_NUMBER}\") | .id")
    [[ ! -z "${SERVER_ID}" ]] && echo "A machine for ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER} already exists!" && continue

    curl -sL ${CURL_OUTPUT} \
        -X POST \
        -H "Authorization: Bearer $HETZNER_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"user_data\":\"$USER_DATA\",\"ssh_keys\":[\"main_one\"],\"image\":\"fedora-42\",\"location\":\"${HETZNER_LOCATION}\",\"labels\":{\"can_be_deleted_by_actions_job\":\"sure\",\"pixel_codename\":\"$PIXEL_CODENAME\",\"gos_build_number\":\"$GOS_BUILD_NUMBER\"},\"name\":\"m-$(date +%s)\",\"public_net\":{\"enable_ipv4\":true,\"enable_ipv6\":true},\"server_type\":\"cpx62\",\"start_after_create\":true}" \
        "https://api.hetzner.cloud/v1/servers"
    echo "Created machine for ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}!"
  else
   echo "Already reproduced ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}!"
  fi
done;
