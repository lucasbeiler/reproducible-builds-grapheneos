#!/bin/bash
set -eo pipefail

source /usr/local/bin/detect_device

# TODO: Move download/clone/sync commands to another script.

# Build and install payload-dumper-go. Already preparing this right here so it fails early in case it fails.
git clone https://github.com/ssut/payload-dumper-go ~/payload-dumper-go
cd ~/payload-dumper-go
go build

# Download official builds to ~/comparing/official. Already preparing this right here so it fails early in case it fails.
rm -rf ~/comparing && mkdir -p ~/comparing/official ~/official_incrementals ~/comparing/reproduced ~/comparing/operation_outputs
wget -P ~/comparing/official/ https://releases.grapheneos.org/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip
wget -P ~/comparing/official/ https://releases.grapheneos.org/${PIXEL_CODENAME}-ota_update-${GOS_BUILD_NUMBER}.zip

# TODO: Find a better, parseable way to get a per-device release history.
## .. I use kernel_manifest after noticing that it doesn't tag releases not intended for the repository's device generation.
LAST_THREE_RELEASES=$(curl -sL "https://api.github.com/repos/GrapheneOS/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}/tags" | jq -r '.[].name' | awk "/${GOS_BUILD_NUMBER}/{f=4} f&&f--" | tail -3)
for PAST_RELEASE in $LAST_THREE_RELEASES; do
  wget -P ~/official_incrementals https://releases.grapheneos.org/${PIXEL_CODENAME}-incremental-${PAST_RELEASE}-${GOS_BUILD_NUMBER}.zip || continue
done;

# Initial builder preparation.
export OFFICIAL_BUILD=true
mkdir -pv ~/.ssh
curl -sL https://grapheneos.org/allowed_signers > ~/.ssh/grapheneos_allowed_signers
git config --global user.name "grapheneos"
git config --global user.email "grapheneos-build@localhost"
git config --global color.ui false

# Fetch OS source code tree.
echo "[INFO] Fetching OS tree..."
mkdir -p ~/grapheneos/grapheneos-${GOS_BUILD_NUMBER}
cd ~/grapheneos/grapheneos-${GOS_BUILD_NUMBER}
repo init --depth=1 -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/${GOS_BUILD_NUMBER}
cd .repo/manifests
git config gpg.ssh.allowedSignersFile ~/.ssh/grapheneos_allowed_signers
git verify-tag $(git describe)
cd ../..
repo sync --fail-fast --force-sync --no-clone-bundle --no-tags

# Build kernel.
echo "[INFO] Building kernel (using tag ${KERNEL_GIT_TAG})..."
source /usr/local/bin/get_kernel_tag
mkdir -p ~/android/kernel/${PIXEL_GENERATION_CODENAME}
if curl -sL "https://api.github.com/repos/GrapheneOS/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}/tags" | jq -e ".[] | select(.name == \"$KERNEL_GIT_TAG\")" >/dev/null; then
  cd ~/android/kernel/${PIXEL_GENERATION_CODENAME}
  repo init --depth=1 -u https://github.com/GrapheneOS/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}.git -b refs/tags/${KERNEL_GIT_TAG}
else # When the tag does not exist in the remote kernel_manifest, clone it and use sed to modify it as desired. Note that this is an edge case and should rarely be needed.
  git clone https://github.com/GrapheneOS/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}.git -b ${GOS_BUILD_NUMBER} ~/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}
  cd ~/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}
  sed -i "/name=\"kernel_common/ s/${GOS_BUILD_NUMBER}/${KERNEL_GIT_TAG}/g" *.xml
  sed -i "/name=\"kernel_common-/ s/revision=\"[^\"]*\"/revision=\"${KERNEL_COMMON_FULL_COMMIT_SHA}\"/g" *.xml
  git commit -a --amend --reset-author --no-edit && git tag ${KERNEL_GIT_TAG}
  cd ~/android/kernel/${PIXEL_GENERATION_CODENAME}
  repo init --depth=1 -u ~/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME} -b refs/tags/${KERNEL_GIT_TAG}
