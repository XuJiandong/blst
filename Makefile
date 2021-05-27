TARGET := riscv64-unknown-linux-gnu
TARGET_B := riscv64-unknown-elf
CKB_VM_CLI := ckb-vm-b-cli

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

all: target/bls12-381-demo target/bls12-381-demo-asm

all_b: target/bls12-381-demo-b

all-via-docker:
	docker run --rm -v `pwd`:/code ${BUILDER_DOCKER} bash -c "cd /code && make all"

all-via-docker-b:
	docker run --rm -v `pwd`:/code ${BUILDER_DOCKER_B} bash -c "cd /code && make all_b"

target/server.o: src/server.c src/no_asm.h
	$(CC) -c -DCKB_DECLARATION_ONLY $(CFLAGS) $(LDFLAGS) -o $@ $<
	#$(CC) -S -c -DCKB_DECLARATION_ONLY $(subst -g,,$(CFLAGS)) -o target/server.S $<

target/server-asm.o: src/server.c src/no_asm.h
	$(CC) -c -DUSE_MUL_MONT_384_ASM -DCKB_DECLARATION_ONLY $(CFLAGS) $(LDFLAGS) -o $@ $<

target/mul_mont_384.o: simulator/mul_mont_384.S
	$(CC) -c -DCKB_DECLARATION_ONLY $(CFLAGS) -o $@ $^

target/bls12-381-demo: simulator/main.c target/server.o
	$(CC) $(CFLAGS) ${LDFLAGS} -o $@ $^

target/bls12-381-demo-asm: simulator/main.c target/server-asm.o target/mul_mont_384.o
	$(CC) $(CFLAGS) ${LDFLAGS} -o $@ $^

#	$(OBJCOPY) --only-keep-debug $@ $@.debug
#	$(OBJCOPY) --strip-debug --strip-all $@

target/server-b.o: src/server.c
	$(CC_B) -c -DCKB_DECLARATION_ONLY $(CFLAGS_B) $(LDFLAGS) -o $@ $^

target/bls12-381-demo-b: simulator/main.c target/server-b.o
	$(CC_B) $(CFLAGS_B) ${LDFLAGS} -o $@ $^

run:
	$(CKB_VM_CLI) --bin target/bls12-381-demo

run_asm:
	$(CKB_VM_CLI) --bin target/bls12-381-demo-asm

run_b:
	$(CKB_VM_CLI) --bin target/bls12-381-demo-b

pprof:
	ckb-vm-pprof --bin target/bls12-381-demo | inferno-flamegraph > target/pprof.svg

pprof-summary:
	ckb-vm-pprof --bin target/bls12-381-demo > target/data.txt
	cat target/data.txt | python3 simulator/folder.py > target/summary.txt

fmt:
	clang-format -i -style=Google $(wildcard simulator/main.c)

clean:
	rm -f target/*

install-tools:
	echo "start to install tool: ckb-vm-cli and ckb-vm-b-cli"
	cargo install --git https://github.com/XuJiandong/ckb-vm-cli.git --branch master
	cargo install --git https://github.com/XuJiandong/ckb-vm-cli.git --branch b-extension

.PHONY: all all-via-docker clean fmt
