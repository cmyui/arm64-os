# ARM64 bare-metal toolchain
AS = aarch64-none-elf-as
LD = aarch64-none-elf-ld
OBJCOPY = aarch64-none-elf-objcopy

# Output files
KERNEL_ELF = kernel.elf
KERNEL_BIN = kernel.bin
TEST_ELF = kernel_test.elf

# Common source files (shared between server and tests)
COMMON_SRCS = src/drivers/uart.s \
              src/drivers/virtio.s \
              src/net/ethernet.s \
              src/net/arp.s \
              src/net/ipv4.s \
              src/net/tcp.s \
              src/net/http.s

# Server sources
SERVER_SRCS = src/boot.s $(COMMON_SRCS)
SERVER_OBJS = $(SERVER_SRCS:.s=.o)

# Test sources
TEST_SRCS = src/test/test_main.s \
            src/test/test_harness.s \
            src/test/test_virtio.s \
            src/test/test_ethernet.s \
            src/test/test_arp.s \
            src/test/test_ipv4.s \
            src/test/test_tcp.s \
            src/test/test_http.s \
            $(COMMON_SRCS)
TEST_OBJS = $(TEST_SRCS:.s=.o)

# Flags
ASFLAGS = -g
LDFLAGS = -T linker.ld -nostdlib

.PHONY: all clean run test

all: $(KERNEL_ELF)

$(KERNEL_ELF): $(SERVER_OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(SERVER_OBJS)

$(TEST_ELF): $(TEST_OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(TEST_OBJS)

$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $< $@

%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f $(SERVER_OBJS) $(TEST_OBJS) $(KERNEL_ELF) $(KERNEL_BIN) $(TEST_ELF)

run: $(KERNEL_ELF)
	qemu-system-aarch64 \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-global virtio-mmio.force-legacy=false \
		-kernel $(KERNEL_ELF) \
		-device virtio-net-device,netdev=net0 \
		-netdev user,id=net0,hostfwd=tcp::8080-:80

test: $(TEST_ELF)
	qemu-system-aarch64 \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-global virtio-mmio.force-legacy=false \
		-kernel $(TEST_ELF) \
		-device virtio-net-device,netdev=net0 \
		-netdev user,id=net0
