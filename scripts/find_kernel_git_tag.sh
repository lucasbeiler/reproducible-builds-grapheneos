#!/bin/bash
set -eo pipefail

# Input arguments
KERNEL_COMMIT_SHA="$1"
GOS_BUILD_NUMBER="$2"
KERNEL_COMMON_REPO_URL="$3"
KERNEL_MANIFEST_REPO_URL="$4"

KERNEL_GIT_TAG_PREFIX=""
if [[ "$KERNEL_MANIFEST_REPO_URL" =~ "github" ]]; then
  KERNEL_GIT_TAG_PREFIX="refs/tags/"
fi

# Default kernel git tag
KERNEL_GIT_TAG="${KERNEL_GIT_TAG_PREFIX}${GOS_BUILD_NUMBER}"

# Always force kernel build string/timestamp unless overridden
NEED_TO_FORCE_KERNEL_BUILD_STRING_AND_TIMESTAMP=true

# Validate all necessary variables before proceeding
if [[ -n "$KERNEL_COMMIT_SHA" && -n "$KERNEL_COMMON_REPO_URL" && -n "$KERNEL_MANIFEST_REPO_URL" ]]; then
  
  KERNEL_COMMON_TAGS_WITH_SHAS=$(git ls-remote --tags "$KERNEL_COMMON_REPO_URL")
  KERNEL_COMMON_TAGS=$(git ls-remote --tags "$KERNEL_COMMON_REPO_URL" | grep -oP 'refs/tags/\K\d{10}' | sort -r | uniq )
  KERNEL_MANIFEST_TAGS=$(git ls-remote --tags "$KERNEL_MANIFEST_REPO_URL" | grep -oP 'refs/tags/\K\d{10}' | sort -r | uniq )

  for tag in $KERNEL_COMMON_TAGS; do
    echo "[DEBUG] Evaluating kernel tag candidate: $tag"
    if grep -q "${KERNEL_COMMIT_SHA}.*[[:space:]]refs/tags/${tag}" <<< "$KERNEL_COMMON_TAGS_WITH_SHAS"; then
      echo "[DEBUG] Found ${KERNEL_COMMIT_SHA} as HEAD of ${tag}."
      if [[ "$tag" =~ ^[0-9]+$ && "$tag" -le "$GOS_BUILD_NUMBER" ]]; then
        if grep -q "${tag}" <<< "$KERNEL_MANIFEST_TAGS"; then
          echo "[DEBUG] Selected kernel tag $tag after checking that ${KERNEL_MANIFEST_REPO_URL} has it."
          KERNEL_GIT_TAG="${KERNEL_GIT_TAG_PREFIX}${tag}"
          NEED_TO_FORCE_KERNEL_BUILD_STRING_AND_TIMESTAMP=false
          break
        fi
      fi
    fi
  done
else
  echo "[DEBUG] Missing input arguments; using default kernel git tag."
fi

echo "[DEBUG] Final kernel git tag: $KERNEL_GIT_TAG"
echo "[DEBUG] Need to force kernel build string/timestamp: $NEED_TO_FORCE_KERNEL_BUILD_STRING_AND_TIMESTAMP"