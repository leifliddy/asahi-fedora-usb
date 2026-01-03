Creates a Fedora usb drive that will boot on Apple M-series systems (that have Asahi Linux installed on the internal hard drive!!!)

## Fedora Package Install
```dnf install arch-install-scripts bubblewrap dosfstools e2fsprogs gdisk mkosi openssl pandoc rsync systemd-container```

#### Notes

- The root password is **fedora**  
- The ```qemu-user-static``` package is needed if building the image on a ```non-aarch64``` system  
- This project will work with mkosi versions less then or equal to `mkosi v23`
  If needed, you can always install a specific version via pip  
  `python3 -m pip install --user git+https://github.com/systemd/mkosi.git@v23`


To build a minimal Fedora image and install it to a usb drive, simply run:
```
./build.sh -d /dev/sda
```

**note:** substitute ```/dev/sda``` with the device id of your usb drive

If you've previously installed this Fedora image to the usb drive, you can wipe the drive and install a new image without having to repartition/reformat the drive by providing the `-w` argument
```
./build.sh -wd /dev/sda
```

Once the drive is created, you can locally mount, unmount, or chroot into the usb drive (which contains 3 partitions) to/from ```mnt_usb/``` with
```
./build.sh mount
./build.sh umount
./build.sh chroot
```
**note:** mounting the usb drive is useful for inspecting the contents of the drive or making changes to it



**Setting up WiFi**

To connect to a wireless network, use the following sytanx:
```nmcli dev wifi connect network-ssid```

An actual example:
```nmcli dev wifi connect blacknet-ac password supersecretpassword```

**Rescuing a Fedora install**

Two helper scripts have been added to this image  
Which are useful if you have Fedora installed on the internal drive:
```
/usr/local/sbin/chroot.asahi
/usr/local/sbin/umount.asahi
```
1. `chroot.asahi` will mount the (Fedora) internal drive under `/mnt` and will `arch-chroot` into it.  
To exit from the `chroot` environment, simply type `ctrl+d` or `exit`

2. `umount.asahi` will unmount the internal drive from `/mnt`



**Booting the USB drive**  

There are two methods (that I use) to boot a usb drive: **u-boot eficonfig** and **modifying the grub config**

1. **u-boot eficonfig**  
   Power on the system while the usb drive is connected.

type eficonfig at the u-boot prompt


<img src=https://github.com/user-attachments/assets/9e9aceee-07d5-430c-929e-56149f016748 width="100" height="100">

then go to "Change Boot Order"


<img src=https://github.com/user-attachments/assets/ff262948-9f1b-4b92-95af-aba1942ae5e3 width="100" height="100">


Now change the boot order.  
I would check `usb0` as well as the First `Fedora` entry.  
**note:** to get `usb0` on the top (like in the pic). I deselected everything except for `usb0` and hit Save.  
I then went back to "Change Boot Order" (this time usb0 was on top) and selected `Fedora`  
I'm pretty sure that you need `usb0` to be on top.  


<img src=https://github.com/user-attachments/assets/83472294-bcf4-48dd-b7e0-9e634f7ca937 width="100" height="100">


From here, simply hit `Save`, then `Quit` (you could also hit the escape key twice).
This will bring you back to the `u-boot` prompt.  
From the `u-boot prompt`: simply type `run bootcmd` or `bootd` to boot the system. 


<img src=https://github.com/user-attachments/assets/a4759bb8-4eea-4566-bc92-dab7bf84ee97 width="100" height="100">

You should now be presented with the grub menu of the usb drive. What "should" happen at this point is that  
if you boot with the usb drive connnected, the usb drive should boot. If usb drive is disconnected, the system should   
boot from the internal drive. 

2. **modifying the grub config** (on the internal drive)
   This couldn't be easier.
   After creating the usb drive, ensure the usb drive is plugged in and run:  
   `grub2-mkconfig -o /boot/grub2/grub.cfg`  
   You should now see a `/dev/sda3` entry in the grub menu when booting from the internal drive. 

   
<img src=https://github.com/user-attachments/assets/031862d3-cf70-471e-a41d-7dac48f2723f width="100" height="100">
