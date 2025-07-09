#!/bin/bash
set -eo pipefail

# Set some base variables for whole device generations.
case $PIXEL_CODENAME in
    tokay|caiman|komodo|comet|tegu) # Pixel 9, 9 Pro, 9 Pro XL, 9 Pro Fold, and 9a.
      PIXEL_GENERATION_CODENAME="caimito"
      M_BUILD_PARAMS="vendorbootimage vendorkernelbootimage target-files-package otatools-package"
      KERNEL_GIT_TAG_OR_BRANCH_OVERRIDE="16-kernel-3"
      ;;
    shiba|husky|akita) # Pixel 8, 8 Pro, and 8a
      PIXEL_GENERATION_CODENAME="shusky"
      M_BUILD_PARAMS="vendorbootimage vendorkernelbootimage target-files-package otatools-package"
      KERNEL_GIT_TAG_OR_BRANCH_OVERRIDE="16-kernel-2"
      ;;
    panther|cheetah|lynx|tangorpro|felix) # Pixel 7, 7 Pro, 7a, Tablet, and Fold.
      PIXEL_GENERATION_CODENAME="pantah"
      M_BUILD_PARAMS="vendorbootimage vendorkernelbootimage target-files-package otatools-package"
      KERNEL_GIT_TAG_OR_BRANCH_OVERRIDE="16-kernel-2"
      ;;
    oriole|raven|bluejay) # Pixel 6, Pixel 6 Pro, and Pixel 6a.
      PIXEL_GENERATION_CODENAME="raviole"
      M_BUILD_PARAMS="vendorbootimage target-files-package otatools-package"
      ;;
    *)
      ;;
esac

# Change some variables for specific device variants (tablets, foldables, 6a/7a/8a/9a, etc).
if [[ "$PIXEL_CODENAME" =~ ^(comet|tegu|akita|bluejay|lynx|felix|tangorpro)$ ]]; then
  PIXEL_GENERATION_CODENAME="$PIXEL_CODENAME"
fi

# Pixel 9a (tegu) does not fit into 16-kernel-2 or 16-kernel-3, and it seems that it can use the default (same as the 16 branch).
if [[ "$PIXEL_CODENAME" = "tegu" ]]; then
  unset KERNEL_GIT_TAG_OR_BRANCH_OVERRIDE
fi

# General variables.
PIXEL_DEVICE_KERNEL_MANIFEST_REPO_SUFFIX=pixel
KERNEL_BUILD_COMMAND="./build_${PIXEL_GENERATION_CODENAME}.sh --lto=full"