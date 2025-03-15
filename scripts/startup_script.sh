#!/bin/bash
set -eo pipefail
source /etc/profile.d/custom_common_variables.sh

# Uncompress my scripts, which I had to compress due to cloud-init's 32KB limit.
gunzip /usr/local/bin/*.gz

finish_script() {
  source /root/.sensitive_vars
  su ${NONROOT_USER} -c "mkdir -p ~/comparing/operation_outputs/"
  cat /var/log/cloud-init-output.log | gzip > /home/${NONROOT_USER}/comparing/operation_outputs/debug-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt
  HTML_OUTPUT_FILE="/home/${NONROOT_USER}/comparing/operation_outputs/${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.html"
  [[ ! -f "$HTML_OUTPUT_FILE" ]] && echo "If you're reading this, the ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER} test failed. Check the logs, fix the issue, and rerun ${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}." > ${HTML_OUTPUT_FILE}

  # Delete old debug files and upload the new ones.
  aws s3 rm s3://${AWS_BUCKET_NAME}/ --recursive --exclude "*" --include "debug*.txt"
  aws s3 mv /home/${NONROOT_USER}/comparing/operation_outputs/ s3://${AWS_BUCKET_NAME}/ --recursive --exclude "*" --include "debug*.txt" --region ${AWS_DEFAULT_REGION}

  # Upload comparison output to AWS S3.
  aws s3 mv /home/${NONROOT_USER}/comparing/operation_outputs/ s3://${AWS_BUCKET_NAME}/ --recursive --exclude "*" --include "*.html" --include "*.txt" --region ${AWS_DEFAULT_REGION} --acl public-read
  echo "[INFO] Done!"
  
  # Delete the server.
  server_id="$(curl -sL http://169.254.169.254/hetzner/v1/metadata/instance-id)"
  curl -sL --fail -X DELETE -H "Authorization: Bearer $HETZNER_API_TOKEN" --url "https://api.hetzner.cloud/v1/servers/${server_id}"
}
trap finish_script EXIT

# Install general AOSP build dependencies and diffoscope stuff.
# NOTE: Yes, mixing packages from bookworm and sid is not good, but I need a lot of newer packages (diffoscope-related, mostly), and Debian 13 isn't out yet, so Hetzner doesn't have images for it.
# ... I'll migrate most things to Docker soon, so I'll be able to have way better version handling.
apt update
apt install -y git git-lfs jq gnupg flex bison build-essential zip zlib1g-dev libc6-dev-i386 x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig yarnpkg rsync libncurses5 libncurses5-dev diffutils hostname libssl-dev 
echo "deb http://deb.debian.org/debian/ sid main" > /etc/apt/sources.list.d/sid.list
apt update
apt --install-recommends install -t sid -y 7zip dexdump diffoscope apksigcopier apksigner apktool python3-protobuf e2fsprogs golang binwalk device-tree-compiler awscli liblzma-dev lz4 binutils-aarch64-linux-gnu xxd android-sdk-libsparse-utils erofs-utils

# Install repo.
curl -sL --url "https://storage.googleapis.com/git-repo-downloads/repo" --output "/usr/local/bin/repo"
chmod a+rx /usr/local/bin/repo

# Download some scripts and tools from AOSP sources.
curl -sL --fail https://android.googlesource.com/platform/external/avb/+/master/avbtool.py?format=TEXT | base64 -d > /usr/local/bin/avbtool && chmod a+x /usr/local/bin/avbtool
curl -sL --fail https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/main/unpack_bootimg.py?format=TEXT | base64 -d > /usr/local/bin/unpack_bootimg && chmod a+x /usr/local/bin/unpack_bootimg
curl -sL --fail https://android.googlesource.com/platform/system/update_engine/+/master/scripts/update_metadata_pb2.py?format=TEXT | base64 -d > /usr/local/bin/update_metadata_pb2.py

## Prepare swapfile.
fallocate -l 18G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Run scripts as user.
su ${NONROOT_USER} -c "build_gos"
su ${NONROOT_USER} -c "compare_gos"
