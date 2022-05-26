Creates a Fedora usb drive that will boot on Apple M1 systems.

To build a minimal Fedora image and install it to a usb drive, simply run:
```
./build -d /dev/sda
```

**substitute ```/dev/sda``` with the device id of your usb drive

Upon completion, you can mount and unmount the usb drive (which contains 3 partition) to/from ```mnt_usb/``` with 
```
./build mount
./build umount
```

To boot the usb drive on an M1 system, enter the following ```u-boot``` command and boot time:
```
run bootcmd_usb0
```

The usb drive is read/write and contains three partitions efi, boot, and root (just like a normal system)  
\*\*I'll provide more documentation later...
