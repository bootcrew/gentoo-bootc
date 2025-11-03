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

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    git clone https://github.com/bootc-dev/bootc.git /tmp/bootc && \
    cd /tmp/bootc && \
    make bin install-all install-initramfs-dracut

RUN echo "$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" > kernel_version.txt && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$(cat kernel_version.txt)"  "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img" && \
    rm "/usr/lib/modules/$(cat kernel_version.txt)/vmlinuz" && \
    cp -f /usr/src/linux-$(cat kernel_version.txt)/arch/*/boot/bzImage "/usr/lib/modules/$(cat kernel_version.txt)/vmlinuz" && \
    rm kernel_version.txt

# Setup a temporary root passwd (changeme) for dev purposes
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

RUN rm -rf /var /boot /home /root /usr/local /srv && \
    mkdir -p /var /boot /sysroot && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/srv /srv && \
    ln -s sysroot/ostree ostree && \
    ln -s /var/usrlocal /usr/local

# Update useradd default to /var/home instead of /home for User Creation
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd"

# Necessary for `bootc install`
RUN mkdir -p /usr/lib/ostree && \
    printf  "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n" | \
    tee "/usr/lib/ostree/prepare-root.conf"

RUN bootc container lint
