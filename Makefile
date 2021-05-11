TARGET := riscv64-unknown-linux-gnu
TARGET_B := riscv64-unknown-elf

CC := $(TARGET)-gcc
LD := $(TARGET)-gcc
OBJCOPY := $(TARGET)-objcopy

CC_B := $(TARGET_B)-gcc
LD_B := $(TARGET_B)-gcc
OBJCOPY_B := $(TARGET_B)-objcopy

CFLAGS := -O3 -fPIC -fno-builtin-printf -nostdinc -nostdlib -nostartfiles \
-fdata-sections -ffunction-sections -I bindings -I deps/ckb-c-stdlib -I deps/ckb-c-stdlib/libc \
-Wall -Werror -Wno-nonnull -Wno-nonnull-compare -Wno-unused-function -g

CFLAGS_B := -march=rv64gb $(CFLAGS)

LDFLAGS := -Wl,-static -Wl,--gc-sections

# docker pull nervos/ckb-riscv-gnu-toolchain:gnu-bionic-20191012
BUILDER_DOCKER := nervos/ckb-riscv-gnu-toolchain@sha256:aae8a3f79705f67d505d1f1d5ddc694a4fd537ed1c7e9622420a470d59ba2ec3

# docker pull mohanson/ckb-riscv64b-unknown-elf:20210510
BUILDER_DOCKER_B := mohanson/ckb-riscv64b-unknown-elf:20210510

all: target/bls12-381-demo

all_b: target/bls12-381-demo-b

all-via-docker:
	docker run --rm -v `pwd`:/code ${BUILDER_DOCKER} bash -c "cd /code && make all"

all-via-docker-b:
	docker run --rm -v `pwd`:/code ${BUILDER_DOCKER_B} bash -c "cd /code && make all_b"


target/server.o: src/server.c
	$(CC) -c -DCKB_DECLARATION_ONLY $(CFLAGS) $(LDFLAGS) -o $@ $^

target/bls12-381-demo: simulator/main.c target/server.o
	$(CC) $(CFLAGS) ${LDFLAGS} -o $@ $^
#	$(OBJCOPY) --only-keep-debug $@ $@.debug
#	$(OBJCOPY) --strip-debug --strip-all $@

target/server-b.o: src/server.c
	$(CC_B) -c -DCKB_DECLARATION_ONLY $(CFLAGS_B) $(LDFLAGS) -o $@ $^

target/bls12-381-demo-b: simulator/main.c target/server-b.o
	$(CC_B) $(CFLAGS_B) ${LDFLAGS} -o $@ $^

run:
	ckb-vm-cli --bin target/bls12-381-demo

run_b:
	ckb-vm-b-cli --bin target/bls12-381-demo-b

pprof:
	ckb-vm-pprof --bin target/bls12-381-demo | inferno-flamegraph > target/pprof.svg

pprof-summary:
	ckb-vm-pprof --bin target/bls12-381-demo | python3 simulator/folder.py > target/summary.txt


fmt:
	clang-format -i -style=Google $(wildcard simulator/main.c)

clean:
	rm -f target/*

.PHONY: all all-via-docker clean fmt
