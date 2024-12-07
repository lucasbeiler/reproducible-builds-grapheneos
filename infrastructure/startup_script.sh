#!/bin/bash
set -eo pipefail

OUR_NONROOT_USER="strcat" # Trying to match official build
TIMEZONE_TO_SET="America/New_York" # Trying to match official build, because I've looked at some diffs showing EST as timezone somewhere.
BUILD_SCRIPT_PATH="build_gos.sh"
COMPARE_SCRIPT_PATH="compare_gos.sh"

useradd -m -G users,sudo -s /bin/bash ${OUR_NONROOT_USER}
timedatectl set-timezone ${TIMEZONE_TO_SET} 
ln -sf /usr/share/zoneinfo/${TIMEZONE_TO_SET} /etc/localtime
echo "${OUR_NONROOT_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-cloud-init-users

# Install general AOSP build dependencies and diffoscope stuff
apt update
apt install -y git-core git-lfs curl gnupg flex bison build-essential zip curl zlib1g-dev libc6-dev-i386 x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig yarnpkg rsync libncurses5 libncurses5-dev diffutils hostname libssl-dev android-sdk-libsparse-utils 
apt install -y diffoscope p7zip e2fsprogs python3-pip golang binwalk device-tree-compiler

# Install repo
curl -sL --url "https://storage.googleapis.com/git-repo-downloads/repo" --output "/usr/local/bin/repo"
chmod a+rx /usr/local/bin/repo
rm -rf /usr/lib/python3/dist-packages/diffoscope*
pip install diffoscope --break-system-packages

# Download avbtool and unpack_bootimg from AOSP sources
curl -sL --fail https://android.googlesource.com/platform/external/avb/+/master/avbtool.py?format=TEXT | base64 -d | tee /usr/local/bin/avbtool && chmod a+x /usr/local/bin/avbtool
curl -sL --fail https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/main/unpack_bootimg.py?format=TEXT | base64 -d | tee /usr/local/bin/unpack_bootimg && chmod a+x /usr/local/bin/unpack_bootimg

shutdown_afterwards() {
    shutdown -h now
}
trap shutdown_afterwards EXIT # Ensure machine goes away on exit.

## Prepare swapfile
# fallocate -l 12G /swapfile
# chmod 600 /swapfile
# mkswap /swapfile
# swapon /swapfile

# Run scripts as user
cp /home/admin/scripts/${BUILD_SCRIPT_PATH} /home/admin/scripts/${COMPARE_SCRIPT_PATH} /usr/local/bin/
chmod a+x /usr/local/bin/${BUILD_SCRIPT_PATH} /usr/local/bin/${COMPARE_SCRIPT_PATH}
su ${OUR_NONROOT_USER} -c ${BUILD_SCRIPT_PATH}
su ${OUR_NONROOT_USER} -c ${COMPARE_SCRIPT_PATH}
