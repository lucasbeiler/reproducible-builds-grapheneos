#!/bin/bash
set -euo pipefail

# Prepare working environment
export PATH="$PATH:$HOME/payload-dumper-go:$HOME/grapheneos/grapheneos-${GOS_BUILD_NUMBER}/out/host/linux-x86/bin/:/sbin:/usr/sbin:/usr/local/sbin"
cd ~/comparing

# Copy my build outputs to reproduced/
cp ~/grapheneos/grapheneos-${GOS_BUILD_NUMBER}/releases/${GOS_BUILD_NUMBER}/release-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip ~/comparing/reproduced/
cp ~/grapheneos/grapheneos-${GOS_BUILD_NUMBER}/releases/${GOS_BUILD_NUMBER}/release-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}/${PIXEL_CODENAME}-ota_update-${GOS_BUILD_NUMBER}.zip ~/comparing/reproduced/

# Save the hashes of the official builds.
# TODO: Add factory.zip ZIPs here too!
sha512sum official/*.zip > ~/comparing/operation_outputs/${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.checksums.txt
sha512sum ../official_incrementals/*.zip >> ~/comparing/operation_outputs/${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.checksums.txt
extract_vbmeta_hashes_to_file official/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip
extract_vbmeta_hashes_to_file official/${PIXEL_CODENAME}-ota_update-${GOS_BUILD_NUMBER}.zip

# Eight iterations are more than enough as far as I'm aware. Maybe turn this into something more dynamic.
## TODO: Review this whole loop again and again!
for i in $(seq 8); do
  # Unzip everything to start with.
  for zipfile in $(find -type f -name "${PIXEL_CODENAME}-factory-${GOS_BUILD_NUMBER}.zip" -o -name "${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip" -o -name "${PIXEL_CODENAME}-ota_update-${GOS_BUILD_NUMBER}.zip" -o -name "image-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.zip"); do
    mkdir -p ${zipfile}.unzip && unzip ${zipfile} -d ${zipfile}.unzip && rm -f ${zipfile}
  done;
  
  # Dump update payloads.
  for update_payload in $(find -type f -name 'payload.bin'); do
    mkdir -p ${update_payload}.unpack
    payload-dumper-go -o ${update_payload}.unpack ${update_payload} 
    rm -f ${update_payload}
    [[ "${update_payload}" =~ "./official/" ]] && cd ${update_payload}.unpack/ && sha256sum *.img > ~/comparing/operation_outputs/full_ota_payload_images.sha256sums.txt && cd -
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
    lpunpack ${superimg} ${superimg}.unpack
    rm -f ${superimg}
  done;
      
  # Try to extract all the supposedly valid filesystem images.
  for img in $(find -type f -name '*.img'); do
    if [[ "$(file ${img})" =~ filesystem && ! -d "${img}.unpack" ]]; then
      mkdir -p ${img}.unpack
      avbtool erase_footer --image ${img} || echo "Could not erase AVB footer. It was erased before, probably!"
      7z x ${img} -o${img}.unpack -snld && rm -f ${img} || echo "7zip returned non-zero exit code for ${img}!"
    fi
  done;
  
  # Extract APEX files.
  for apex in $(find -type f -name '*.apex'); do
    # Extract apex_payload.img with deapexer.
    deapexer --debugfs_path=/usr/sbin/debugfs --fsckerofs_path=/usr/bin/fsck.erofs extract ${apex} ${apex}.deapex
    # Extract other files from the APEX by using unzip (except apex_payload.img because deapexer already does, and better).
    unzip ${apex} -d${apex}.unzip && rm -f ${apex}.unzip/apex_payload.img
    # Delete the original APEX file.
    rm -f ${apex}
  done;
    
  # Extract APK files in order to dissolve its signatures (we only care about APK contents), quickly dealing with differences that signatures would introduce.
  for apkfile in $(find -type f -name '*.apk'); do
    mkdir -p ${apkfile}.unpack && unzip "$apkfile" -d "${apkfile}.unpack" && rm -f $apkfile || echo "unzip returned non-zero exit code for ${apkfile}!"; continue;
  done;
      
  # Unpack boot images. 
  for bootimg in $(find -type f -name '*boot.img'); do
    if [[ -f "${bootimg}"  ]]; then
      unpack_bootimg --boot_img ${bootimg} --out ${bootimg}.unpacked
      rm -f ${bootimg}
    fi
  done;
    
  # Deal with vendor_ramdisk from vendor_kernel_boot and vendor_boot
  for ramdisk in $(find -type f -name 'vendor_ramdisk00'); do
    unlz4 ${ramdisk} ${ramdisk}.unlz4
    mkdir -p ${ramdisk}.extract
    cpio -i -F ${ramdisk}.unlz4 -D ${ramdisk}.extract/
    rm -f ${ramdisk} ${ramdisk}.unlz4
  done;

  # Uncompress LZ4 kernel image files, then use binwalk and dd to locate and remove any signature/certificate.
  # NOTE: What I am doing is still pretty much experimental (and a bit hacky), barebones and slow (needs to be rewritten), beware.
  # TODO: Improve this. Could be way better.
  for kernel in $(find -type f -name 'kernel'); do
    if [[ "$(file ${kernel})" =~ 'LZ4 compressed data' ]]; then
      unlz4 ${kernel} ${kernel}.unlz4 && mv ${kernel}.unlz4 ${kernel}
      read -r byte_sign_start byte_sign_length < <(echo $(binwalk "${kernel}" | grep -i 'certificate in der format' |  head -1 | awk '{print $1, $NF}'))
      byte_sign_end=$(( ${byte_sign_start} + ${byte_sign_length} ))
      dd if=${kernel} of=${kernel}.before bs=1 count=${byte_sign_start}
      dd if=${kernel} of=${kernel}.after bs=1 skip=$(echo $((${byte_sign_end} + 4)))
      rm -f ${kernel}
      cat ${kernel}.before ${kernel}.after > ${kernel}
      rm -f ${kernel}.before ${kernel}.after
    fi
  done;

  # Remove AVB signatures from the microdroid kernel and rialto.bin (both part of AVF).
  for file in $(find -type f -name 'microdroid_kernel' -o -name 'rialto.bin'); do
    if [[ "$(file ${file})" =~ 'LZ4 compressed data' ]]; then
      unlz4 ${file} ${file}.unlz4 && mv ${file}.unlz4 ${file}
    fi
    avbtool erase_footer --image ${file}
    mv ${file} ${file}.erased_avb_footer
  done;

  # Deal with pvmfw.img. NOTE: What I am doing is still pretty much experimental (and a bit hacky), beware.
  ## TODO: Improve this. Seems way NAIVE.
  for pvmfw in $(find -type f -name 'pvmfw.img'); do
    # Use binwalk to get to know where the flattened device tree starts.
    read -r byte_dtb_start < <(echo $(binwalk "${pvmfw}" | grep -i 'flattened device tree' |  head -1 | awk '{ print $1 }'))
    # Get file up until right before the byte where the flattened device tree begins (and the Android bootimg part ends).
    dd bs=1 if=${pvmfw} of=${pvmfw}.bootimg count=$(echo $((${byte_dtb_start} + 22147)))
    # Get file after the byte where the flattened device tree begins.
    dd bs=1 if=${pvmfw} of=${pvmfw}.dtb skip=${byte_dtb_start} 
    # Get dts from dtb.
    dtc -I dtb -O dts -o ${pvmfw}.dts ${pvmfw}.dtb
    # Remove original image and my intermediate files.
    rm -f ${pvmfw} ${pvmfw}.dtb
  done;
done;

# Strip kernel modules in order to remove signatures and other irrelevant things (comments, notes, debugging stuff, build IDs, info/metadata, etc).
# TODO: Check if I am not stripping too much.
find -name '*.ko' | xargs aarch64-linux-gnu-strip --remove-section=.comment --remove-section=.note --remove-section=.BTF --remove-section=.note.gnu.build-id --remove-section=.modinfo

# Delete every symlink.
find . -xtype l -print -delete
find .  -type l -print -delete

# Save the directory tree in a way that can be debugged later.
find ~/comparing/ -type f | gzip > ~/comparing/operation_outputs/debug-find-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt # TODO: Remove this when confident enough.

# Compare the now unpacked OTA and install builds (official vs. reproduced).
# NOTE: The `|| :` at the end is due to diffoscope returning non-zero exit codes when there are diffs.
diffoscope --no-default-limits --max-page-diff-block-lines 5000 --exclude "*.png" --exclude "payload_properties.txt" --exclude-command ^zipinfo.* --exclude-command ^zipdetail.* --exclude "otacerts.zip" --exclude "*.pem" --exclude "**/META-INF/**" --exclude "**/lost+found/**" --exclude "*vbmeta.img" --exclude "apex_pubkey" --exclude "avb_pkmd.bin" --exclude-directory-metadata yes  --html operation_outputs/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.html official/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip.unzip/ reproduced/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip.unzip/ || :
diffoscope --no-default-limits --max-page-diff-block-lines 5000 --exclude "*.png" --exclude "payload_properties.txt" --exclude-command ^zipinfo.* --exclude-command ^zipdetail.* --exclude "otacerts.zip" --exclude "*.pem" --exclude "**/META-INF/**" --exclude "**/lost+found/**" --exclude "*vbmeta.img" --exclude "apex_pubkey" --exclude "avb_pkmd.bin" --exclude-directory-metadata yes  --html operation_outputs/${PIXEL_CODENAME}-ota_update-${GOS_BUILD_NUMBER}.html official/${PIXEL_CODENAME}-ota_update-${GOS_BUILD_NUMBER}.zip.unzip/ reproduced/${PIXEL_CODENAME}-ota_update-${GOS_BUILD_NUMBER}.zip.unzip/ || :

# Store the target hashes of the partitions within incremental updates so we can see later if they all match.
for incremental_zip in ~/official_incrementals/${PIXEL_CODENAME}-incremental-*-${GOS_BUILD_NUMBER}.zip; do
  incremental_filename=$(basename "$incremental_zip")
  incremental_filename=${incremental_filename%.*}
  python3 /usr/local/bin/payload_hash_reader ${incremental_zip} 2>/dev/null > ~/comparing/operation_outputs/${incremental_filename}_ota_payload_images.sha256sums.txt
done;

# Loop through all the files containing SHA256 hashes of the data inside the payloads of full OTA and incrementals. All these hashes should be identical.
first_hash=""
for sha256sums_file in ~/comparing/operation_outputs/*_ota_payload_images.sha256sums.txt; do
  if [[ -f "$sha256sums_file" ]]; then
    current_hash=$(cat "$sha256sums_file" | sort | uniq | sha512sum)
    echo "${sha256sums_file} hash: ${current_hash}"

    if [ -z "$first_hash" ]; then
      first_hash="$current_hash"
    fi

    if [ "$current_hash" != "$first_hash" ]; then
      echo "Data in the official full OTA and incrementals/deltas do not match!" > ~/comparing/operation_outputs/additional-comparisons${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt
      echo -e "\n\nCheck the hashes below:" >> ~/comparing/operation_outputs/additional-comparisons${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt
      cat ~/comparing/operation_outputs/*_ota_payload_images.sha256sums.txt | sort | uniq >> ~/comparing/operation_outputs/additional-comparisons${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt
      exit
    fi
  fi
done

echo "The target hashes of the partitions after the incremental/delta operations for all incremental/delta images match the hashes of the partitions in the full OTA image." > ~/comparing/operation_outputs/additional-comparisons${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt
echo "The official full OTA image was compared with my reproduced build and now its partitions' hashes were compared with the target hashes of the operations in the official incrementals/deltas targets, so there are chained guarantees that the official incrementals are also trustworthy." >> ~/comparing/operation_outputs/additional-comparisons${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt
echo -e "\n\nCheck the hashes below:" >> ~/comparing/operation_outputs/additional-comparisons${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt
cat ~/comparing/operation_outputs/*_ota_payload_images.sha256sums.txt | sort | uniq >> ~/comparing/operation_outputs/additional-comparisons${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt
rm -f ~/comparing/operation_outputs/*_ota_payload_images.sha256sums.txt # No need to keep because they are identical.

grep -viE "Successfully verified|Verifying image|([a-fA-F0-9]{64})" ~/*.vbmeta_results.txt && echo "Something wrong with vbmeta checks." >> "~/comparing/operation_outputs/additional-comparisons${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt"
echo -e "Verified boot hash of the official builds that were tested. You can compare it with the one shown by Auditor on your device:\n$(grep -iE '([a-fA-F0-9]{64})' ~/*.vbmeta_results.txt | sort | uniq)"
