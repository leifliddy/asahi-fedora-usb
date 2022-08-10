Creates a Fedora usb drive that will boot on Apple M1/M2 systems.

**Prerequisites:** Ensure ```mkosi``` and ```arch-install-scripts``` (needed for ```arch-chroot```) are installed  
```
# Fedora
dnf install mkosi arch-install-scripts systemd-container gdisk qemu-user-static
# Debian
apt install mkosi arch-install-scripts gdisk systemd-container
# Arch
pacman -S mkosi arch-install-scripts gdisk
```
\*\*in theory you should be able to build this Fedora usb drive on any Linux system that has ```mkosi``` and ```arch-install-scripts``` installed  

To build a minimal Fedora image and install it to a usb drive, simply run:
```
./build.sh -d /dev/sda
```

**substitute ```/dev/sda``` with the device id of your usb drive

Once the drive is created, you can locally mount and unmount the usb drive (which contains 3 partitions) to/from ```mnt_usb/``` with 
```
./build.sh mount
./build.sh umount
```
\*\*mounting the usb drive is useful for inspecting the contents of the drive or making changes to it   

To boot the usb drive on an M1 system, enter the following ```u-boot``` command at boot time:
```
run bootcmd_usb0
```

The usb drive is read/write and contains three partitions: ```efi, boot, and root``` (just like a normal system)  

Also ```dnf``` has cross-architecture support, so you could build this on an x86_64 Fedora system no problem.  
\*\*just ensure ```qemu-user-static``` is installed.   
I don't believe other package managers (```apt``` or ```pacman```) support this feature.  
https://github.com/systemd/mkosi/issues/138
