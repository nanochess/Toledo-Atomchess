all : toledo_atomchess_disk.bin atomr.bin

clean : ; rm -f toledo_atomchess_disk.bin atomr.bin

toledo_atomchess_disk.bin : toledo_atomchess.asm
	nasm -f bin $^ -o $@

atomr.bin : toledo_atomchess_reloaded.asm
	nasm -f bin $^ -o $@
