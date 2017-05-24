
all:
	if [ ! -d "out" ]; then mkdir out; fi
	if [ ! -d "out/xfs" ]; then mkdir out/xfs; fi
	dd if=/dev/zero bs=512 count=71568 of=disk.hdd
	fasm kernel/boot/mbr.asm out/mbr.bin
	fasm kernel/boot/boot_hdd.asm out/boot_hdd.bin
	fasm kernel/kernel.asm out/kernel32.sys
	fasm tmp/rootnew.asm out/rootnew.bin
	fasm hello/hello.asm out/hello.exe
	fasm draw/draw.asm out/draw.exe
	fasm buttontest/buttontest.asm out/buttontest.exe
	fasm calc/calc.asm out/calc.exe
	fasm shell/shell.asm out/shell.exe
	fasm 2048/2048.asm out/2048.exe
	fasm monitor/monitor.asm out/monitor.exe

	dd if=out/mbr.bin conv=notrunc bs=512 count=1 of=disk.hdd
	dd if=out/boot_hdd.bin conv=notrunc bs=512 seek=63 of=disk.hdd
	dd if=out/rootnew.bin conv=notrunc bs=512 seek=64 of=disk.hdd
	dd if=out/kernel32.sys conv=notrunc bs=512 seek=200 of=disk.hdd
	dd if=out/hello.exe conv=notrunc bs=512 seek=1021 of=disk.hdd
	dd if=out/draw.exe conv=notrunc bs=512 seek=1022 of=disk.hdd
	dd if=out/buttontest.exe conv=notrunc bs=512 seek=1042 of=disk.hdd
	dd if=out/calc.exe conv=notrunc bs=512 seek=1062 of=disk.hdd
	dd if=out/shell.exe conv=notrunc bs=512 seek=1000 of=disk.hdd
	dd if=wp/wp2.bmp conv=notrunc bs=512 seek=8000 of=disk.hdd
	dd if=shell/shell.cfg conv=notrunc bs=512 seek=1020 of=disk.hdd
	dd if=out/2048.exe conv=notrunc bs=512 seek=1200 of=disk.hdd
	dd if=out/monitor.exe conv=notrunc bs=512 seek=1221 of=disk.hdd

run:
	qemu-system-i386 -drive file=disk.hdd,format=raw -m 128 -vga std -serial stdio -usbdevice mouse

runsata:
	qemu-system-i386 -m 128 -vga std -serial stdio -device ahci,id=ahci -drive if=none,file=disk.hdd,id=xosdrive,format=raw -device ide-drive,drive=xosdrive,bus=ahci.0 -usbdevice mouse

runusb:
	qemu-system-i386 -m 128 -vga std -serial stdio -usbdevice disk:disk.hdd -usbdevice mouse

runohci:
	qemu-system-i386 -m 128 -vga std -serial stdio -hda disk.hdd -device pci-ohci,id=usbohci -device usb-mouse,bus=usbohci.0 -device usb-kbd,bus=usbohci.0

clean:
	if [ -d "out/xfs" ]; then rm out/xfs/*; rmdir out/xfs; fi
	if [ -d "out" ]; then rm out/*; rmdir out; fi


