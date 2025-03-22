FROM archlinux:latest

ENV TZ="America/New_York"
RUN useradd -ms /bin/bash reprobuilder && \
    pacman -Syyuu --noconfirm base base-devel jq cpio diffutils fontconfig freetype2 git gnupg inetutils make nodejs-lts-iron openssh openssl parallel python-protobuf python repo rsync signify ttf-dejavu zip unzip yarn gperf lib32-gcc-libs lib32-glibc && \
    sed -i 's/purge debug/purge !debug/g' /etc/makepkg.conf && \
    su reprobuilder -c "curl -sL --create-dirs -o /tmp/ncurses5-compat-libs/PKGBUILD 'https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=ncurses5-compat-libs&id=4e33179af1a720c5cdf4204d1321751081b9cc6a'" && \
    echo '418c11f18967e966a27549f8069af6ca8be4c8f4e8c4b5cb0bd348a4f3f50b78b920ec21745bdcebec5faa81ae54afbc23d36d263285008d4dfc3236b889f64f /tmp/ncurses5-compat-libs/PKGBUILD' | sha512sum -c && \
    su reprobuilder -c "cd /tmp/ncurses5-compat-libs/; makepkg --skippgpcheck" && \
    pacman -U /tmp/ncurses5-compat-libs/ncurses5-compat-libs-* --noconfirm && \
    rm -rf /tmp/ncurses5-compat-libs/ && \
    mkdir -pv /opt/build/grapheneos/ && chown -R reprobuilder:reprobuilder /opt/build/ && \
    ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime;

    
COPY ./scripts/*.sh /usr/local/bin
RUN chmod a+rx /usr/local/bin/*.sh

WORKDIR /opt/build/grapheneos

USER reprobuilder
ENTRYPOINT ["/bin/bash", "-c", "/usr/local/bin/build_gos.sh > /opt/build/grapheneos/comparing/operation_outputs/build_log.txt 2>&1"]