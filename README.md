Creates a Fedora usb drive that will boot on Apple M1/M2 systems.   

**Fedora package install:**  
```
dnf install arch-install-scripts bubblewrap gdisk qemu-user-static pandoc rsync systemd-container
```
**note:** ```qemu-user-static``` is only needed if building on a non-```aarch64``` system.  

**note:** until this PR is merged into the next `mkosi` release https://github.com/systemd/mkosi/pull/1264/commits  
install mksoi from main:   
`python3 -m pip install --user git+https://github.com/systemd/mkosi.git`  


To build a minimal Fedora image and install it to a usb drive, simply run:
```
./build.sh -d /dev/sda
```

**note:** substitute ```/dev/sda``` with the device id of your usb drive

If you've previously installed this Fedora image to the usb drive, you can wipe the drive and install a new image without having to repartition/reformat the drive by providing the `-w` argument   
```
./build.sh -wd /dev/sda
```

Once the drive is created, you can locally mount and unmount the usb drive (which contains 2 partitions) to/from ```mnt_usb/``` with 
```
./build.sh mount
./build.sh umount
```
**note:** mounting the usb drive is useful for inspecting the contents of the drive or making changes to it   

To boot the usb drive on an M1 system, enter the following ```u-boot``` commands at boot time:
```
env set boot_efi_bootmgr
run usb_boot
```
If anyone knows an easier method to boot a usb drive -- please let me know   
  
**Setting up WiFi**

To connect to a wireless network, use the following sytanx:
```nmcli dev wifi connect network-ssid```

An actual example:
```nmcli dev wifi connect blacknet-ac password supersecretpassword```
