TARGET := riscv64-unknown-linux-gnu
CC := $(TARGET)-gcc
LD := $(TARGET)-gcc
OBJCOPY := $(TARGET)-objcopy

CFLAGS := -O3 -fPIC -fno-builtin-printf -nostdinc -nostdlib -nostartfiles \
-fdata-sections -ffunction-sections -I bindings -I deps/ckb-c-stdlib -I deps/ckb-c-stdlib/libc \
-Wall -Werror -Wno-nonnull -Wno-nonnull-compare -Wno-unused-function -g

LDFLAGS := -Wl,-static -Wl,--gc-sections

# docker pull nervos/ckb-riscv-gnu-toolchain:gnu-bionic-20191012
BUILDER_DOCKER := nervos/ckb-riscv-gnu-toolchain@sha256:aae8a3f79705f67d505d1f1d5ddc694a4fd537ed1c7e9622420a470d59ba2ec3

all: target/bls12-381-demo


all-via-docker:
	docker run --rm -v `pwd`:/code ${BUILDER_DOCKER} bash -c "cd /code && make all"

target/server.o: src/server.c
	$(CC) -c -DCKB_DECLARATION_ONLY $(CFLAGS) $(LDFLAGS) -o $@ $^

target/bls12-381-demo: simulator/main.c target/server.o
	$(CC) $(CFLAGS) ${LDFLAGS} -o $@ $^
#	$(OBJCOPY) --only-keep-debug $@ $@.debug
#	$(OBJCOPY) --strip-debug --strip-all $@

run:
	ckb-vm-cli --bin target/bls12-381-demo

pprof:
	ckb-vm-pprof --bin target/bls12-381-demo | inferno-flamegraph > target/pprof.svg

pprof-summary:
	ckb-vm-pprof --bin target/bls12-381-demo | python3 simulator/folder.py > target/summary.txt


fmt:
	clang-format -i -style=Google $(wildcard simulator/main.c)

clean:
	rm -f target/*

.PHONY: all all-via-docker clean fmt
