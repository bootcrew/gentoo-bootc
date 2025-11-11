FROM docker.io/gentoo/stage3:latest

# Sync sources and select systemd-based profile
RUN --mount=type=tmpfs,dst=/tmp emerge --sync --quiet && \
    eselect profile list | grep -E -e "default.*[[:digit:]]/systemd" | grep -v 32  | awk '{ print $1 }' | grep -o [[:digit:]] | xargs eselect profile set && \
    echo -e 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox"\nACCEPT_LICENSE="*"\nUSE="dracut nftables"' | tee -a /etc/portage/make.conf && \
    echo "sys-apps/systemd boot" | tee -a /etc/portage/package.use/systemd && \
    emerge --verbose --deep --newuse @world && \
    emerge --verbose app-arch/cpio btrfs-progs dev-vcs/git dosfstools linux-firmware rust skopeo sys-kernel/gentoo-kernel-bin systemd && \
    git clone https://github.com/EWouters/gentoo gentoo -b ostree --depth 1 --single-branch && \
    cd gentoo && ebuild --debug dev-util/ostree/ostree-2025.6.ebuild clean install merge && \
    git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc && \
    make -C /tmp/bootc bin install-all install-initramfs-dracut && \
    rm -rf /var/db

RUN echo "$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" > kernel_version.txt && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$(cat kernel_version.txt)"  "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img" && \
    rm "/usr/lib/modules/$(cat kernel_version.txt)/vmlinuz" && \
    cp -f /usr/src/linux-$(cat kernel_version.txt)/arch/*/boot/bzImage "/usr/lib/modules/$(cat kernel_version.txt)/vmlinuz" && \
    rm kernel_version.txt

# Necessary for general behavior expected by image-based systems
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    rm -rf /boot /home /root /usr/local /srv && \
    mkdir -p /var /sysroot /boot /usr/lib/ostree && \
    ln -s var/opt /opt && \
    ln -s var/roothome /root && \
    ln -s var/home /home && \
    ln -s sysroot/ostree /ostree && \
    echo "$(for dir in opt usrlocal home srv mnt ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo "d /var/roothome 0700 root root -" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    echo "d /run/media 0755 root root -" | tee -a /usr/lib/tmpfiles.d/bootc-base-dirs.conf && \
    printf "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n" | tee "/usr/lib/ostree/prepare-root.conf"

# Setup a temporary root passwd (changeme) for dev purposes
RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

RUN bootc container lint
