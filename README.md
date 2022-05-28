Creates a Fedora usb drive that will boot on Apple M1 systems.

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
Also ```mkosi``` has cross-architecture support, so you could build this on an x86_64 system no problem.  
\*\*I'll provide more in-depth documentation later...
