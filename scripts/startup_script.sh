#!/bin/bash
set -eo pipefail
source /root/.bashrc
trap delete_server EXIT

OUR_NONROOT_USER="strcat" # Trying to match official build
TIMEZONE_TO_SET="America/New_York" # Trying to match official build, because I've seen some diffs showing EST vs. UTC before.
BUILD_SCRIPT_PATH="build_gos"
COMPARE_SCRIPT_PATH="compare_gos"

useradd -m -G users -s /bin/bash ${OUR_NONROOT_USER}
timedatectl set-timezone ${TIMEZONE_TO_SET} 
ln -sf /usr/share/zoneinfo/${TIMEZONE_TO_SET} /etc/localtime

# Install general AOSP build dependencies and diffoscope stuff
apt update
apt install -y git git-lfs jq gnupg flex bison build-essential zip zlib1g-dev libc6-dev-i386 x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig yarnpkg rsync libncurses5 libncurses5-dev diffutils hostname libssl-dev 
apt --install-recommends install -y diffoscope e2fsprogs python3-pip golang binwalk device-tree-compiler awscli liblzma-dev lz4 binutils-aarch64-linux-gnu p7zip-full xxd android-sdk-libsparse-utils 

# Install repo
curl -sL --url "https://storage.googleapis.com/git-repo-downloads/repo" --output "/usr/local/bin/repo"
chmod a+rx /usr/local/bin/repo

# Download avbtool and unpack_bootimg from AOSP sources
curl -sL --fail https://android.googlesource.com/platform/external/avb/+/master/avbtool.py?format=TEXT | base64 -d > /usr/local/bin/avbtool && chmod a+x /usr/local/bin/avbtool
curl -sL --fail https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/main/unpack_bootimg.py?format=TEXT | base64 -d > /usr/local/bin/unpack_bootimg && chmod a+x /usr/local/bin/unpack_bootimg

## Prepare swapfile
fallocate -l 18G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Run scripts as user
su ${OUR_NONROOT_USER} -c ${BUILD_SCRIPT_PATH}
su ${OUR_NONROOT_USER} -c ${COMPARE_SCRIPT_PATH}

# Upload diffoscope output to s3
cat /var/log/cloud-init-output.log > /home/${OUR_NONROOT_USER}/comparing/diffoscope_outputs/cloud-init-output-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt
aws s3 mv /home/${OUR_NONROOT_USER}/comparing/diffoscope_outputs/ s3://${AWS_BUCKET_NAME}/ --recursive --exclude "*" --include "*.html" --include "*.txt" --include "*.checksums" --region ${AWS_DEFAULT_REGION} --acl public-read
echo "[INFO] Done!"
