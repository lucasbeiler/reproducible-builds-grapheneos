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

# Extract informations from the official microdroid kernel build string.
MICRODROID_KERNEL_BUILD_STRING=$(strings ${TMP_DIR}/*install*/super*.img | grep -oE '[4-7]\.[0-9]{1,2}\.[0-9]{1,3}+-android[0-9]{1,2}-[0-9]+-g[a-f0-9]+' | grep -v "${KERNEL_BUILD_STRING}" | sort | uniq -c | sort -nr | head -n 1 | awk '{print $2}') || echo "[DEBUG] Microdroid kernel build string extraction returned a non-zero exit code: $?"
MICRODROID_KERNEL_VERSION=$(echo "${MICRODROID_KERNEL_BUILD_STRING}" | grep -oE '^[4-7]\.[0-9]{1,2}') || echo "[DEBUG] Microdroid kernel version extraction returned a non-zero exit code: $?"
MICRODROID_KERNEL_COMMIT_SHA=$(echo "${MICRODROID_KERNEL_BUILD_STRING}" | grep -oE '[a-f0-9]+$')  || echo "[DEBUG] Microdroid kernel commit SHA extraction returned a non-zero exit code: $?"
MICRODROID_KERNEL_BUILD_TIMESTAMP_EPOCH=$(date -d "$(strings ${TMP_DIR}/*install*/super*.img | grep $MICRODROID_KERNEL_BUILD_STRING | grep -m1 -oP '\b\w{3} \w{3}\s+\d+ \d{2}:\d{2}:\d{2} UTC \d{4}')" +%s) || echo "[DEBUG] Microdroid kernel build timestamp extraction returned a non-zero exit code: $?"

# Make sure that BUILD_DATETIME is right for this official release (useful when building older releases).
GOS_BUILD_DATETIME=$(strings ${TMP_DIR}/*install*/super*.img | grep -oP 'ro.build.date.utc=\K\d+' | head -n1) || echo "[DEBUG] BUILD_DATETIME extraction returned a non-zero exit code: $?"

# Get the current security patch level.
GOS_BUILD_SPL=$(strings ${TMP_DIR}/*install*/super*.img | grep -oP 'ro.build.version.security_patch=\K[0-9-]+' | head -n1 | tr -d '-') || echo "[DEBUG] SPL extraction returned a non-zero exit code: $?"

# Debugging info.
echo "[DEBUG] Information extracted from the official build will be shown below:"
echo "[DEBUG] Kernel build string: ${KERNEL_BUILD_STRING}; Kernel version: ${KERNEL_VERSION}; Kernel commit hash: ${KERNEL_COMMIT_SHA}; Kernel build timestamp: ${KERNEL_BUILD_TIMESTAMP_EPOCH};"
echo "[DEBUG] Microdroid kernel build string: ${MICRODROID_KERNEL_BUILD_STRING}; Kernel version: ${MICRODROID_KERNEL_VERSION}; Kernel commit hash: ${MICRODROID_KERNEL_COMMIT_SHA}; Kernel build timestamp: ${MICRODROID_KERNEL_BUILD_TIMESTAMP_EPOCH};"
echo "[DEBUG] Official build SPL: ${GOS_BUILD_SPL}; Official build DATETIME: ${GOS_BUILD_DATETIME};"

# Finish.
rm -rf ${TMP_DIR}