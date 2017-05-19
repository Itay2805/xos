![](https://s21.postimg.org/f81j1t2jb/collage.jpg)
![](https://s15.postimg.org/9zxz9q5a3/collage.jpg)
xOS is a 32-bit graphical operating system written for the PC entirely in assembly language. This results in faster execution, smaller program sizes and overall simplicity. The goal of xOS is to be fully functional, yet small and simple.  

Features
========
xOS is still under early stages of development; although the following features are already implemented:
* PCI and ACPI, with shutdown.
* ATA and SATA hard disks.
* Multitasking and userspace.
* PS/2 keyboard and mouse.
* True-color windowed graphical user interface.

Requirements
============
* A Pentium CPU with SSE2, or better.
* VESA 2.0-compatible BIOS, capable of true-color.
* Little over 32 MB of RAM.
* Few megabytes of disk space.

For building requirements, you'll need [Flat Assembler](http://flatassembler.net) in your `$PATH`. Then, run `make` and it will build xOS. Feel free to tweak with xOS as you like, just please give me feedback. To clean up the working directory afterwards, run `make clean`.

Testing xOS
===========
xOS is provided as a disk image. `disk.hdd` in this repository can be considered the latest nightly build. It is very likely unstable and may crash. Old demo releases are in the "releases" tab. `disk.hdd` is a prebuilt hard disk image that can be used with QEMU or VirtualBox, though it performs best on VirtualBox. If you're tweaking the source and want to build xOS, simply run `make` as said above. To run xOS under QEMU, then `make run`. The Makefile assumes FASM and QEMU are both in your `$PATH`.  
If you want to test xOS on real hardware without dumping the hard disk, use [SYSLINUX MEMDISK](http://www.syslinux.org/wiki/index.php?title=Download) and GRUB or another bootloader to boot xOS from a USB stick, or a hard disk. Use `disk.hdd` as the INITRD of MEMDISK. Any changes made within xOS will then be removed after system reset. xOS has been tested with SYSLINUX 4.07, but should work with other versions too.

Contact
=======
I can be contacted at omarx024@gmail.com. I am also user **omarrx024** on the OSDev Forum.

