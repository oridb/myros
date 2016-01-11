#!/bin/sh

tmp=`mktemp -d`
mkdir -p $tmp/isofiles/boot/grub
cp kernel $tmp/isofiles/boot/kernel.bin
cp grub.cfg $tmp/isofiles/boot/grub
grub-mkrescue -o $1 $tmp/isofiles
rm -r $tmp/isofiles
