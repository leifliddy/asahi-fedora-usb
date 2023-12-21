#!/bin/bash

set -e

mkosi_output='mkosi.output'
mkosi_rootfs="$mkosi_output/image"
mkosi_cache='mkosi.cache'
mnt_usb="$(pwd)/mnt_usb"
mkosi_supported_version=19

EFI_UUID='3051-D434'
BOOT_UUID='a1492762-3fe2-4908-a8b9-118439becd26'
ROOT_UUID='d747cb2a-aff1-4e47-8a33-c4d9b7475df9'

if [[ $USER != 'root' ]]; then
    echo 'You must run this script as root'
    exit
elif [[ -n $SUDO_USER ]] && [[ $SUDO_USER != 'root' ]]; then
    echo "You must run this script as root and not with sudo"
    exit
fi

[ ! -d $mnt_usb ] && mkdir $mnt_usb
[ ! -d $mkosi_output ] && mkdir $mkosi_output
[ ! -d $mkosi_cache ] && mkdir $mkosi_cache

# specify the usb device with the -d argument
while getopts :d:w arg
do
    case "${arg}" in
        d) usb_device=${OPTARG};;
        w) wipe=true;;
    esac
done

shift "$((OPTIND-1))"

[[ -z $usb_device ]] && echo "usage ./build -d [usb_device]" && exit
[[ -n $usb_device ]] && [[ ! -b $usb_device ]] && echo $usb_device is not a block device && exit

check_mkosi() {
    mkosi_cmd=$(command -v mkosi || true)
    [[ -z $mkosi_cmd ]] && echo 'mkosi is not installed...exiting' && exit
    mkosi_version=$(mkosi --version | awk '{print $2}')

    if [[ $mkosi_version -ne $mkosi_supported_version ]]; then
        echo "mkosi path:    $mkosi_cmd"
        echo "mkosi version: $mkosi_version"
        echo -e "\nthis project was built with mkosi version $mkosi_supported_version"
        echo "please install that version to continue"
        exit
    fi
}

mount_usb() {
    # mounts an existing usb drive to mnt_usb/ so you can inspect the contents or chroot into it...etc
    systemctl daemon-reload
    sleep 1
    # first try to mount the usb partitions via their uuid
    if [ $(blkid | grep -Ei "$EFI_UUID|$BOOT_UUID|$ROOT_UUID" | wc -l) -eq 3 ]; then
        [[ -z "$(findmnt -n $mnt_usb)" ]] && mount -U $ROOT_UUID $mnt_usb
        [[ -z "$(findmnt -n $mnt_usb/boot)" ]] && mount -U $BOOT_UUID $mnt_usb/boot
        [[ -z "$(findmnt -n $mnt_usb/boot/efi)" ]] && mount -U $EFI_UUID $mnt_usb/boot/efi
        # we need this since we're using set -e
        return 0
    else
        # otherwise mount via the device id
        if [[ -z $usb_device ]]; then
            echo -e "\nthe usb device can't be mounted via the uuid values"
            echo -e "\ntherefore you must specify the usb device ie\n./build.sh -d /dev/sda mount\n"
            exit
        fi
        [[ -z "$(findmnt -n $mnt_usb)" ]] && mount "$usb_device"3 $mnt_usb
        [[ -z "$(findmnt -n $mnt_usb/boot)" ]] && mount "$usb_device"2 $mnt_usb/boot
        [[ -z "$(findmnt -n $mnt_usb/boot/efi)" ]] && mount "$usb_device"1 $mnt_usb/boot/efi
    fi
}

umount_usb() {
    # if $usb_device is specified then ensure all partitions from the drive are unmounted
    # this is needed for new usb devices and for systems that auto-mount usb devices
    if [[ -n $usb_device ]]; then
        for partition in ${usb_device}?*; do
            [[ -n "$(findmnt -n $partition)" ]] && umount $partition
        done
        return 0
    fi

    # umounts usb drive from mnt_usb/
    echo '### Checking to see if usb drive is mounted to mnt_usb'
    if [ ! "$(findmnt -n $mnt_usb)" ]; then
        return 0
    fi

    echo '### Unmounting usb partitions'
    [[ "$(findmnt -n $mnt_usb/boot/efi)" ]] && umount $mnt_usb/boot/efi
    [[ "$(findmnt -n $mnt_usb/boot)" ]] && umount $mnt_usb/boot
    [[ "$(findmnt -n $mnt_usb)" ]] && umount $mnt_usb
}

