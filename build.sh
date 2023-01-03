#!/bin/bash

set -e

img_name='fedora.raw'
mnt_img='image_mnt'
mnt_usb='mnt_usb'

EFI_UUID='3051-D434'
ROOT_UUID='d747cb2a-aff1-4e47-8a33-c4d9b7475df9'


if [ "$(whoami)" != 'root' ]; then
    echo "You must be root to run this script."
    exit 1
fi


while getopts d:w arg
do
    case "${arg}" in
        d) usb_device=${OPTARG};;
        w) wipe=true ;;
    esac
done

get_loop_dev() {
    loop_dev=$(losetup -l | grep $img_name | grep -v '(deleted)' | awk '{print $1}')
}

mount_image() {
    echo '### Mounting raw image...'
    get_loop_dev
    [[ -z $loop_dev ]] && losetup -f -P $img_name && get_loop_dev && sleep 1

    esp_part=${loop_dev}p1
    root_part=${loop_dev}p2

    [[ -z "$(findmnt -n $mnt_img)" ]] && mount $root_part $mnt_img
    [[ -z "$(findmnt -n $mnt_img/efi)" ]] && mount $esp_part $mnt_img/efi

    sleep 1
}

umount_image() {
    # unmounts image from image_mnt
    loop_dev=$(losetup -l | grep $img_name | awk '{print $1}')

    if [ ! "$(findmnt -n $mnt_img)" ]; then
        return
    fi
    echo '### Unmounting raw image...'
    [[ "$(findmnt -n $mnt_img/efi)" ]] && umount $mnt_img/efi
    [[ "$(findmnt -n $mnt_img)" ]] && umount $mnt_img

    [[ -n $loop_dev ]] && losetup -d $loop_dev
}

mount_usb() {
    # mounts an existing usb drive to mnt_usb/ so you can inspect the contents or chroot into it...etc
    echo '### Mounting usb partitions...'
    sleep 1
    # first try to mount the usb partitions via their uuid
    if [ $(blkid | egrep -i "$EFI_UUID|$ROOT_UUID" | wc -l) -eq 2 ]; then
        [[ -z "$(findmnt -n $mnt_usb)" ]] && mount -U $ROOT_UUID $mnt_usb
        mkdir -p $mnt_usb/efi
        [[ -z "$(findmnt -n $mnt_usb/efi)" ]] && mount -U $EFI_UUID $mnt_usb/efi
    else
        # otherwise mount via the device id
        if [ -z $usb_device ]; then
            echo -e "\nthe usb device can't be mounted via the uuid values"
            echo -e "\ntherefore you must specify the usb device ie\n./build.sh -d /dev/sda mount\n"
            exit
        fi
        [[ -z "$(findmnt -n $mnt_usb)" ]] && mount ${usb_device}2 $mnt_usb
        mkdir -p $mnt_usb/efi
        [[ -z "$(findmnt -n $mnt_usb/efi)" ]] && mount ${usb_device}1 $mnt_usb/efi
    fi

    sleep 1
    systemctl daemon-reload
}

umount_usb() {
    # unmounts usb drive from mnt_usb/
    if [ ! "$(findmnt -n $mnt_usb)" ]; then
        return
    fi

    echo '### Unmounting usb partitions...'
    [[ "$(findmnt -n $mnt_usb/efi)" ]] && umount $mnt_usb/efi
    [[ "$(findmnt -n $mnt_usb)" ]] && umount $mnt_usb
}

