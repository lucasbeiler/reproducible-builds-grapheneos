#!/bin/bash
set -eo pipefail
## This script:
## 1. Extracts the build string from the official kernel;
## 2. Gets the kernel version and commit hash;
## 3. Finds the latest git tag with a HEAD commit containing the given hash.

# Prepare things.
TMP_DIR=$(mktemp -d)
unzip ~/comparing/official/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip */*boot.img -d "${TMP_DIR}"

# Extract informations from the official kernel build string.
KERNEL_BUILD_STRING=$(strings ${TMP_DIR}/*install*/*boot*.img | grep -m1 -oE '[4-7]\.[0-9]{1,2}\.[0-9]{1,3}+-android[0-9]{1,2}-[0-9]+-g[a-f0-9]+') || echo "Kernel build string extraction returned a non-zero exit code: $?"
KERNEL_VERSION=$(echo "${KERNEL_BUILD_STRING}" | grep -oE '^[4-7]\.[0-9]{1,2}') || echo "Kernel version extraction returned a non-zero exit code: $?"
KERNEL_COMMIT_SHA=$(echo "${KERNEL_BUILD_STRING}" | grep -oE '[a-f0-9]+$')  || echo "Kernel commit SHA extraction returned a non-zero exit code: $?"
KERNEL_BUILD_TIMESTAMP_EPOCH=$(date -d "$(strings ${TMP_DIR}/*install*/*boot*.img | grep -oE -m1 "SMP PREEMPT [A-Za-z]{3} [A-Za-z]{3} [0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC [0-9]{4}$" | sed 's/SMP PREEMPT //g')" +%s) || echo "Kernel build timestamp extraction returned a non-zero exit code: $?"

# Debugging info.
echo "Kernel build string: ${KERNEL_BUILD_STRING}; Kernel version: ${KERNEL_VERSION}; Kernel commit hash: ${KERNEL_COMMIT_SHA}; Kernel build timestamp: ${KERNEL_BUILD_TIMESTAMP_EPOCH}"

# Use GitHub APIs to find the right kernel tag to use.
if [[ ! -z "$KERNEL_BUILD_STRING" || ! -z "$KERNEL_VERSION" || ! -z "$KERNEL_COMMIT_SHA" ]]; then
  KERNEL_GIT_TAGS=$(curl -sL "https://github.com/GrapheneOS/kernel_common-${KERNEL_VERSION}/branch_commits/${KERNEL_COMMIT_SHA}" | grep -oP '/tag/\K[^"]\d+' || echo)
  for candidate in $KERNEL_GIT_TAGS; do
    if [[ ${candidate} -le ${GOS_BUILD_NUMBER} ]]; then
      # OK, the $candidate tag in kernel_common points to the correct HEAD commit. Before chosing it, let's check if the tag also exists in the kernel_manifest repository.
      if curl -sL "https://api.github.com/repos/GrapheneOS/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}/tags" | jq -e ".[] | select(.name == \"$candidate\")" >/dev/null; then
        KERNEL_GIT_TAG=${candidate} && break
      fi
    fi
  done;
fi

# Default to GOS_BUILD_NUMBER if no better option is found.
# Don't worry; this fallback tag may not have the desired HEAD commit, but anyway, setlocalversion will be manipulated to force the use of the $KERNEL_COMMIT_SHA obtained here.
# The build timestamp from $KERNEL_BUILD_TIMESTAMP_EPOCH will also be applied when building the kernel.
# This ensures that the build timestamp and version strings align with the official build even when GrapheneOS' git tags are mistaken.
[[ -z "${KERNEL_GIT_TAG}" ]] && KERNEL_GIT_TAG=${GOS_BUILD_NUMBER}

# Finish.
rm -rf ${TMP_DIR}
echo "And the kernel tag is... ${KERNEL_GIT_TAG}!"