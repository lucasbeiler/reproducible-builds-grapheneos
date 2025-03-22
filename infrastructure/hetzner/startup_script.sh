#!/bin/bash
set -eo pipefail
source /etc/reproducible-builds-grapheneos.env

finish_script() {
  source /root/.sensitive_vars
  su ${NONROOT_USER} -c "mkdir -p ~/comparing/operation_outputs/"
  uptime --pretty && cat /var/log/cloud-init-output.log | gzip >/home/${NONROOT_USER}/comparing/operation_outputs/machine_log.txt.gz
  HTML_OUTPUT_FILE="/home/${NONROOT_USER}/comparing/operation_outputs/${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.html"
  [[ ! -f "$HTML_OUTPUT_FILE" ]] && echo "If you're reading this, the ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER} test failed. Check the logs, fix the issue, and rerun ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}." > ${HTML_OUTPUT_FILE}

  # Delete old debug files and upload the new ones.
  aws s3 rm s3://${AWS_BUCKET_NAME}/ --recursive --exclude "*" --include "debug*.txt.gz" --include "*_log.*"
  gzip /home/${NONROOT_USER}/comparing/operation_outputs/*_log.txt || :
  aws s3 mv /home/${NONROOT_USER}/comparing/operation_outputs/ s3://${AWS_BUCKET_NAME}/ --recursive --exclude "*" --include "debug*.txt.gz" --include "*_log.*" --region ${AWS_DEFAULT_REGION}

  # Upload comparison output to AWS S3.
  aws s3 mv /home/${NONROOT_USER}/comparing/operation_outputs/ s3://${AWS_BUCKET_NAME}/ --recursive --exclude "*" --include "*.html" --include "*.txt" --region ${AWS_DEFAULT_REGION} --acl public-read
  echo "[INFO] Done!"
  
  # Delete the server.
  server_id="$(curl -sL http://169.254.169.254/hetzner/v1/metadata/instance-id)"
  curl -sL --fail -X DELETE -H "Authorization: Bearer $HETZNER_API_TOKEN" --url "https://api.hetzner.cloud/v1/servers/${server_id}"
}
trap finish_script EXIT

# Install needed packages.
sudo dnf -y install docker-cli docker-compose docker-buildx awscli2 curl git
systemctl enable --now docker
usermod -a -G docker ${NONROOT_USER}

## Prepare swapfile.
fallocate -l 18G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Run reproducible builds tests.
su ${NONROOT_USER} -c "
  # Create necessary directories.
  mkdir -p ~/comparing/operation_outputs/ ~/comparing/official/ ~/comparing/reproduced/ ~/comparing/tools/ &&

  # Build kernel and OS.
  docker-compose -f /etc/docker-compose.reproducible-builds-grapheneos.yml up --abort-on-container-exit build-gos &&

  # Clean up running Docker containers and prune unused Docker objects.
  docker rm -vf \$(docker ps -aq) && \
  docker system prune -a -f --volumes &&

  # Compare GrapheneOS builds (official vs. compared).
  docker-compose -f /etc/docker-compose.reproducible-builds-grapheneos.yml up --abort-on-container-exit compare-gos
"