wipe_usb() {
    # wipe the contents of the usb drive to avoid having to repartition it

    # first check if the paritions exist
    if [ $(blkid | egrep -i "$EFI_UUID|$ROOT_UUID" | wc -l) -eq 2 ]; then
        [[ -z "$(findmnt -n $mnt_usb)" ]] && mount -U $ROOT_UUID $mnt_usb
        if [ -e $mnt_usb/efi ]; then
            [[ -z "$(findmnt -n $mnt_usb/efi)" ]] && mount -U $EFI_UUID $mnt_usb/efi
        fi
    fi

    if [ ! "$(findmnt -n $mnt_usb)" ]; then
        echo -e '### The usb drive did not mount\nparitioning disk...\n'
        wipe=false
        return
    fi

    echo '### Wiping usb partitions...'
    [[ "$(findmnt -n $mnt_usb/efi)" ]] && rm -rf $mnt_usb/efi/* && umount $mnt_usb/efi
    [[ "$(findmnt -n $mnt_usb)" ]] && rm -rf $mnt_usb/* && umount $mnt_usb
}

# ./build.sh mount
#  or
# ./build.sh umount
#  to mount or unmount a usb drive (that was previously created by this script) to/from mnt_usb/
if [[ $1 == 'mount' ]]; then
    mount_usb
    exit
elif [[ $1 == 'umount' ]] || [[ $1 == 'unmount' ]]; then
    umount_usb
    exit
elif [[ $1 == 'image' ]]; then
    mount_image
    exit
elif [[ $1 == 'uimage' ]] || [[ $1 == 'imageu' ]]; then
    umount_image
    exit
fi

[[ -z $usb_device ]] && echo -e "\nyou must specify a usb device ie\n./build.sh -d /dev/sda\n" && exit
[[ ! -e $usb_device ]] && echo -e "\n$usb_device doesn't exist\n" && exit

mkdir -p $mnt_img $mnt_usb


prepare_usb_device() {
    umount_usb
    echo '### Preparing USB device...'
    # create 5GB root partition
    #echo -e 'o\ny\nn\n\n\n+2G\nef00\nn\n\n\n+1G\n8300\nw\ny\n' | gdisk "$usb_device"
    # root parition will take up all remaining space
    echo -e 'o\ny\nn\n\n\n+2G\nef00\nn\n\n\n\n8300\nw\ny\n' | gdisk $usb_device
    mkfs.vfat -F 32 -n 'EFI-USB-FED' -i $(echo $EFI_UUID | tr -d '-') ${usb_device}1 || mkfs.vfat -F 32 -n 'EFI-USB-FED' -i $(echo $EFI_UUID | tr -d '-') ${usb_device}p1
    mkfs.ext4 -O '^metadata_csum' -U $ROOT_UUID -L 'fedora-usb-root' -F ${usb_device}2 || mkfs.ext4 -O '^metadata_csum' -U $ROOT_UUID -L 'fedora-usb-root' -F ${usb_device}p2
    systemctl daemon-reload

    if [ $(blkid | grep -Ei "$EFI_UUID|$ROOT_UUID" | wc -l) -ne 2 ]; then
        echo -e "\nthe partitions and/or filesystem were not created correctly on $usb_device\nexiting...\n"
        exit
    fi
}

mkosi_create_image() {
    umount_image
    mkosi clean
    rm -rf .mkosi-*
    wget https://leifliddy.com/asahi-linux/asahi-linux.repo -O mkosi.skeleton/etc/yum.repos.d/asahi-linux.repo
    mkosi
}

install_usb() {
    # ensure image is mounted
    mount_image
    # ensure usb drive is not mounted
    mount_usb
    echo '### Rsyncing files...'
    rsync -aHAX --delete --exclude={"/dev/*","/proc/*","/sys/*","/lost+found/","/efi/*"} $mnt_img/ $mnt_usb
    rsync -aHA  --delete $mnt_img/efi/ $mnt_usb/efi
    umount_image
    echo '### Setting uuids for partitions in /etc/fstab...'
    sed -i "s/EFI_UUID_PLACEHOLDER/$EFI_UUID/" $mnt_usb/etc/fstab
    sed -i "s/ROOT_UUID_PLACEHOLDER/$ROOT_UUID/" $mnt_usb/etc/fstab
    echo "### Setting systemd-boot timeout value..."
    sed -i 's/#timeout.*$/timeout 5/' $mnt_usb/efi/loader/loader.conf
    # adding a small delay prevents this error msg from polluting the console
    # device (wlan0): interface index 2 renamed iface from 'wlan0' to 'wlp1s0f0'
    echo "### Adding delay to NetworkManager.service..."
    sed -i '/ExecStart=.*$/iExecStartPre=/usr/bin/sleep 2' $mnt_usb/usr/lib/systemd/system/NetworkManager.service
    echo "### Enabling system services..."
    chroot $mnt_usb systemctl enable NetworkManager.service sshd.service
    echo "### Remove unneeded efi image..."
    rm -f $mnt_usb/efi/EFI/Linux/*.efi
    # selinux enforcing mode still needs to be fully tested out
    # probably a good idea to run restorecon -Rv / after the first boot
    echo "### Setting selinux to permissive"
    sed -i 's/^SELINUX=.*$/SELINUX=permissive/' $mnt_usb/etc/selinux/config
    umount_usb
    echo '### Done'
}

# if -w argument is specified
# ie
# ./build.sh -wd /dev/sda
# and the disk partitions already exist (from a previous install)
# then remove the files from disk vs repartitioning it
# warning: this feature is experimental
[[ $wipe = true ]] && wipe_usb || prepare_usb_device
mkosi_create_image
install_usb