wipe_usb() {
    # wipe the contents of the usb drive to avoid having to repartition it
    # first check if the partitions exist
    umount_usb

    if [ $(blkid | grep -Ei "$EFI_UUID|$BOOT_UUID|$ROOT_UUID" | wc -l) -eq 3 ]; then
        [[ -z "$(findmnt -n $mnt_usb)" ]] && mount -U $ROOT_UUID $mnt_usb
        if [ -e $mnt_usb/boot ]; then
            [[ -z "$(findmnt -n $mnt_usb/boot)" ]] && mount -U $BOOT_UUID $mnt_usb/boot
        fi
        if [ -e $mnt_usb/boot/efi ]; then
            [[ -z "$(findmnt -n $mnt_usb/boot/efi)" ]] && mount -U $EFI_UUID $mnt_usb/boot/efi
        fi
    fi

    if [ ! "$(findmnt -n $mnt_usb)" ]; then
        echo -e '### The usb drive did not mount\nparitioning disk\n'
        wipe=false
        return
    fi

    echo '### Wiping usb partitions'
    [[ "$(findmnt -n $mnt_usb/boot/efi)" ]] && rm -rf $mnt_usb/boot/efi/* && umount $mnt_usb/boot/efi
    [[ "$(findmnt -n $mnt_usb/boot)" ]] && rm -rf $mnt_usb/boot/* && umount $mnt_usb/boot
    [[ "$(findmnt -n $mnt_usb)" ]] && rm -rf $mnt_usb/* && umount $mnt_usb
}

# ./build.sh mount
# ./build.sh umount
# ./build chroot
#  to mount, unmount, or chroot into the usb drive (that was previously created by this script) to/from mnt_usb
if [[ $1 == 'mount' ]]; then
    echo "### Mounting to $mnt_usb"
    mount_usb
    exit
elif [[ $1 == 'umount' ]] || [[ $1 == 'unmount' ]]; then
    echo "### Umounting from $mnt_usb"
    umount_usb
    exit
elif [[ $1 == 'chroot' ]]; then
    mount_usb
    echo "### Chrooting into $mnt_usb"
    arch-chroot $mnt_usb
    exit
elif [[ -n $1 ]]; then
    echo "$1 isn't a recogized option"
fi

[[ -z $usb_device ]] && echo -e "\nyou must specify a usb device ie\n./build.sh -d /dev/sda\n" && exit
[[ ! -e $usb_device ]] && echo -e "\n$usb_device doesn't exist\n" && exit


prepare_usb_device() {
    umount_usb
    is_mounted=$(lsblk -no MOUNTPOINT $usb_device | sed '/^$/d')
    [[ -n "$is_mounted" ]] && echo -e "\n### The usb drive is currently mounted here\n\n$(lsblk $usb_device)\n\n### Please unmount the drive and then re-run the script\n" && exit
    echo '### Preparing USB device'
    # create 5GB root partition
    #echo -e 'o\ny\nn\n\n\n+600M\nef00\nn\n\n\n+1G\n8300\nn\n\n\n+5G\n8300\nw\ny\n' | gdisk "$usb_device"
    # root partition will take up all remaining space\
    echo -e 'o\ny\nn\n\n\n+600M\nef00\nn\n\n\n+1G\n8300\nn\n\n\n\n8300\nw\ny\n' | gdisk $usb_device
    mkfs.vfat -F 32 -n 'EFI-USB-FED' -i $(echo $EFI_UUID | tr -d '-') "$usb_device"1 || mkfs.vfat -F 32 -n 'EFI-USB-FED' -i $(echo $EFI_UUID | tr -d '-') "$usb_device"p1
    mkfs.ext4 -U $BOOT_UUID -L 'fedora-usb-boot' -F "$usb_device"2 || mkfs.ext4 -U $BOOT_UUID -L 'fedora-usb-boot' -F "$usb_device"p2
    mkfs.ext4 -U $ROOT_UUID -L 'fedora-usb-root' -F "$usb_device"3 || mkfs.ext4 -U $ROOT_UUID -L 'fedora-usb-root' -F "$usb_device"p3
    # reserved for future use: kernel 6.7
    #mkfs.f2fs -U $ROOT_UUID -l 'fedora-usb-root' -f "$usb_device"3 || mkfs.f2fs -U $ROOT_UUID -l 'fedora-usb-root' -f "$usb_device"p3
    systemctl daemon-reload

    if [ $(blkid | grep -Ei "$EFI_UUID|$BOOT_UUID|$ROOT_UUID" | wc -l) -ne 3 ]; then
        echo -e "\nthe partitions and/or filesystem were not created correctly on $usb_device\nexiting\n"
        exit
    fi
}

mkosi_create_rootfs() {
    umount_usb
    mkosi clean
    mkosi
}

install_usb() {
    umount_usb
    echo '### Cleaning up'
    rm -f $mkosi_rootfs/var/cache/dnf/*
    echo '### Mounting usb partitions and copying files'
    mount -U $ROOT_UUID $mnt_usb
    rsync -aHAX --delete --exclude '/tmp/*' --exclude '/boot/*' --exclude '/efi' $mkosi_rootfs/ $mnt_usb
    mount -U $BOOT_UUID $mnt_usb/boot
    rsync -aHAX --delete $mkosi_rootfs/boot/ $mnt_usb/boot
    # mkosi >=v18 creates the following symlink in /boot: efi -> ../efi
    [[ -L $mnt_usb/boot/efi ]] && rm -f $mnt_usb/boot/efi && mkdir $mnt_usb/boot/efi
    mount -U $EFI_UUID $mnt_usb/boot/efi
    echo "rsync -aH $mkosi_rootfs/efi/ $mnt_usb/boot/efi"
    rsync -aH $mkosi_rootfs/efi/ $mnt_usb/boot/efi
    echo '### Setting uuids for partitions in /etc/fstab'
    sed -i "s/EFI_UUID_PLACEHOLDER/$EFI_UUID/" $mnt_usb/etc/fstab
    sed -i "s/BOOT_UUID_PLACEHOLDER/$BOOT_UUID/" $mnt_usb/etc/fstab
    sed -i "s/ROOT_UUID_PLACEHOLDER/$ROOT_UUID/" $mnt_usb/etc/fstab
    sed -i "s/BOOT_UUID_PLACEHOLDER/$BOOT_UUID/" $mnt_usb/boot/efi/EFI/fedora/grub.cfg

    echo '### Running systemd-machine-id-setup'
    # generate a machine-id
    [[ -f $mnt_usb/etc/machine-id ]] && rm -f $mnt_usb/etc/machine-id
    chroot $mnt_usb systemd-machine-id-setup
    chroot $mnt_usb echo "KERNEL_INSTALL_MACHINE_ID=$(cat /etc/machine-id)" > /etc/machine-info

    echo -e '\n### Generating EFI bootloader'
    arch-chroot $mnt_usb create-efi-bootloader

    echo "### Creating BLS (/boot/loader/entries/) entry"
    arch-chroot $mnt_usb grub2-editenv create
    rm -f $mnt_usb/etc/kernel/cmdline
    arch-chroot $mnt_usb /image.creation/create.bls.entry

    echo -e '\n### Generating GRUB config'
    # /etc/grub.d/30_uefi-firmware creates a uefi grub boot entry that doesn't work on this platform
    chroot $mnt_usb chmod -x /etc/grub.d/30_uefi-firmware
    arch-chroot $mnt_usb grub2-mkconfig -o /boot/grub2/grub.cfg

    echo "### Enabling system services"
    arch-chroot $mnt_usb systemctl enable NetworkManager sshd systemd-resolved

    echo "### Disabling systemd-firstboot"
    chroot $mnt_usb rm -f /usr/lib/systemd/system/sysinit.target.wants/systemd-firstboot.service

    echo "### SElinux labeling filesystem"
    arch-chroot $mnt_usb setfiles -F -p -c /etc/selinux/targeted/policy/policy.* -e /proc -e /sys -e /dev /etc/selinux/targeted/contexts/files/file_contexts /
    arch-chroot $mnt_usb setfiles -F -p -c /etc/selinux/targeted/policy/policy.* -e /proc -e /sys -e /dev /etc/selinux/targeted/contexts/files/file_contexts /boot

    ###### post-install cleanup ######
    echo -e '\n### Cleanup'
    rm -f  $mnt_usb/etc/kernel/{entry-token,install.conf}
    rm -rf $mnt_usb/image.creation
    rm -f  $mnt_usb/etc/dracut.conf.d/initial-boot.conf
    rm -f  $mnt_usb/etc/yum.repos.d/mkosi*.repo
    # not sure how/why a $mnt_usb/root/asahi-fedora-usb directory is being created
    # remove it like this to account for it being named something different
    find $mnt_usb/root/ -maxdepth 1 -mindepth 1 -type d | grep -Ev '/\..*$' | xargs rm -rf

    echo '### Unmounting usb partitions'
    umount $mnt_usb/boot/efi
    umount $mnt_usb/boot
    umount $mnt_usb
    echo '### Done'
}

check_mkosi
# if -w argument is specified
# ie
# ./build.sh -wd /dev/sda
# and the disk partitions already exist (from a previous install)
# then remove the files from disk vs repartitioning it
[[ $wipe = true ]] && wipe_usb || prepare_usb_device
[[ $(command -v getenforce) ]] && setenforce 0
mkosi_create_rootfs
install_usb
