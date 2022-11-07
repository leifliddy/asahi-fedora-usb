Creates a Fedora usb drive that will boot on Apple M1/M2 systems.   

**note**: There's currently an issue creating a Fedora37 drive with `mkosi`  
I needed to set this in `/usr/lib/python3.10/site-packages/mkosi/__init__.py`  
I'll try and find the proper solution. https://github.com/systemd/mkosi/issues/1263  
```diff
@@ -1988,7 +1988,7 @@ def invoke_dnf(state: MkosiState, comman
     cmdline += [command, *sort_packages(packages)]
 
     with mount_api_vfs(state.root):
-        run(cmdline, env=dict(KERNEL_INSTALL_BYPASS="1"))
+        run(cmdline, env=dict(KERNEL_INSTALL_BYPASS="0"))
 
     distribution, _ = detect_distribution()
     if distribution not in (Distribution.debian, Distribution.ubuntu):
```

**Fedora package install:**  
```
dnf install mkosi arch-install-scripts systemd-container gdisk rsync qemu-user-static
```
**note:** ```qemu-user-static``` is only needed if building on a non-```aarch64``` system. 

To build a minimal Fedora image and install it to a usb drive, simply run:
```
./build.sh -d /dev/sda
```

**note:** substitute ```/dev/sda``` with the device id of your usb drive

If you've previously installed this Fedora image to the usb drive, you can wipe the drive and install a new image without having to repartition/reformat the drive by providing the `-w` argument   
```
./build.sh -wd /dev/sda
```

Once the drive is created, you can locally mount and unmount the usb drive (which contains 3 partitions) to/from ```mnt_usb/``` with 
```
./build.sh mount
./build.sh umount
```
**note:** mounting the usb drive is useful for inspecting the contents of the drive or making changes to it   

To boot the usb drive on an M1 system, enter the following ```u-boot``` command at boot time:
```
run bootcmd_usb0
```

The usb drive is read/write and contains three partitions: ```efi, boot, and root``` (just like a normal system)
