#!/bin/bash

NUM=2
VM_BOOT_IMAGE_NAME=obs-worker-grub-image
VM_BOOT_SIZE=1
VM_ROOT_SIZE=4
VM_SWAP_SIZE=1

for i in $(seq 1 $NUM)
do
	echo "Creating volumes for worker$i"
	VM_BOOT_NAME=worker$i\-grub-image
	VM_ROOT_NAME=worker$i\-root
	VM_SWAP_NAME=worker$i\-swap
	cinder create --image $VM_BOOT_IMAGE_NAME --name $VM_BOOT_NAME $VM_BOOT_SIZE
        cinder create --name $VM_ROOT_NAME $VM_ROOT_SIZE
        cinder create --name $VM_SWAP_NAME $VM_SWAP_SIZE
	cinder set-bootable $VM_BOOT_NAME true
done
