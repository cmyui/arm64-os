#!/bin/bash
qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -nographic \
    -kernel kernel.elf \
    -device virtio-net-device,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::8080-:80
