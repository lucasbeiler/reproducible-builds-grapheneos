#!/bin/bash
set -euo pipefail

# Prepare working environment.
export PATH="$PATH:/opt/build/grapheneos/comparing/tools/host/linux-x86/bin/:/sbin:/usr/sbin:/usr/local/sbin"

# Save the verified boot hash of the official build.
bash /usr/local/bin/extract_vbmeta_hashes_to_file.sh /opt/build/grapheneos/comparing/official/${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip

# Ten iterations are more than enough as far as I'm aware. Maybe turn this into something more dynamic.
cd /opt/build/grapheneos/comparing/
for i in $(seq 10); do
  # Unzip everything to start with.
  for zipfile in $(find official/ reproduced/ -type f -name "${PIXEL_CODENAME}-install-${GOS_BUILD_NUMBER}.zip"); do
    mkdir -p ${zipfile}.unzip && unzip ${zipfile} -d ${zipfile}.unzip && rm -f ${zipfile}
  done;
  
  # Locate super_1.img, then merge all the parts into super.img to finally properly unpack super.img later.
  for super_1 in $(find official/ reproduced/ -type f -name 'super_1.img'); do
    directory=$(dirname "$super_1")
    simg2img ${directory}/super_*img ${directory}/super.img.raw
    rm -f ${directory}/super_*img
  done;

  # Unsparse other super.img images (also includes microdroid_super.img, for example).
  for superimg in $(find official/ reproduced/ -type f -name '*super.img'); do
    simg2img ${superimg} ${superimg}.raw || continue;
    rm -f ${superimg}
  done;
  
  # Unpack the unsparsed (raw) super.img files.
  for superimg in $(find official/ reproduced/ -type f -name '*super.img.raw'); do
    mkdir -p ${superimg}.unpack
    lpunpack ${superimg} ${superimg}.unpack
    rm -f ${superimg}
  done;
      
  # Try to extract all the supposedly valid filesystem images.
  for img in $(find official/ reproduced/ -type f -name '*.img'); do
    if [[ "$(file ${img})" =~ filesystem && ! -d "${img}.unpack" ]]; then
      mkdir -p ${img}.unpack
      avbtool erase_footer --image ${img} || echo "[DEBUG] Could not erase AVB footer. It was erased before, probably!"
      7z x ${img} -o${img}.unpack -snld && rm -f ${img} || echo "[DEBUG] 7zip returned non-zero exit code for ${img}!"
    fi
  done;
  
  # Extract APEX files.
  for apex in $(find official/ reproduced/ -type f -name '*.apex'); do
    # Extract apex_payload.img with deapexer.
    deapexer --debugfs_path=/usr/sbin/debugfs --fsckerofs_path=/usr/bin/fsck.erofs extract ${apex} ${apex}.deapex
    # Extract other files from the APEX by using unzip (except apex_payload.img because deapexer already does, and better).
    unzip ${apex} -d${apex}.unzip && rm -f ${apex}.unzip/apex_payload.img
    # Delete the original APEX file.
    rm -f ${apex}
  done;
    
  # Extract APK files in order to dissolve its signatures (we only care about APK contents), quickly dealing with differences that signatures would introduce.
  for apkfile in $(find official/ reproduced/ -type f -name '*.apk'); do
    mkdir -p ${apkfile}.unpack && unzip "$apkfile" -d "${apkfile}.unpack" && rm -f $apkfile || echo "[DEBUG] unzip returned non-zero exit code for ${apkfile}!"; continue;
  done;
      
  # Unpack boot images. 
  for bootimg in $(find official/ reproduced/ -type f -name '*boot.img'); do
    if [[ -f "${bootimg}"  ]]; then
      unpack_bootimg --boot_img ${bootimg} --out ${bootimg}.unpacked
      rm -f ${bootimg}
    fi
  done;
    
  # Deal with vendor_ramdisk from vendor_kernel_boot and vendor_boot
  for ramdisk in $(find official/ reproduced/ -type f -name 'vendor_ramdisk00'); do
    unlz4 ${ramdisk} ${ramdisk}.unlz4
    mkdir -p ${ramdisk}.extract
    cpio -i -F ${ramdisk}.unlz4 -D ${ramdisk}.extract/
    rm -f ${ramdisk} ${ramdisk}.unlz4
  done;

  # Uncompress LZ4 kernel image files, then use binwalk and dd to locate and remove certificates.
  # TODO: Improve this.
  for kernel in $(find official/ reproduced/ -type f -name 'kernel' ! -empty); do
    [[ "$(file ${kernel})" =~ 'LZ4 compressed data' ]] && unlz4 ${kernel} ${kernel}.unlz4 && mv ${kernel}.unlz4 ${kernel}
    if [[ "$(file ${kernel})" =~ 'Linux kernel ARM64 boot executable Image' ]]; then
      if ~/.local/bin/binwalk "${kernel}" | grep -i 'certificate in der format'; then
        read -r byte_sign_start byte_sign_length < <(echo $(~/.local/bin/binwalk "${kernel}" | grep -i 'certificate in der format' |  head -n1 | awk '{print $1, $NF}'))
        byte_sign_end=$(( ${byte_sign_start} + ${byte_sign_length} ))
        dd if=${kernel} of=${kernel}.before bs=1 count=${byte_sign_start}
        dd if=${kernel} of=${kernel}.after bs=1 skip=$(echo $((${byte_sign_end} + 4)))
        rm -f ${kernel}
        cat ${kernel}.before ${kernel}.after > ${kernel}
        rm -f ${kernel}.before ${kernel}.after
      fi
    fi
  done;

  # Remove AVB signatures from the microdroid kernel and rialto.bin (both part of AVF).
  for file in $(find official/ reproduced/ -type f -name 'microdroid_kernel' -o -name 'rialto.bin'); do
    if [[ "$(file ${file})" =~ 'LZ4 compressed data' ]]; then
      unlz4 ${file} ${file}.unlz4 && mv ${file}.unlz4 ${file}
    fi
    avbtool erase_footer --image ${file}
    mv ${file} ${file}.erased_avb_footer
  done;

  # Deal with pvmfw.img.
  ## TODO: Improve this.
  for pvmfw in $(find official/ reproduced/ -type f -name 'pvmfw.img'); do
    # Use binwalk to get to know where the flattened device tree starts.
    read -r byte_dtb_start < <(echo $(~/.local/bin/binwalk "${pvmfw}" | grep -i 'flattened device tree' |  head -1 | awk '{ print $1 }'))
    # Get file up until right before the byte where the flattened device tree begins (and the Android bootimg part ends).
    dd bs=1 if=${pvmfw} of=${pvmfw}.bootimg count=$(echo $((${byte_dtb_start} + 22147))) # TODO: Get this 22147 (total size of dtb) dynamically.
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
find official/ reproduced/ -name '*.ko' | xargs aarch64-linux-gnu-strip --remove-section=.comment --remove-section=.note --remove-section=.BTF --remove-section=.note.gnu.build-id --remove-section=.modinfo --remove-section=.llvm_addrsig

# Delete every symlink.
find official/ reproduced/ -xtype l -print -delete
find official/ reproduced/  -type l -print -delete

# Save the directory tree in a way that can be debugged later.
find official/ reproduced/ -type f | gzip > /opt/build/grapheneos/comparing/operation_outputs/debug-find-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt.gz

# Compare the now unpacked install packages (official vs. reproduced).
# NOTE: The `|| :` at the end is due to diffoscope returning non-zero exit codes when there are diffs.
HTML_OUTPUT_FILE="operation_outputs/${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.html"
diffoscope --no-default-limits --new-file --max-page-diff-block-lines 5000 --exclude "*.png" --exclude "payload_properties.txt" --exclude-command ^zipinfo.* --exclude-command ^zipdetail.* --exclude "otacerts.zip" --exclude "*.pem" --exclude "**/META-INF/CERT*" --exclude "**/META-INF/MANIFEST.MF" --exclude "**/lost+found/**" --exclude "*vbmeta.img" --exclude "apex_pubkey" --exclude "avb_pkmd.bin" --exclude-directory-metadata yes  --html ${HTML_OUTPUT_FILE} official/ reproduced/ || :

# Fetch the Verified Boot calculated before and add it to the HTML_OUTPUT_FILE.
AVB_STRING_H3=""
AVB_STRING_H4=""
# grep: if there's some line other than "Successfully verified|Verifying image|([a-fA-F0-9]{64})", it has something wrong.
grep -viE "Successfully verified|Verifying image|([a-fA-F0-9]{64})" ~/${PIXEL_CODENAME}*${GOS_BUILD_NUMBER}*.vbmeta_results.txt && AVB_STRING_H3="<h3>Something wrong with the Verified Boot hash extraction.</h3>"
if [ -z "${AVB_STRING_H3}" ]; then
  AVB_STRING_H3="<h3>This is the Verified Boot hash of the official build: $(grep -iE '([a-fA-F0-9]{64})' ~/${PIXEL_CODENAME}*${GOS_BUILD_NUMBER}*.vbmeta_results.txt | sort | uniq)</h3>"
  AVB_STRING_H4="<h4>You can compare it with the Verified Boot hash attested by Auditor on your device.</h4>"
fi
# ... add it to the HTML_OUTPUT_FILE.
sed -i '/<body class="diffoscope">/a\'"$AVB_STRING_H3"'\n'"$AVB_STRING_H4" $HTML_OUTPUT_FILE
