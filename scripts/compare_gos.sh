#!/bin/bash
set -euo pipefail

# Build and install payload-dumper-go
git clone https://github.com/ssut/payload-dumper-go ~/payload-dumper-go
cd ~/payload-dumper-go
go build
sudo mv payload-dumper-go /usr/local/bin/
sudo chmod a+x /usr/local/bin/payload-dumper-go

# Prepare working environment
rm -rf ~/comparing && mkdir -p ~/comparing/official ~/comparing/reproduced ~/comparing/diffoscope_outputs
cd ~/comparing
export BUILD_NUMBER=$(cat ~/.grapheneos_release_build_number)
export PIXEL_CODENAME=$(cat ~/.grapheneos_release_device)

# Copy my build outputs to reproduced/
cp ~/grapheneos/grapheneos-${BUILD_NUMBER}/releases/${BUILD_NUMBER}/release-${PIXEL_CODENAME}-${BUILD_NUMBER}/${PIXEL_CODENAME}-install-${BUILD_NUMBER}.zip ~/comparing/reproduced/
cp ~/grapheneos/grapheneos-${BUILD_NUMBER}/releases/${BUILD_NUMBER}/release-${PIXEL_CODENAME}-${BUILD_NUMBER}/${PIXEL_CODENAME}-ota_update-${BUILD_NUMBER}.zip ~/comparing/reproduced/

# Download official builds to official/
wget -P ~/comparing/official/ https://releases.grapheneos.org/${PIXEL_CODENAME}-install-${BUILD_NUMBER}.zip
wget -P ~/comparing/official/ https://releases.grapheneos.org/${PIXEL_CODENAME}-ota_update-${BUILD_NUMBER}.zip
sha512sum official/*.zip > ~/comparing/diffoscope_outputs/${PIXEL_CODENAME}-${BUILD_NUMBER}.checksums

for i in $(seq 4); do
  # Unzip everything to start with.
  for zipfile in $(find -type f -name "${PIXEL_CODENAME}-*.zip"); do
    mkdir -p ${zipfile}.unzip && unzip ${zipfile} -d ${zipfile}.unzip && rm -f ${zipfile}
  done;
  
  # Dump update payloads.
  for update_payload in $(find -type f -name 'payload.bin'); do
    mkdir -p ${update_payload}.unpack
    payload-dumper-go -o ${update_payload}.unpack ${update_payload} 
    rm -f ${update_payload}
  done;
  
  # Locate super_1.img, then merge all the parts into super.img to finally properly unpack super.img later.
  for super_1 in $(find -type f -name 'super_1.img'); do
    directory=$(dirname "$super_1")
    cat $(ls ${directory}/super_*img | sort -V) > ${directory}/super.img
    rm -f ${directory}/super_*img
  done;
  
  # Unpack super.img.
  for superimg in $(find -type f -name '*super.img'); do
    if [[ $(file ${superimg}) =~ 'Android sparse image'  ]]; then 
      simg2img ${superimg} ${superimg}.raw
    fi
    mkdir -p ${superimg}.raw.slot0.unpack ${superimg}.raw.slot1.unpack
    ~/grapheneos/grapheneos-*/out/host/linux-x86/bin/lpunpack --slot=0 ${superimg}.raw ${superimg}.raw.slot0.unpack
    ~/grapheneos/grapheneos-*/out/host/linux-x86/bin/lpunpack --slot=1 ${superimg}.raw ${superimg}.raw.slot1.unpack
    rm -f ${superimg} ${superimg}.raw
  done;
      
  # Try to extract all the supposedly valid filesystem images.
  for img in $(find -type f -name '*.img'); do
    if [[ "$(file ${img})" =~ filesystem && ! -d "${img}.unpack" ]]; then
      mkdir -p ${img}.unpack
      e2fsck -yE unshare_blocks ${img} || :
      7z x ${img} -o${img}.unpack && rm -f ${img} || :
    fi
  done;
  
  # Extract APEX files.
  for apex in $(find -type f -name '*.apex'); do
    apex_base_name=$(basename ${apex})
    
    # Unpack APEX files that are valid ZIP files.
    unzip -tq "${apex}" && mkdir -p ${apex}.unpack && unzip "$apex" -d "${apex}.unpack" && rm -f ${apex} && continue || :
    
    # Save hash, hexdump and strings and delete the file.
    sha512sum ${apex} | awk '{ print $1 }' > ${apex}.sha512sum
    hexdump -C ${apex} > ${apex}.hexdump
    strings ${apex} > ${apex}.strings
    echo "${apex}" >> diffoscope_outputs/deleted-apexes-${PIXEL_CODENAME}-${BUILD_NUMBER}.txt # TODO: Remove this debugging file when confident enough.
    rm -f ${apex}
  done;
      
  # Extract apex_payload.img.
  for apex_payload in $(find -type f -name 'apex_payload.img'); do
    if [[ "$(file ${apex_payload})" =~ filesystem && ! -d "${apex_payload}.extract" ]]; then
      mkdir -p ${apex_payload}.extract
      7z x ${apex_payload} -o${apex_payload}.extract && rm -f ${apex_payload} || :
    fi
  done;
    
  # Extract APK files in order to dissolve its signatures (we only care about APK contents), quickly dealing with differences that signatures would introduce
  for apkfile in $(find -type f -name '*.apk'); do
    unzip -tq "${apkfile}" && mkdir -p ${apkfile}.unpack && unzip "$apkfile" -d "${apkfile}.unpack" && rm -f $apkfile || continue
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
    avbtool erase_footer --image ${file} || echo "No AVB footer found. It's already removed, probably."
  done;

  # Deal with pvmfw.img. NOTE: What I am doing is still pretty much experimental (and a bit hacky), beware.
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
find -name '*.ko' | xargs strip --remove-section=.comment --remove-section=.note --remove-section=.BTF --remove-section=.note.gnu.build-id --remove-section=.modinfo

find ~/comparing/ -type f > ~/comparing/diffoscope_outputs/find-${PIXEL_CODENAME}-${BUILD_NUMBER}.txt
sudo cat /var/log/cloud-init-output.log > ~/comparing/diffoscope_outputs/cloud-init-output-${PIXEL_CODENAME}-${BUILD_NUMBER}.txt

# Compare the now unpacked builds (official vs. reproduced).
# NOTE: The `|| :` at the end is due to diffoscope returning non-zero exit codes when there are diffs.
diffoscope --no-default-limits --max-page-diff-block-lines 5000 --exclude "*.png" --exclude "payload_properties.txt" --exclude-command ^zipinfo.* --exclude-command ^zipdetail.* --exclude "otacerts.zip" --exclude "*.pem" --exclude "**/META-INF/**" --exclude "**/lost+found/**" --exclude "*vbmeta.img" --exclude "apex_pubkey" --exclude "avb_pkmd.bin" --exclude-directory-metadata yes  --html diffoscope_outputs/${PIXEL_CODENAME}-${BUILD_NUMBER}.html official/ reproduced/ || :

# Upload diffoscope output to s3
aws s3 mv diffoscope_outputs/ s3://gos-reproducibility-reports/ --recursive --exclude "*" --include "*.html" --include "*.txt" --include "*.checksums" --region us-east-1 --acl public-read

echo "[INFO] Done!"
