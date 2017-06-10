
all:
	if [ ! -d "out" ]; then mkdir out; fi
	if [ ! -d "out/libxos" ]; then mkdir out/libxos; fi
	dd if=/dev/zero bs=512 count=71568 of=disk.hdd
	fasm kernel/boot/mbr.asm out/mbr.bin
	fasm kernel/boot/boot_hdd.asm out/boot_hdd.bin
	fasm kernel/kernel.asm out/kernel32.sys
	fasm tmp/rootnew.asm out/rootnew.bin
	fasm tmp/drivers.asm out/drivers.bin
	fasm tmp/netio.asm out/netio.bin
	fasm tmp/fsusage.asm out/fsusage.bin
	fasm hello/hello.asm out/hello.exe
	fasm draw/draw.asm out/draw.exe
	fasm buttontest/buttontest.asm out/buttontest.exe
	fasm calc/calc.asm out/calc.exe
	fasm shell/shell.asm out/shell.exe
	fasm 2048/2048.asm out/2048.exe
	fasm monitor/monitor.asm out/monitor.exe
	fasm rtl8139/rtl8139.asm out/rtl8139.sys
	fasm fasm/source/xos/fasm.asm out/fasm.exe
	fasm i8254x/i8254x.asm out/i8254x.sys

	fasm libxos/src/interface.asm out/libxos/interface.o
	gcc -c -Ilibxos/include -m32 -nostdlib -nostartfiles -nodefaultlibs -fomit-frame-pointer -mno-red-zone libxos/src/init.c -o out/libxos/init.o
	gcc -c -Ilibxos/include -m32 -nostdlib -nostartfiles -nodefaultlibs -fomit-frame-pointer -mno-red-zone libxos/src/window.c -o out/libxos/window.o
	gcc -c -Ilibxos/include -m32 -nostdlib -nostartfiles -nodefaultlibs -fomit-frame-pointer -mno-red-zone libxos/src/event.c -o out/libxos/event.o
	gcc -c -Ilibxos/include -m32 -nostdlib -nostartfiles -nodefaultlibs -fomit-frame-pointer -mno-red-zone libxos/src/label.c -o out/libxos/label.o

	gcc -c -Ilibxos/include -m32 -nostdlib -nostartfiles -nodefaultlibs -fomit-frame-pointer -mno-red-zone helloc/helloc.c -o out/helloc.o
	gcc -m32 -nostdlib -nostartfiles -nodefaultlibs -fomit-frame-pointer -mno-red-zone -T libxos/link.ld out/libxos/interface.o out/libxos/init.o out/libxos/window.o out/libxos/label.o out/libxos/event.o out/helloc.o -o out/helloc.exe

	dd if=out/mbr.bin conv=notrunc bs=512 count=1 of=disk.hdd
	dd if=out/boot_hdd.bin conv=notrunc bs=512 seek=63 of=disk.hdd
	dd if=out/rootnew.bin conv=notrunc bs=512 seek=64 of=disk.hdd
	dd if=out/fsusage.bin conv=notrunc bs=512 seek=52563 of=disk.hdd
	dd if=out/drivers.bin conv=notrunc bs=512 seek=1300 of=disk.hdd
	dd if=out/netio.bin conv=notrunc bs=512 seek=1301 of=disk.hdd
	dd if=out/kernel32.sys conv=notrunc bs=512 seek=200 of=disk.hdd
	dd if=out/hello.exe conv=notrunc bs=512 seek=1021 of=disk.hdd
	dd if=out/draw.exe conv=notrunc bs=512 seek=1022 of=disk.hdd
	dd if=out/buttontest.exe conv=notrunc bs=512 seek=1042 of=disk.hdd
	dd if=out/calc.exe conv=notrunc bs=512 seek=1062 of=disk.hdd
	dd if=out/shell.exe conv=notrunc bs=512 seek=1000 of=disk.hdd
	dd if=wp/wp4.bmp conv=notrunc bs=512 seek=8000 of=disk.hdd
	dd if=shell/shell.cfg conv=notrunc bs=512 seek=1020 of=disk.hdd
	dd if=out/2048.exe conv=notrunc bs=512 seek=1200 of=disk.hdd
	dd if=out/monitor.exe conv=notrunc bs=512 seek=1221 of=disk.hdd
	dd if=out/rtl8139.sys conv=notrunc bs=512 seek=1302 of=disk.hdd
	dd if=out/fasm.exe conv=notrunc bs=512 seek=1400 of=disk.hdd
	dd if=out/i8254x.sys conv=notrunc bs=512 seek=1311 of=disk.hdd
	dd if=out/helloc.exe conv=notrunc bs=512 seek=1801 of=disk.hdd

run:
	qemu-system-i386 -drive file=disk.hdd,format=raw -m 128 -vga std -serial stdio -usbdevice mouse -net nic,model=rtl8139 -net user -net dump,file=qemudump.pcap

runsata:
	qemu-system-i386 -m 128 -vga std -serial stdio -device ahci,id=ahci -drive if=none,file=disk.hdd,id=xosdrive,format=raw -device ide-drive,drive=xosdrive,bus=ahci.0 -usbdevice mouse -net nic,model=rtl8139 -net user -net dump,file=qemudump.pcap

runusb:
	qemu-system-i386 -m 128 -vga std -serial stdio -usbdevice disk:disk.hdd -usbdevice mouse -net nic,model=rtl8139 -net user -net dump,file=qemudump.pcap

runohci:
	qemu-system-i386 -m 128 -vga std -serial stdio -hda disk.hdd -device pci-ohci,id=usbohci -device usb-mouse,bus=usbohci.0 -device usb-kbd,bus=usbohci.0 -net nic,model=rtl8139 -net user -net dump,file=qemudump.pcap

clean:
	if [ -d "out/libxos" ]; then rm out/libxos/*; rmdir out/libxos; fi
	if [ -d "out" ]; then rm out/*; rmdir out; fi


