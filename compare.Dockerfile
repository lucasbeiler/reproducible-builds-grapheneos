FROM archlinux:latest

RUN useradd -ms /bin/bash comparer && \
    pacman -Syyuu --noconfirm base base-devel diffoscope binwalk procyon-decompiler jdk-openjdk gnupg llvm radare2 openssl openssh android-tools 7zip gzip enjarify cpio python-capstone zip unzip python-protobuf e2fsprogs guestfs-tools go dtc xz lz4 binutils aarch64-linux-gnu-binutils vim erofs-utils && \
    mkdir -pv /opt/build/grapheneos/comparing/ && chown -R comparer:comparer /opt/build/;

# Install an additional older 2.x version of binwalk (detects more stuff than 3.x).
RUN pacman -Sy --noconfirm python-setuptools python-build python-installer python-wheel git && \
    su comparer -c "git clone https://github.com/OSPG/binwalk ~/binwalk && cd ~/binwalk && python3 setup.py install --user";

COPY ./scripts/*.sh /usr/local/bin
RUN chmod a+rx /usr/local/bin/*.sh

WORKDIR /opt/build/grapheneos/comparing/

USER comparer
ENTRYPOINT ["/bin/bash", "-c", "/usr/local/bin/compare_gos.sh > /opt/build/grapheneos/comparing/operation_outputs/compare_log.txt 2>&1"]