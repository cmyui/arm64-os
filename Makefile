# ARM64 bare-metal toolchain
AS = aarch64-none-elf-as
LD = aarch64-none-elf-ld
OBJCOPY = aarch64-none-elf-objcopy

# Output files
KERNEL_ELF = kernel.elf
KERNEL_BIN = kernel.bin
TEST_ELF = kernel_test.elf
BENCH_ELF = kernel_bench.elf

# Common source files (shared between server and tests)
COMMON_SRCS = src/drivers/uart.s \
              src/drivers/virtio.s \
              src/drivers/timer.s \
              src/net/ethernet.s \
              src/net/arp.s \
              src/net/ipv4.s \
              src/net/tcp.s \
              src/net/http.s

# Memory and database sources
MEM_DB_SRCS = src/mem/slab.s \
              src/db/db.s

# SlowAPI framework sources
SLOWAPI_SRCS = src/slowapi/request.s \
               src/slowapi/response.s \
               src/slowapi/router.s \
               src/slowapi/query.s \
               src/slowapi/json.s \
               src/slowapi/string.s \
               src/slowapi/slowapi.s \
               src/app.s

# Server sources
SERVER_SRCS = src/boot.s $(COMMON_SRCS) $(MEM_DB_SRCS) $(SLOWAPI_SRCS)
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
            src/test/test_slowapi.s \
            src/test/test_slab.s \
            src/test/test_db.s \
            src/test/test_query.s \
            src/test/test_json.s \
            $(COMMON_SRCS) \
            $(MEM_DB_SRCS) \
            src/slowapi/request.s \
            src/slowapi/response.s \
            src/slowapi/router.s \
            src/slowapi/query.s \
            src/slowapi/json.s \
            src/slowapi/string.s \
            src/slowapi/slowapi.s \
            src/app.s
TEST_OBJS = $(TEST_SRCS:.s=.o)

# Benchmark sources
BENCH_SRCS = src/bench/bench_main.s \
             src/bench/bench_harness.s \
             src/bench/bench_slab.s \
             src/bench/bench_db.s \
             src/bench/bench_string.s \
             src/bench/bench_json.s \
             src/bench/bench_request.s \
             $(COMMON_SRCS) \
             $(MEM_DB_SRCS) \
             $(SLOWAPI_SRCS)
BENCH_OBJS = $(BENCH_SRCS:.s=.o)

# Flags
ASFLAGS = -g
LDFLAGS = -T linker.ld -nostdlib

.PHONY: all clean run test bench

all: $(KERNEL_ELF)

$(KERNEL_ELF): $(SERVER_OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(SERVER_OBJS)

$(TEST_ELF): $(TEST_OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(TEST_OBJS)

$(BENCH_ELF): $(BENCH_OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(BENCH_OBJS)

$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $< $@

%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f $(SERVER_OBJS) $(TEST_OBJS) $(BENCH_OBJS) $(KERNEL_ELF) $(KERNEL_BIN) $(TEST_ELF) $(BENCH_ELF)

run: $(KERNEL_ELF)
	qemu-system-aarch64 \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-global virtio-mmio.force-legacy=true \
		-kernel $(KERNEL_ELF) \
		-device virtio-net-device,netdev=net0 \
		-netdev user,id=net0,hostfwd=tcp::8888-:80

test: $(TEST_ELF)
	qemu-system-aarch64 \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-global virtio-mmio.force-legacy=true \
		-kernel $(TEST_ELF) \
		-device virtio-net-device,netdev=net0 \
		-netdev user,id=net0

bench: $(BENCH_ELF)
	qemu-system-aarch64 \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-global virtio-mmio.force-legacy=true \
		-kernel $(BENCH_ELF) \
		-device virtio-net-device,netdev=net0 \
		-netdev user,id=net0
