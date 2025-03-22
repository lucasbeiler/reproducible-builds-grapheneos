#!/bin/bash
set -euo pipefail
# This script takes a zip file, checks its partitions with avbtool and outputs it to a proper file.
TMP_DIR=$(mktemp -d)

OFFICIAL_ZIP_FILE_PATH=$1
OFFICIAL_ZIP_FILE_NAME=$(basename "${OFFICIAL_ZIP_FILE_PATH}")
UNZIP_TARGET_DIR="${TMP_DIR}/${OFFICIAL_ZIP_FILE_NAME}.unzip"
IMAGES_TARGET_DIR="${TMP_DIR}/images"

mkdir -p ${UNZIP_TARGET_DIR} ${IMAGES_TARGET_DIR}
unzip -q ${OFFICIAL_ZIP_FILE_PATH} -d ${UNZIP_TARGET_DIR}
cd ${UNZIP_TARGET_DIR}

for i in $(seq 8); do
  # Unzip everything to start with.
  for zipfile in $(find -type f -name "${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip"); do
    mkdir -p ${zipfile}.unzip && unzip -q ${zipfile} -d ${zipfile}.unzip && rm -f ${zipfile}
  done;
  
  # Locate super_1.img, then merge all the parts into super.img to finally properly unpack super.img later.
  for super_1 in $(find -type f -name 'super_1.img'); do
    directory=$(dirname "$super_1")
    simg2img ${directory}/super_*img ${directory}/super.img.raw
    rm -f ${directory}/super_*img
  done;

  # Unsparse other super.img images (also includes microdroid_super.img, for example).
  for superimg in $(find -type f -name '*super.img'); do
    simg2img ${superimg} ${superimg}.raw || continue;
    rm -f ${superimg}
  done;
  
  # Unpack the unsparsed (raw) super.img files.
  for superimg in $(find -type f -name '*super.img.raw'); do
    mkdir -p ${superimg}.unpack
    lpunpack ${superimg} ${superimg}.unpack >/dev/null
    rm -f ${superimg}
  done;
done;

find -type f -name "*.img" -exec mv {} ${IMAGES_TARGET_DIR}/ \;

cd ${IMAGES_TARGET_DIR}
find -type f -size 0 -delete
find . -type f \( -name "*_a.img" -o -name "*_b.img" \) | while read file; do
    new_name=$(echo "$file" | sed -E 's/(_a|_b)\.img$/.img/')
    [[ ! -f "$new_name" ]] && mv "$file" "$new_name"
done;

avbtool verify_image --image vbmeta.img --follow_chain_partitions > ~/${OFFICIAL_ZIP_FILE_NAME}.vbmeta_results.txt
avbtool calculate_vbmeta_digest --image vbmeta.img >> ~/${OFFICIAL_ZIP_FILE_NAME}.vbmeta_results.txt
rm -rf ${TMP_DIR}
