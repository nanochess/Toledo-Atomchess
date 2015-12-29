Toledo Atomchess
(c) Copyright 2015 Oscar Toledo G.

http://www.nanochess.org/
https://github.com/nanochess

This Github repository contains the x86 assembler source code
for Toledo Atomchess and Toledo Atomchess Reloaded.

Toledo Atomchess allows the player to play against the computer,
the computer only plays basic legal chess movements, no promotion,
no castling and no enpassant. All this in 397 bytes bootable from
a floppy disk or 388 bytes if using the COM file.

Toledo Atomchess Reloaded allows full chess movements and
currently sizes up to 779 bytes.

Check the source code for further details.

In order to assemble it, you must download the Netwide Assembler
(nasm) from www.nasm.us

Use this command line:

  nasm -f bin toledo_atomchess.asm -o toledo_atomchess_disk.bin
  nasm -f bin toledo_atomchess_reloaded.asm -o atomr.bin

It can be run with DosBox or qemu:
  
  qemu-system-x86_64 -fda toledo_atomchess_disk.bin
  qemu-system-x86_64 -fda atomr.bin

Thanks to HellMood for suggesting the translation of Toledo
Atomchess to nasm syntax and some optimization suggestions.

Also thanks to Peter Ferrie (qkumba) for suggestions.

Enjoy it!

Useful links: 

Original homepage of Toledo Atomchess
  http://nanochess.org/chess6.html
