#!/bin/bash

OUTFILE=./obs-worker-grub-image.raw
# SIZE in MB
SIZE=10
MOUNT=/mnt
LOOP_DEV=/dev/loop0
PART_DEV=/dev/mapper/loop0p1

OS_IMAGE_NAME=obs-worker-grub-image

dd if=/dev/zero of=$OUTFILE bs=1M count=$SIZE

fdisk $OUTFILE <<EOF
n
p



w
EOF

kpartx -s -a $OUTFILE

mkfs.ext3 $PART_DEV

mount $PART_DEV $MOUNT

mkdir -p $MOUNT/boot/grub2

cat <<EOF > $MOUNT/boot/grub2/grub.cfg
insmod part_msdos
insmod ext2
set root='hd0,msdos1'
set default=1
set timeout=0

serial --unit=0 --speed=115200
terminal_input serial
terminal_output serial


menuentry 'OBS Build' {
        insmod gzio
        insmod part_msdos
        insmod ext2
        search --label obsrootfs --no-floppy --set=root
        #set root='hd1'
        echo    'Loading Linux ...'
        linux   /.build.kernel.kvm root=LABEL=obsrootfs console=ttyS0 init=/sbin/init
        echo    'Loading initial ramdisk ...'
        initrd  /.build.initrd.kvm
}
EOF

grub2-install --boot-directory $MOUNT/boot $LOOP_DEV

umount $MOUNT

kpartx -dv $LOOP_DEV

losetup -d $LOOP_DEV

glance image-create --name $OS_IMAGE_NAME --file $OUTFILE --container-format bare --disk-format raw --progress

exit 0
