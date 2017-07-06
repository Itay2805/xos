![](https://s11.postimg.org/a0wkezumr/Virtual_Box_x_OS_21_06_2017_19_56_32.png)  
![](https://s12.postimg.org/5g8yqjot9/xos_network.png)  
xOS is a graphical operating system written for the PC entirely in assembly language. It aims to be modern and fully functional, yet be fast, small and simple.  

## Features
* **Graphical:** Features a true-color compositing windowing system.
* **Lightweight:** Can boot using less than 32 MB of RAM, and the binaries are less than 1 MB.
* **Networking:** Features a functional TCP/IP stack.
* **Self-hosting:** Can assemble itself under itself.

## Hardware Support
* **CPU:** Practically any x86 CPU with SSE2 support.
* **Storage:** IDE and SATA hard disks.
* **Graphics:** VESA 2.0 or newer.
* **Input:** PS/2 and USB mice and keyboards.
* **Network:** Realtek 8139 and Intel PRO/1000 cards.
* **Others:** PCI, ACPI, and other basic PC hardware.

## Testing xOS
xOS is provided as a disk image. `disk.hdd` in this repository is the latest unstable build. It can be used with QEMU or VirtualBox, but it performs best on VirtualBox. Stabler builds are in the Releases tab. For networking, use one of the Intel PRO/1000 options in VirtualBox settings. To run in QEMU, run `make run`. Instructions for running stabler builds are provided with their readme files.  

## Contact
I can be contacted at omarx024@gmail.com. I am also user **omarrx024** on the OSDev Forum.  

You can find more information on xOS [here](https://omarrx024.github.io/).

