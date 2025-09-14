FROM docker.io/gentoo/stage3:latest

# Sync sources and select systemd-based profile
RUN emerge --sync && \
    eselect profile list | \
    grep -E -e "default.*[[:digit:]]/systemd" | \
    grep -v 32  | \
    awk '{ print $1 }' | \
    grep -o [[:digit:]] | \
    xargs eselect profile set

RUN echo -e 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox"\nACCEPT_LICENSE="*"\nUSE="dracut nftables"' | tee -a /etc/portage/make.conf && \
    echo "sys-apps/systemd boot" | tee -a /etc/portage/package.use/systemd

RUN emerge -vDN @world

# Necessary specifically for bootc install and deps for builds
RUN emerge \
    app-arch/cpio \
    btrfs-progs \
    dev-vcs/git \
    dosfstools \
    e2fsprogs \
    linux-firmware \
    make \
    ostree \
    rust \
    skopeo \
    sys-kernel/gentoo-kernel-bin \
    systemd \
    zstd

# https://github.com/gentoo/gentoo/pull/43759/files
# REMOVE ONCE THIS IS MERGED
RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/EWouters/gentoo gentoo -b ostree --depth 1 --single-branch && \
    cd gentoo && \
    ebuild dev-util/ostree/ostree-2025.6.ebuild clean install merge

ENV CARGO_FEATURES="composefs-backend"
RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/bootc-dev/bootc.git bootc && \
    cd bootc && \
    git fetch --all && \
    git switch origin/composefs-backend -d && \
    make && \
    make install-all && \
    make install-initramfs-dracut

RUN --mount=type=tmpfs,dst=/tmp cd /tmp && \
    git clone https://github.com/p5/coreos-bootupd.git bootupd && \
    cd bootupd && \
    git fetch --all && \
    git switch origin/sdboot-support -d && \
    cargo build --release --bins --features systemd-boot && \
    install -Dpm0755 -t /usr/bin ./target/release/bootupd && \
    ln -s ./bootupd /usr/bin/bootupctl

RUN echo "$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" > kernel_version.txt && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$(cat kernel_version.txt)"  "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img" && \
    cp /usr/src/linux-$(cat kernel_version.txt)/arch/*/boot/bzImage "/usr/lib/modules/$(cat kernel_version.txt)/vmlinuz" && \
    rm kernel_version.txt

# Setup a temporary root passwd (changeme) for dev purposes
# TODO: Replace this for a more robust option when in prod
RUN usermod -p '$6$AJv9RHlhEXO6Gpul$5fvVTZXeM0vC03xckTIjY8rdCofnkKSzvF5vEzXDKAby5p3qaOGTHDypVVxKsCE3CbZz7C3NXnbpITrEUvN/Y/' root

RUN cd / && \
    rm -rf home root usr/local srv var boot && \
    mkdir -p boot sysroot var/home && \
    ln -s /var/home home && \
    ln -s /var/roothome root && \
    ln -s /var/usrlocal usr/local && \
    ln -s /var/srv srv

# Necessary for `bootc install`
RUN echo -e "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true" | tee "/usr/lib/ostree/prepare-root.conf"

LABEL containers.bootc 1