fi
repo sync --fail-fast --force-sync --no-clone-bundle --no-tags
${KERNEL_BUILD_COMMAND}
cd ~/grapheneos/grapheneos-${GOS_BUILD_NUMBER}
REAL_KERNEL_PREBUILTS_PATH=$(realpath device/google/${PIXEL_GENERATION_CODENAME}-kernels/*/grapheneos/)
find ${REAL_KERNEL_PREBUILTS_PATH}/ -type f ! -path '*kernel-headers/*' -delete
mv ~/android/kernel/${PIXEL_GENERATION_CODENAME}/out/${PIXEL_GENERATION_CODENAME}/dist/* ${REAL_KERNEL_PREBUILTS_PATH}
rm -rf ~/android/kernel/${PIXEL_GENERATION_CODENAME} ~/kernel_manifest-*

# Build kernel for microdroid.
echo "[INFO] Building kernel for microdroid pVMs..."
mkdir -p ~/android/kernel/6.6
cd ~/android/kernel/6.6
repo init --depth=1 -u https://github.com/GrapheneOS/kernel_manifest-6.6.git -b refs/tags/${GOS_BUILD_NUMBER}
repo sync --fail-fast --force-sync --no-clone-bundle --no-tags
tools/bazel run //common:kernel_aarch64_microdroid_dist --config=stamp --lto=full
cd ~/grapheneos/grapheneos-${GOS_BUILD_NUMBER}
mv ~/android/kernel/6.6/out/kernel_aarch64_microdroid/dist/Image packages/modules/Virtualization/guest/kernel/android15-6.6/arm64/kernel-6.6
mv ~/android/kernel/6.6/out/kernel_aarch64_microdroid/dist/* packages/modules/Virtualization/guest/kernel/android15-6.6/arm64/
rm -rf ~/android/kernel/6.6

# Prepare adevtool to fetch vendor blobs.
echo "[INFO] Preparing adevtool..."
yarnpkg install --cwd vendor/adevtool/
source build/envsetup.sh
lunch sdk_phone64_x86_64-cur-user
m aapt2 lpunpack deapexer
echo "[INFO] Downloading and placing vendor blobs..."
PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin vendor/adevtool/bin/run generate-all -d ${PIXEL_CODENAME}

# Set up build environment for building the base OS and then build it.
echo "[INFO] Building OS..."
source build/envsetup.sh
export BUILD_DATETIME="$GOS_BUILD_DATETIME"
export BUILD_NUMBER="$GOS_BUILD_NUMBER"
lunch ${PIXEL_CODENAME}-cur-user
m ${M_BUILD_PARAMS} 

# Generate keys. Note that these keys are irrelevant because this build will not be used anywhere.
rm -rf keys && mkdir -p keys/${PIXEL_CODENAME}
cd keys/${PIXEL_CODENAME}
CN=$(head /dev/urandom | tr -dc A-Za-z | head -c 8)
export password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
echo ${password} | ../../development/tools/make_key releasekey "/CN=${CN}/" || :
echo ${password} | ../../development/tools/make_key platform "/CN=${CN}/" || :
echo ${password} | ../../development/tools/make_key shared "/CN=${CN}/" || :
echo ${password} | ../../development/tools/make_key media "/CN=${CN}/" || :
echo ${password} | ../../development/tools/make_key networkstack "/CN=${CN}/" || :
echo ${password} | ../../development/tools/make_key sdk_sandbox "/CN=${CN}/" || :
echo ${password} | ../../development/tools/make_key bluetooth "/CN=${CN}/" || :
openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -passout pass:${password}  -out avb.pem
sed -i "s/\['openssl', 'rsa',/\['openssl', 'rsa', '-passin', 'pass:${password}',/" ../../external/avb/avbtool.py # Make it prompt no password
../../external/avb/avbtool.py extract_public_key --key avb.pem --output avb_pkmd.bin
cd ../..
ssh-keygen -t ed25519 -f keys/${PIXEL_CODENAME}/id_ed25519 -N ""

# Prepare ZIP packages.
. script/finalize.sh
script/generate-release.sh ${PIXEL_CODENAME} ${BUILD_NUMBER}

# Done.
echo "[INFO] Finished building!"