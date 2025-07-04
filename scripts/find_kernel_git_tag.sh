#!/bin/bash
set -eo pipefail

ARG_KERNEL_VERSION="$1"
ARG_KERNEL_COMMIT_SHA="$2"
ARG_GOS_BUILD_NUMBER="$3"
ARG_MANIFEST_REPO_SUFFIX="$4"

export NEED_TO_FORCE_KERNEL_BUILD_STRING_AND_TIMESTAMP=true

if [[ -n "$ARG_KERNEL_COMMIT_SHA" && -n "$ARG_KERNEL_VERSION" ]]; then
  # Try to find git tags containing a commit with $ARG_KERNEL_COMMIT_SHA somewhere.
  KERNEL_GIT_TAGS=$(curl -sL "https://github.com/GrapheneOS/kernel_common-${ARG_KERNEL_VERSION}/branch_commits/${ARG_KERNEL_COMMIT_SHA}" | grep -oP '/tag/\K[^"]\d+' || echo)
  for candidate in $KERNEL_GIT_TAGS; do
    if [[ ${candidate} -le ${ARG_GOS_BUILD_NUMBER} ]]; then
      # OK, the $candidate tag has that commit somewhere, now let's check that it is actually its HEAD commit.
      if curl -sL "https://api.github.com/repos/GrapheneOS/kernel_common-${ARG_KERNEL_VERSION}/tags" | jq -e --arg tag "$candidate" --arg sha "$ARG_KERNEL_COMMIT_SHA" '.[] | select(.name == $tag and (.commit.sha | startswith($sha)))' >/dev/null; then
        # OK, the $candidate tag in kernel_common points to the correct HEAD commit. Before choosing it, let's check if the tag also exists in the kernel_manifest repository.
        if curl -sL "https://api.github.com/repos/GrapheneOS/kernel_manifest-${ARG_MANIFEST_REPO_SUFFIX}/tags" | jq -e ".[] | select(.name == \"$candidate\")" >/dev/null; then
          export KERNEL_GIT_TAG=${candidate} && export NEED_TO_FORCE_KERNEL_BUILD_STRING_AND_TIMESTAMP=false && break
        fi
      fi
    fi
  done;
fi
echo "[DEBUG] Kernel build will use git tag ${KERNEL_GIT_TAG:-$ARG_GOS_BUILD_NUMBER} from kernel_manifest-${ARG_MANIFEST_REPO_SUFFIX}."