#!/bin/bash
set -eo pipefail

# Arguments and variables. Defaults to the alpha channel and to the Google Pixel 8 Pro (husky).
export OFFICIAL_BUILD=true
PIXEL_CODENAME=${1:-husky}
PIXEL_CODENAME_FOR_KERNELS=${2:-shusky}
PIXEL_GENERATION_CODENAME=${3:-zuma}
KERNEL_VERSION="5.15"
YEARQUARTER_KERNEL_NUMBER="24Q3-12357444"
M_BUILD_PARAMS="vendorbootimage vendorkernelbootimage target-files-package otatools-package"
GOS_CHANNEL=alpha

# Initial builder preparation
mkdir -pv ~/.ssh
curl -sL https://grapheneos.org/allowed_signers > ~/.ssh/grapheneos_allowed_signers
git config --global user.name "grapheneos"
git config --global user.email "grapheneos-build@localhost"
git config --global color.ui false

# Read latest release metadata
echo "[INFO] Reading latest release metadata..."
read -r BUILD_NUMBER_FROM_SERVER BUILD_DATETIME_FROM_SERVER BUILD_ID _ < <(echo $(curl -sL "https://releases.grapheneos.org/${PIXEL_CODENAME}-${GOS_CHANNEL}"))

# Get OS source code tree
echo "[INFO] Fetching OS tree..."
mkdir -p ~/grapheneos/grapheneos-${BUILD_NUMBER_FROM_SERVER}
cd ~/grapheneos/grapheneos-${BUILD_NUMBER_FROM_SERVER}
repo init --depth=1 -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/${BUILD_NUMBER_FROM_SERVER}
cd .repo/manifests
git config gpg.ssh.allowedSignersFile ~/.ssh/grapheneos_allowed_signers
git verify-tag $(git describe)
cd ../..
repo sync --fail-fast --force-sync --no-clone-bundle --no-tags

####### Now, let's download vendor blobs and build kernels and apps in order to replace the prebuilts from the GrapheneOS tree.

# Build kernel
echo "[INFO] Building kernel..."
mkdir -p ~/android/kernel/${PIXEL_CODENAME_FOR_KERNELS}
cd ~/android/kernel/${PIXEL_CODENAME_FOR_KERNELS}
repo init --depth=1 -u https://github.com/GrapheneOS/kernel_manifest-${PIXEL_GENERATION_CODENAME}.git -b refs/tags/${BUILD_NUMBER_FROM_SERVER}
repo sync --fail-fast --force-sync --no-clone-bundle --no-tags
./build_${PIXEL_CODENAME_FOR_KERNELS}.sh --config=use_source_tree_aosp --config=no_download_gki --lto=full
cd ~/grapheneos/grapheneos-${BUILD_NUMBER_FROM_SERVER}
#rsync -av --remove-source-files ~/android/kernel/${PIXEL_CODENAME_FOR_KERNELS}/out/${PIXEL_CODENAME_FOR_KERNELS}/dist/ device/google/${PIXEL_CODENAME_FOR_KERNELS}-kernels/${KERNEL_VERSION}/${YEARQUARTER_KERNEL_NUMBER}/
cp ~/android/kernel/${PIXEL_CODENAME_FOR_KERNELS}/out/${PIXEL_CODENAME_FOR_KERNELS}/dist/* device/google/${PIXEL_CODENAME_FOR_KERNELS}-kernels/${KERNEL_VERSION}/${YEARQUARTER_KERNEL_NUMBER}/

# Build kernel for microdroid
echo "[INFO] Building kernel for microdroid pVMs..."
mkdir -p ~/android/kernel/6.6
cd ~/android/kernel/6.6
repo init --depth=1 -u https://github.com/GrapheneOS/kernel_manifest-6.6.git -b refs/tags/${BUILD_NUMBER_FROM_SERVER}
repo sync --fail-fast --force-sync --no-clone-bundle --no-tags
tools/bazel run //common:kernel_aarch64_microdroid_dist --lto=full --config=stamp
cd ~/grapheneos/grapheneos-${BUILD_NUMBER_FROM_SERVER}
cp ~/android/kernel/6.6/out/kernel_aarch64_microdroid/dist/Image packages/modules/Virtualization/microdroid/kernel/android15-6.6/arm64/kernel-6.6
cp ~/android/kernel/6.6/out/kernel_aarch64_microdroid/dist/System.map packages/modules/Virtualization/microdroid/kernel/android15-6.6/arm64/

# Prepare adevtool to fetch vendor blobs
echo "[INFO] Preparing adevtool..."
yarnpkg install --cwd vendor/adevtool/
source build/envsetup.sh
lunch sdk_phone64_x86_64-cur-user
m aapt2 lpunpack
echo "[INFO] Downloading and placing vendor blobs..."
PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin vendor/adevtool/bin/run generate-all -d ${PIXEL_CODENAME}

# Set up build environment for building the base OS and then build it
echo "[INFO] Building GrapheneOS..."
source build/envsetup.sh
export BUILD_DATETIME="$BUILD_DATETIME_FROM_SERVER"
export BUILD_NUMBER="$BUILD_NUMBER_FROM_SERVER"
lunch ${PIXEL_CODENAME}-cur-user
m ${M_BUILD_PARAMS} 

# Generate keys, then generate release package files.
rm -rf keys && mkdir -p keys/${PIXEL_CODENAME}
cd keys/${PIXEL_CODENAME}
CN=GrapheneOS
export password=pass1234
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
. script/finalize.sh
script/generate-release.sh ${PIXEL_CODENAME} ${BUILD_NUMBER}

echo ${BUILD_NUMBER} > ~/.grapheneos_release_build_number
echo ${PIXEL_CODENAME} > ~/.grapheneos_release_device
echo "[INFO] Done!"
