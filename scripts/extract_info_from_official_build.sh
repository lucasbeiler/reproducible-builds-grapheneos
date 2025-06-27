#!/bin/bash
set -eo pipefail
## This script downloads the official build and extract some useful information from it.
## Additionally, it also uses the official kernel build string to find the right git tag to use.

# Download official builds to /opt/build/grapheneos/comparing/official.
# You can reproduce older build you do these two things:
# 1. Set GOS_BUILD_NUMBER accordingly;
# 2. Place an existing build in the path mentioned below.
if [[ ! -f "/opt/build/grapheneos/comparing/official/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip" ]]; then
  curl -L -o /opt/build/grapheneos/comparing/official/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip https://releases.grapheneos.org/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip
fi

# Prepare things.
TMP_DIR=$(mktemp -d)
unzip /opt/build/grapheneos/comparing/official/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip */*.img -d "${TMP_DIR}"

# Extract informations from the official kernel build string.
KERNEL_BUILD_STRING=$(strings ${TMP_DIR}/*install*/*boot*.img | grep -oE '[4-7]\.[0-9]{1,2}\.[0-9]{1,3}+-android[0-9]{1,2}-[0-9]+-g[a-f0-9]+' | sort | uniq -c | sort -nr | head -n 1 | awk '{print $2}') || echo "[DEBUG] Kernel build string extraction returned a non-zero exit code: $?"
KERNEL_VERSION=$(echo "${KERNEL_BUILD_STRING}" | grep -oE '^[4-7]\.[0-9]{1,2}') || echo "[DEBUG] Kernel version extraction returned a non-zero exit code: $?"
KERNEL_COMMIT_SHA=$(echo "${KERNEL_BUILD_STRING}" | grep -oE '[a-f0-9]+$')  || echo "[DEBUG] Kernel commit SHA extraction returned a non-zero exit code: $?"
KERNEL_BUILD_TIMESTAMP_EPOCH=$(date -d "$(strings ${TMP_DIR}/*install*/*boot*.img | grep -oE -m1 "SMP PREEMPT [A-Za-z]{3} [A-Za-z]{3} [0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC [0-9]{4}$" | sed 's/SMP PREEMPT //g')" +%s) || echo "[DEBUG] Kernel build timestamp extraction returned a non-zero exit code: $?"
NEED_TO_FORCE_BUILD_STRING_AND_TIMESTAMP=true

# Make sure that BUILD_DATETIME is right for this official release (useful when building older releases).
GOS_BUILD_DATETIME=$(strings ${TMP_DIR}/*install*/super*.img | grep -oP 'ro.build.date.utc=\K\d+' | head -n1) || echo "[DEBUG] BUILD_DATETIME extraction returned a non-zero exit code: $?"

# Get the current security patch level.
GOS_BUILD_SPL=$(strings ${TMP_DIR}/*install*/super*.img | grep -oP 'ro.build.version.security_patch=\K[0-9-]+' | head -n1 | tr -d '-') || echo "[DEBUG] SPL extraction returned a non-zero exit code: $?"

# Debugging info.
echo "[DEBUG] Information extracted from the official build will be shown below:"
echo "[DEBUG] Kernel build string: ${KERNEL_BUILD_STRING}; Kernel version: ${KERNEL_VERSION}; Kernel commit hash: ${KERNEL_COMMIT_SHA}; Kernel build timestamp: ${KERNEL_BUILD_TIMESTAMP_EPOCH};"
echo "[DEBUG] Official build SPL: ${GOS_BUILD_SPL}; Official build DATETIME: ${GOS_BUILD_DATETIME};"

# Change some variables for releases based on Android 15 QPR2 or newer.
if [[ "${GOS_BUILD_SPL}" -ge 20250305 ]]; then
  PIXEL_GENERATION_SOC_CODENAME="pixel"
  KERNEL_BUILD_COMMAND="./build_${PIXEL_GENERATION_CODENAME}.sh --config=no_download_gki --config=no_download_gki_fips140 --lto=full"
fi

# Change some variables for releases based on Android 16 or newer.
if [[ "${GOS_BUILD_NUMBER}" -ge 2025061600 ]]; then
 KERNEL_BUILD_COMMAND="./build_${PIXEL_GENERATION_CODENAME}.sh --lto=full" # 2025061600 already includes kernel drivers and build system from Android 16.
fi

# Android 15 QPR2 builds using Android 16 firmware backports require a temporary workaround via adevtool.
if [[ "$GOS_BUILD_NUMBER" -ge 2025061300 && "$GOS_BUILD_NUMBER" -le 2025062700 ]]; then
  export FIRMWARE_DIR="$(mktemp -d)/vendor/google_devices-firmware"
  export DOWNLOAD_DIR="${FIRMWARE_DIR}/../../firmware_download_dir"
  mkdir -p "${DOWNLOAD_DIR}" "${FIRMWARE_DIR}"

  declare -A FIRMWARE_URLS
  FIRMWARE_URLS[tegu]="https://dl.google.com/dl/android/aosp/tegu-bp2a.250605.031.a2-factory-aecd8a3b.zip"
  FIRMWARE_URLS[comet]="https://dl.google.com/dl/android/aosp/comet-bp2a.250605.031.a3-factory-1f6bd727.zip"
  FIRMWARE_URLS[caiman]="https://dl.google.com/dl/android/aosp/caiman-bp2a.250605.031.a2-factory-ff281827.zip"
  FIRMWARE_URLS[komodo]="https://dl.google.com/dl/android/aosp/komodo-bp2a.250605.031.a2-factory-4cd869ec.zip"
  FIRMWARE_URLS[tokay]="https://dl.google.com/dl/android/aosp/tokay-bp2a.250605.031.a2-factory-df553d50.zip"
  FIRMWARE_URLS[akita]="https://dl.google.com/dl/android/aosp/akita-bp2a.250605.031.a2-factory-ee6b1148.zip"
  FIRMWARE_URLS[husky]="https://dl.google.com/dl/android/aosp/husky-bp2a.250605.031.a2-factory-bc412146.zip"
  FIRMWARE_URLS[shiba]="https://dl.google.com/dl/android/aosp/shiba-bp2a.250605.031.a2-factory-4453bca2.zip"
  FIRMWARE_URLS[felix]="https://dl.google.com/dl/android/aosp/felix-bp2a.250605.031.a2-factory-49bbb5b5.zip"
  FIRMWARE_URLS[lynx]="https://dl.google.com/dl/android/aosp/lynx-bp2a.250605.031.a2-factory-4246da73.zip"
  FIRMWARE_URLS[cheetah]="https://dl.google.com/dl/android/aosp/cheetah-bp2a.250605.031.a2-factory-f5e122c5.zip"
  FIRMWARE_URLS[panther]="https://dl.google.com/dl/android/aosp/panther-bp2a.250605.031.a2-factory-53161cbb.zip"
  FIRMWARE_URLS[bluejay]="https://dl.google.com/dl/android/aosp/bluejay-bp2a.250605.031.a2-factory-d7a89215.zip"
  FIRMWARE_URLS[oriole]="https://dl.google.com/dl/android/aosp/oriole-bp2a.250605.031.a2-factory-747402f2.zip"
  FIRMWARE_URLS[raven]="https://dl.google.com/dl/android/aosp/raven-bp2a.250605.031.a2-factory-fdd1008f.zip"

  curl -Lo "${DOWNLOAD_DIR}/official_firmware.zip" --url "${FIRMWARE_URLS[$PIXEL_CODENAME]}"
  unzip -j "${DOWNLOAD_DIR}/official_firmware.zip" '*.img' -d "${FIRMWARE_DIR}"
  rm -rf ${DOWNLOAD_DIR}
  unset DOWNLOAD_DIR && unset FIRMWARE_URLS
fi

# Use GitHub APIs to find the right kernel tag to use.
if [[ ! -z "$KERNEL_BUILD_STRING" || ! -z "$KERNEL_VERSION" || ! -z "$KERNEL_COMMIT_SHA" ]]; then
  KERNEL_GIT_TAGS=$(curl -sL "https://github.com/GrapheneOS/kernel_common-${KERNEL_VERSION}/branch_commits/${KERNEL_COMMIT_SHA}" | grep -oP '/tag/\K[^"]\d+' || echo)
  for candidate in $KERNEL_GIT_TAGS; do
    if [[ ${candidate} -le ${GOS_BUILD_NUMBER} ]]; then
      # OK, the $candidate tag in kernel_common points to the correct HEAD commit. Before chosing it, let's check if the tag also exists in the kernel_manifest repository.
      if curl -sL "https://api.github.com/repos/GrapheneOS/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}/tags" | jq -e ".[] | select(.name == \"$candidate\")" >/dev/null; then
        KERNEL_GIT_TAG=${candidate} && NEED_TO_FORCE_BUILD_STRING_AND_TIMESTAMP=false && break
      fi
    fi
  done;
fi

echo "[DEBUG] Kernel build will use git tag ${KERNEL_GIT_TAG:-$GOS_BUILD_NUMBER} from kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}."

# Finish.
rm -rf ${TMP_DIR}