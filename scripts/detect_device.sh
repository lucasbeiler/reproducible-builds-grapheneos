#!/bin/bash
set -eo pipefail

# Set some base variables for whole device generations.
case $PIXEL_CODENAME in
    frankel|blazer|mustang|rango) # Pixel 10, 10 Pro, 10 Pro XL, and 10 Pro Fold.
      # Placeholders for future devices based on their supposed codenames!!!
      PIXEL_CODENAME_FOR_KERNELS="???"
      PIXEL_GENERATION_SOC_CODENAME="laguna"
      KERNEL_VERSION="6.6???"
      M_BUILD_PARAMS="vendorbootimage vendorkernelbootimage target-files-package otatools-package"
      KERNEL_BUILD_COMMAND="./build_${PIXEL_CODENAME_FOR_KERNELS}.sh --config=no_download_gki ??? --lto=full"
      ;;
    tokay|caiman|komodo|comet|tegu) # Pixel 9, 9 Pro, 9 Pro XL, 9 Pro Fold, and 9a.
      PIXEL_CODENAME_FOR_KERNELS="caimito"
      PIXEL_GENERATION_SOC_CODENAME="zumapro"
      KERNEL_VERSION="6.1"
      M_BUILD_PARAMS="vendorbootimage vendorkernelbootimage target-files-package otatools-package"
      KERNEL_BUILD_COMMAND="./build_${PIXEL_CODENAME_FOR_KERNELS}.sh --config=no_download_gki --config=no_download_gki_fips140 --lto=full"
      ;;
    shiba|husky|akita) # Pixel 8, 8 Pro, and 8a
      PIXEL_CODENAME_FOR_KERNELS="shusky"
      PIXEL_GENERATION_SOC_CODENAME="zuma"
      KERNEL_VERSION="5.15"
      M_BUILD_PARAMS="vendorbootimage vendorkernelbootimage target-files-package otatools-package"
      KERNEL_BUILD_COMMAND="./build_${PIXEL_CODENAME_FOR_KERNELS}.sh --config=no_download_gki --lto=full"
      ;;
    panther|cheetah|lynx|tangorpro|felix) # Pixel 7, 7 Pro, 7a, Tablet, and Fold.
      PIXEL_CODENAME_FOR_KERNELS="pantah"
      PIXEL_GENERATION_SOC_CODENAME="gs"
      KERNEL_VERSION="5.10"
      M_BUILD_PARAMS="vendorbootimage vendorkernelbootimage target-files-package otatools-package"
      KERNEL_BUILD_COMMAND="BUILD_AOSP_KERNEL=1 LTO=full ./build_cloudripper.sh"
      ;;
    oriole|raven|bluejay) # Pixel 6, Pixel 6 Pro, and Pixel 6a.
      PIXEL_CODENAME_FOR_KERNELS="raviole"
      PIXEL_GENERATION_SOC_CODENAME="gs"
      KERNEL_VERSION="5.10"
      M_BUILD_PARAMS="vendorbootimage target-files-package otatools-package"
      KERNEL_BUILD_COMMAND="BUILD_AOSP_KERNEL=1 LTO=full ./build_slider.sh"
      ;;
    *)
      ;;
esac

# Change some variables for specific device variants (tablets, foldables, 6a/7a/8a/9a, etc).
case $PIXEL_CODENAME in
    rango) # Pixel 10 Pro Fold.
      # Placeholders for a future device based on its supposed codenames!!!
      PIXEL_CODENAME_FOR_KERNELS="${PIXEL_CODENAME}"
      KERNEL_BUILD_COMMAND="./build_${PIXEL_CODENAME_FOR_KERNELS}.sh --config=no_download_gki ??? --lto=full"
      ;;
    comet|tegu) # Pixel 9 Pro Fold and 9a.
      PIXEL_CODENAME_FOR_KERNELS="${PIXEL_CODENAME}"
      KERNEL_BUILD_COMMAND="./build_${PIXEL_CODENAME_FOR_KERNELS}.sh --config=no_download_gki --config=no_download_gki_fips140 --lto=full"
      ;;
    akita) # Pixel 8a.
      PIXEL_CODENAME_FOR_KERNELS="${PIXEL_CODENAME}"
      KERNEL_BUILD_COMMAND="./build_${PIXEL_CODENAME_FOR_KERNELS}.sh --config=no_download_gki --lto=full"
      ;;
    bluejay|lynx|felix|tangorpro) # Pixel 6a, 7a, Fold, and Tablet.
      PIXEL_CODENAME_FOR_KERNELS="${PIXEL_CODENAME}"
      KERNEL_BUILD_COMMAND="BUILD_AOSP_KERNEL=1 LTO=full ./build_${PIXEL_CODENAME_FOR_KERNELS}.sh"
      ;;
    *)
      ;;
esac