# Gentoo Bootc

Gentoo base image for Bootc!

<img width="1520" height="667" alt="image" src="https://github.com/user-attachments/assets/169a29b4-02f6-4f5f-bff9-fdfc42713746" />

## Building

In order to get a running gentoo-bootc system you can run the following steps:
```shell
just build-containerfile # This will build the containerfile and all the dependencies you need
just generate-bootable-image # Generates a bootable image for you using bootc!
```

Then you can run the `bootable.img` as your boot disk in your preferred hypervisor.

# Fixes

- `mount /dev/vda2 /sysroot/boot` - You need this to get `bootc status` and other stuff working
