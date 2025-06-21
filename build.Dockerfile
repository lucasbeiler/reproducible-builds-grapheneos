FROM archlinux:latest

ENV TZ="America/New_York"
RUN useradd -ms /bin/bash reprobuilder && \
    pacman -Syyuu --noconfirm base base-devel jq cpio diffutils fontconfig freetype2 git gnupg inetutils make nodejs-lts-iron openssh openssl parallel python-protobuf python repo rsync signify ttf-dejavu zip unzip yarn gperf lib32-gcc-libs lib32-glibc && \
    mkdir -pv /opt/build/grapheneos/ && chown -R reprobuilder:reprobuilder /opt/build/ && \
    ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime;

    
COPY ./scripts/*.sh /usr/local/bin
RUN chmod a+rx /usr/local/bin/*.sh

WORKDIR /opt/build/grapheneos

USER reprobuilder
ENTRYPOINT ["/bin/bash", "-c", "/usr/local/bin/build_gos.sh > /opt/build/grapheneos/comparing/operation_outputs/build_log.txt 2>&1"]