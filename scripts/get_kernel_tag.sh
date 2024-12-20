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

# Use GitHub APIs to find the right kernel tag to use.
if [[ ! -z "$KERNEL_BUILD_STRING" || ! -z "$KERNEL_VERSION" || ! -z "$KERNEL_COMMIT_SHA" ]]; then
  KERNEL_GIT_TAGS=$(curl -sL "https://github.com/GrapheneOS/kernel_common-${KERNEL_VERSION}/branch_commits/${KERNEL_COMMIT_SHA}" | grep -oP '/tag/\K[^"]\d+')
  for candidate in $KERNEL_GIT_TAGS; do
    if [[ ${candidate} -le ${GOS_BUILD_NUMBER} ]]; then
      if curl -sL "https://api.github.com/repos/GrapheneOS/kernel_manifest-${PIXEL_GENERATION_SOC_CODENAME}/tags" | jq -e ".[] | select(.name == \"$candidate\")" >/dev/null; then
        KERNEL_GIT_TAG=${candidate} && break
      elif [[ -z "${no_manifest_candidate}" ]]; then
        no_manifest_candidate=${candidate} # This tag is not in kernel_manifest. I'll save it as a last resort in case the loop ends without finding anything.
      fi
    fi
  done;
fi

# Couldn't find a proper tag existing in both kernel_common and kernel_manifest. 
# Later, I'll try to clone the manifest anyway (with $GOS_BUILD_NUMBER as tag) and use sed modify the manifest replacing the kernel_common tag with this tag.
[[ ! -z "${no_manifest_candidate}" && -z "${KERNEL_GIT_TAG}" ]] && KERNEL_GIT_TAG=${no_manifest_candidate} 

# Default to GOS_BUILD_NUMBER if nothing better could be found.
[[ -z "${KERNEL_GIT_TAG}" ]] && KERNEL_GIT_TAG=${GOS_BUILD_NUMBER}

# Get the full commit hash and finish.
KERNEL_COMMON_FULL_COMMIT_SHA=$(curl -sL https://api.github.com/repos/GrapheneOS/kernel_common-${KERNEL_VERSION}/commits/${KERNEL_GIT_TAG} | jq -r '.sha')
echo "And the kernel tag is... ${KERNEL_GIT_TAG}!"
rm -rf ${TMP_DIR}