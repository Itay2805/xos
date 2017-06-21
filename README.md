![](https://s11.postimg.org/a0wkezumr/Virtual_Box_x_OS_21_06_2017_19_56_32.png)
![](https://s12.postimg.org/5g8yqjot9/xos_network.png)
xOS is a graphical operating system written for the PC entirely in assembly language. It aims to be modern and fully functional, yet be fast, small and simple.  

## Features
* True-color compositing graphical user interface.
* PCI and ACPI, with shutdown.
* ATA and SATA hard disks.
* Multitasking and userspace.
* USB 1.1 keyboards and mice.
* Networking stack with rudimentary web browser.

## Requirements
* A Pentium CPU with SSE2, or better.
* VESA 2.0-compatible BIOS, capable of true-color.
* Little over 32 MB of RAM.
* Few megabytes of disk space.
* Optional compatible network card. Currently supported cards are RTL8139 and Intel i8254x (aka E1000).

For building requirements, you'll need [Flat Assembler](http://flatassembler.net) in your `$PATH`, as well as any version of GCC/binutils capable of generating 32-bit binaries. Then, run `make` and it will build xOS to `disk.hdd`. Feel free to tweak with xOS as you like, just please give me feedback. To clean up the working directory afterwards, run `make clean`.

## Testing xOS
xOS is provided as a disk image. `disk.hdd` in this repository can be considered the latest nightly build. It contains the latest development changes, but is very likely unstable and may crash. More stable builds are in the "Releases" tab. `disk.hdd` is a prebuilt hard disk image that can be used with QEMU or VirtualBox, though it performs best on VirtualBox. If you're tweaking the source and want to build xOS, simply run `make` as said above. To run xOS under QEMU, then `make run`. For networking on VirtualBox, set the emulated network card to any of the Intel PRO/1000 options, and set the networking type to NAT. Support for bridged networking is still being improved. The Makefile assumes FASM and QEMU are both in your `$PATH`. Instructions running stabler builds are provided in their readme files.  

## Contact
I can be contacted at omarx024@gmail.com. I am also user **omarrx024** on the OSDev Forum.  

You can find more information on xOS [here](https://omarrx024.github.io/).

