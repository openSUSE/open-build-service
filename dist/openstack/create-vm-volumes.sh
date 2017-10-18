#!/bin/bash

worker_prefix='worker'
NUM=2

VM_BOOT_IMAGE_NAME=obs-worker-grub-image
VM_BOOT_SIZE=1
VM_ROOT_SIZE=4
VM_SWAP_SIZE=1

while [ $1 ];do
  OPT=$1
  shift
  case $OPT in 
    -p|--prefix)    WORKER_PREFIX=$1;shift;;
    -r|--root-size) VM_ROOT_SIZE=$1;shift;;
    -b|--boot-size) VM_BOOT_SIZE=$1;shift;;
    -s|--swap-size) VM_SWAP_SIZE=$1;shift;;
    -n|--number)    NUM=$1;shift;;
    -t|--templat)   VM_BOOT_IMAGE_NAME=1;shift;;
  esac
done


for i in $(seq 1 $NUM)
do
	echo "Creating volumes for worker$i"
	VM_BOOT_NAME=$WORKER_PREFIX$i\-grub-image
	VM_ROOT_NAME=$WORKER_PREFIX$i\-root
	VM_SWAP_NAME=$WORKER_PREFIX$i\-swap
	cinder create --image $VM_BOOT_IMAGE_NAME --name $VM_BOOT_NAME $VM_BOOT_SIZE
        cinder create --name $VM_ROOT_NAME $VM_ROOT_SIZE
        cinder create --name $VM_SWAP_NAME $VM_SWAP_SIZE
	cinder set-bootable $VM_BOOT_NAME true
done
