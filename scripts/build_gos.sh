#!/bin/bash
set -eo pipefail

# Initial builder preparation.
export OFFICIAL_BUILD=true
mkdir -pv ~/.ssh
curl -sL https://grapheneos.org/allowed_signers > ~/.ssh/grapheneos_allowed_signers
git config --global user.name "grapheneos"
git config --global user.email "grapheneos-build@localhost"
git config --global color.ui false
if [[ -f "/.gitcookies" ]]; then
  git config --global http.cookiefile /.gitcookies
fi

# Fetch OS source code tree.
echo "[INFO] Fetching OS tree..."
mkdir -p /opt/build/grapheneos/grapheneos-${GOS_BUILD_NUMBER}
cd /opt/build/grapheneos/grapheneos-${GOS_BUILD_NUMBER}
repo init --depth=1 -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/${GOS_BUILD_NUMBER}
cd .repo/manifests
git config gpg.ssh.allowedSignersFile ~/.ssh/grapheneos_allowed_signers
git verify-tag $(git describe)
cd ../..
repo sync -j8 --retry-fetches=6 --force-sync --no-clone-bundle --no-tags

# Set device-specific variables. Finally, extract some useful strings from the official build, and detect the right kernel_manifest git tag to use.
source /usr/local/bin/detect_device.sh
source /usr/local/bin/extract_info_from_official_build.sh

# Fetch kernel source code tree.
echo "[INFO] Building kernel (using tag ${KERNEL_GIT_TAG:-$GOS_BUILD_NUMBER})..."
mkdir -p ~/android/kernel/${PIXEL_GENERATION_CODENAME}
cd ~/android/kernel/${PIXEL_GENERATION_CODENAME}
repo init --depth=1 -u https://github.com/GrapheneOS/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}.git -b refs/tags/${KERNEL_GIT_TAG:-$GOS_BUILD_NUMBER}
repo sync -j8 --retry-fetches=6 --force-sync --no-clone-bundle --no-tags

# If needed, force localversion string and build timestamp to values obtained from the official build, in order to workaround some issues.
if [[ "${NEED_TO_FORCE_BUILD_STRING_AND_TIMESTAMP}" == true ]]; then
  echo "[DEBUG] Forcing kernel build localversion string and build timestamp to, respectively: -${KERNEL_BUILD_STRING#*-} and ${KERNEL_BUILD_TIMESTAMP_EPOCH}"
  cd aosp
  echo -e '#!/bin/sh\necho' "-${KERNEL_BUILD_STRING#*-}" > scripts/setlocalversion
  GIT_COMMITTER_DATE=$KERNEL_BUILD_TIMESTAMP_EPOCH GIT_AUTHOR_DATE=$KERNEL_BUILD_TIMESTAMP_EPOCH git commit -a --amend --reset-author --no-edit
  cd ..
else
  echo "[DEBUG] Already have the expected kernel_common commit hash for this build. The expected kernel build string will be naturally produced, matching the official build."
fi

# Build the device kernel and move it into the OS tree.
${KERNEL_BUILD_COMMAND}
cd /opt/build/grapheneos/grapheneos-${GOS_BUILD_NUMBER}
REAL_KERNEL_PREBUILTS_PATH=$(realpath device/google/${PIXEL_GENERATION_CODENAME}-kernels/*/grapheneos/)
find ${REAL_KERNEL_PREBUILTS_PATH}/ -type f ! -path '*kernel-headers/*' -delete
mv ~/android/kernel/${PIXEL_GENERATION_CODENAME}/out/${PIXEL_GENERATION_CODENAME}/dist/* ${REAL_KERNEL_PREBUILTS_PATH}
rm -rf ~/android/kernel/${PIXEL_GENERATION_CODENAME} ~/kernel_manifest-*

# Build microdroid kernel (pretty similar to the kernel build above).
echo "[INFO] Building kernel for microdroid pVMs..."
mkdir -p ~/android/kernel/6.6
cd ~/android/kernel/6.6
repo init --depth=1 -u https://github.com/GrapheneOS/kernel_manifest-6.6.git -b refs/tags/${GOS_BUILD_NUMBER}
repo sync -j8 --retry-fetches=6 --force-sync --no-clone-bundle --no-tags
tools/bazel run //common:kernel_aarch64_microdroid_dist --config=stamp --lto=full
cd /opt/build/grapheneos/grapheneos-${GOS_BUILD_NUMBER}
mv ~/android/kernel/6.6/out/kernel_aarch64_microdroid/dist/Image packages/modules/Virtualization/guest/kernel/android15-6.6/arm64/kernel-6.6
mv ~/android/kernel/6.6/out/kernel_aarch64_microdroid/dist/* packages/modules/Virtualization/guest/kernel/android15-6.6/arm64/
rm -rf ~/android/kernel/6.6

# Export important variables for OS builds.
export BUILD_NUMBER="$GOS_BUILD_NUMBER"
export BUILD_DATETIME="$GOS_BUILD_DATETIME"

# Prepare adevtool to fetch vendor blobs.
echo "[INFO] Preparing adevtool..."
yarnpkg install --cwd vendor/adevtool/
source build/envsetup.sh
lunch sdk_phone64_x86_64-cur-user
m aapt2 lpunpack deapexer dexdump
echo "[INFO] Downloading and placing vendor blobs..."
PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin vendor/adevtool/bin/run generate-all -d ${PIXEL_CODENAME}

# Set up build environment for building the base OS and then build it.
echo "[INFO] Building OS..."
source build/envsetup.sh
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
script/finalize.sh
script/generate-release.sh ${PIXEL_CODENAME} ${GOS_BUILD_NUMBER}

# Save build.
mv /opt/build/grapheneos/grapheneos-${GOS_BUILD_NUMBER}/releases/${GOS_BUILD_NUMBER}/release-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip /opt/build/grapheneos/comparing/reproduced/
mv /opt/build/grapheneos/grapheneos-${GOS_BUILD_NUMBER}/out/host/ /opt/build/grapheneos/comparing/tools/

# Done.
echo "[INFO] Finished building!"