# RISCV should either be unset, or set to point to a directory that contains
# a toolchain install tree that was built via other means.
RISCV ?= $(CURDIR)/toolchain
PATH := $(RISCV)/bin:$(PATH)
MODE ?= raw
RAW_ISA = rv64imafdc_zifencei_zicsr
RAW_ABI = lp64d
SIG_ISA = rv64imafdc_zifencei_zicsr_xsig0p1
SIG_ABI = lps64d
CMAKE := cmake

topdir := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
topdir := $(topdir:/=)
srcdir := $(topdir)/repo
confdir := $(topdir)/conf
wrkdir := $(CURDIR)/build
scriptdir := $(topdir)/scripts
benchdir := $(topdir)/benchmark

toolchain_dest := $(CURDIR)/toolchain

llvm_srcdir	 :=	$(srcdir)/llvm-project
llvm_wrkdir	 :=	$(wrkdir)/llvm-project
llvm_sysroot :=	$(toolchain_dest)/sysroot
LLVM_VERSION :=  Release

freebsd_srcdir := $(srcdir)/freebsd
freebsd_wrkdir := $(wrkdir)/freebsd
freebsd_wrkdir_legacy := $(freebsd_wrkdir)/$(freebsd_srcdir)/riscv.riscv64/tmp/legacy
freebsd_rootfs := $(topdir)/rootfs/freebsd_sysroot
freebsd_rootfs_img := $(freebsd_rootfs).img
freebsd_kernel_full := $(freebsd_wrkdir)/$(freebsd_srcdir)/riscv.riscv64/sys/QEMU/kernel.full
freebsd_kernel := $(freebsd_rootfs)/boot/kernel/kernel
freebsd_bench := $(freebsd_rootfs)/opt
freebsd_usr_local := $(freebsd_rootfs)/usr/local

freebsd_world_done := $(freebsd_wrkdir)/.buildworld.done
freebsd_distribution_done := $(freebsd_wrkdir)/.distribution.done
freebsd_world_metalog := $(freebsd_rootfs)/METALOG.world
freebsd_kernel_metalog := $(freebsd_rootfs)/METALOG.kernel
freebsd_custom_done := $(freebsd_wrkdir)/.custom.done
freebsd_change_flag := $(freebsd_wrkdir)/.change.flag

lmbench_srcdir := $(benchdir)/lmbench
unixbench_srcdir := $(benchdir)/unixbench/UnixBench
simple_sigriscv_test_dir := $(benchdir)/simple-sigriscv-test
unixbench_install := $(freebsd_bench)/unixbench
lmbench_install := $(freebsd_bench)/lmbench
simple_sigriscv_test_install := $(freebsd_bench)/simple_sigriscv_test

opensbi_srcdir := $(srcdir)/opensbi
opensbi_wrkdir := $(wrkdir)/opensbi
fw_jump := $(opensbi_wrkdir)/platform/generic/firmware/fw_jump.elf

qemu_srcdir := $(srcdir)/qemu
qemu_wrkdir := $(wrkdir)/qemu
qemu :=  $(toolchain_dest)/bin/qemu-system-riscv64

gmp_srcdir := $(srcdir)/cross/gmp
gmp_wrkdir := $(wrkdir)/gmp
gmp_lib := $(freebsd_usr_local)/lib/libgmp.so

mpfr_srcdir := $(srcdir)/cross/mpfr
mpfr_wrkdir := $(wrkdir)/mpfr
mpfr_lib := $(freebsd_usr_local)/lib/libmpfr.so

gdb_srcdir := $(srcdir)/gdb
gdb_native_wrkdir := $(wrkdir)/gdb-native
gdb_cross_wrkdir := $(wrkdir)/gdb-cross
gdb_native := $(toolchain_dest)/bin/gdb
gdb_cross := $(freebsd_usr_local)/bin/gdb

.PHONY: llvm
llvm $(toolchain_dest)/bin/clang: $(llvm_srcdir)
	mkdir -p $(llvm_wrkdir) $(toolchain_dest)
	cd $(llvm_wrkdir); $(CMAKE) -G Ninja -DLLVM_ENABLE_PROJECTS="clang;lld" \ \
		-DCMAKE_BUILD_TYPE:String=$(LLVM_VERSION)  -DLLVM_ENABLE_ASSERTIONS=True \
		-DLLVM_USE_SPLIT_DWARF=True \
		-DLLVM_OPTIMIZED_TABLEGEN=True \
		-DCMAKE_INSTALL_PREFIX=$(toolchain_dest) \
		-DLLVM_DEFAULT_TARGET_TRIPLE=riscv64-unknown-linux-gnu \
		-DLLVM_TARGETS_TO_BUILD="RISCV" \
		-DDEFAULT_SYSROOT=$(llvm_sysroot) \
		$(llvm_srcdir)/llvm
	free -h
	$(CMAKE) --build $(llvm_wrkdir) --target install

FREEBSD_ENV := MAKEOBJDIRPREFIX=$(freebsd_wrkdir) \
	X_COMPILER_TYPE=clang \
	CC=/usr/bin/clang \
	CXX=/usr/bin/clang++ \
	CPP=/usr/bin/clang-cpp-18 \
	STRIPBIN=/usr/bin/strip \
	XCC=$(toolchain_dest)/bin/clang \
	XCXX=$(toolchain_dest)/bin/clang++ \
	XCPP=$(toolchain_dest)/bin/clang-cpp \
	XLD=$(toolchain_dest)/bin/ld.lld

FREEBSD_TARGET := TARGET=riscv \
	TARGET_ARCH=riscv64 \
	TARGET_CPUTYPE= 

FREEBSD_WNO := "-Wno-unterminated-string-initialization -Wno-switch \
	-Wno-cast-function-type-mismatch -Wno-unused -Wno-format -Wno-parentheses \
	-Wno-string-plus-int -Wno-address-of-packed-member -Wno-tautological-pointer-compare\
	-Wno-implicit-enum-enum-cast -Wno-empty-body -Wno-incompatible-pointer-types-discards-qualifiers \
	-Wno-tautological-constant-out-of-range-compare -Wno-uninitialized"

FREEBSD_TOOL := LD=$(toolchain_dest)/bin/ld.lld \
	AR=$(toolchain_dest)/bin/llvm-ar \
	NM=$(toolchain_dest)/bin/llvm-nm \
	SIZE=$(toolchain_dest)/bin/llvm-size \
	STRIPBIN=$(toolchain_dest)/bin/llvm-strip \
	STRINGS=$(toolchain_dest)/bin/llvm-strings \
	OBJCOPY=$(toolchain_dest)/bin/llvm-objcopy \
	RANLIB=$(toolchain_dest)/bin/llvm-ranlib \
	LLVM_LINK=$(toolchain_dest)/bin/llvm-link \
	XLD=$(toolchain_dest)/bin/ld.lld \
	XAR=$(toolchain_dest)/bin/llvm-ar \
	XNM=$(toolchain_dest)/bin/llvm-nm \
	XSIZE=$(toolchain_dest)/bin/llvm-size \
	XSTRIPBIN=$(toolchain_dest)/bin/llvm-strip \
	XSTRINGS=$(toolchain_dest)/bin/llvm-strings \
	XOBJCOPY=$(toolchain_dest)/bin/llvm-objcopy \
	XRANLIB=$(toolchain_dest)/bin/llvm-ranlib \
	XLLVM_LINK=$(toolchain_dest)/bin/llvm-link

FREEBSD_OPT := -DDB_FROM_SRC -DI_REALLY_MEAN_NO_CLEAN -DNO_ROOT -DBUILD_WITH_STRICT_TMPPATH -DWITHOUT_EFI \
	-DWITHOUT_CLEAN -DWITH_TESTS -DWITHOUT_INIT_ALL_ZERO -DWITHOUT_INIT_ALL_PATTERN \
	-DWITHOUT_MAN -DWITHOUT_MAIL -DWITH_DISK_IMAGE_TOOLS_BOOTSTRAP -DWITHOUT_PROFILE \
	-DWITHOUT_OFED -DWITH_MALLOC_PRODUCTION -DWITHOUT_GCC -DWITHOUT_CLANG -DWITHOUT_LLD \
	-DWITHOUT_LLDB -DWITHOUT_GCC_BOOTSTRAP -DWITHOUT_CLANG_BOOTSTRAP -DWITHOUT_LLD_BOOTSTRAP \
	-DWITHOUT_LIB32 -DWITH_ELFTOOLCHAIN_BOOTSTRAP -DWITH_TOOLCHAIN -DWITHOUT_BINUTILS_BOOTSTRAP

FREEBSD_ARGS := $(FREEBSD_TARGET) \
	CWARNFLAGS.clang=$(FREEBSD_WNO) \
	$(FREEBSD_TOOL) \
	$(FREEBSD_OPT) -s -de

.PHONY: buildworld buildkernel installworld installkernel distribution freebsd-all
buildworld $(freebsd_world_done): $(freebsd_srcdir) $(toolchain_dest)/bin/clang
	mkdir -p $(freebsd_wrkdir)
	rm -rf $(freebsd_world_done)
	cd $(freebsd_srcdir) && env $(FREEBSD_ENV) \
	nice $(freebsd_srcdir)/tools/build/make.py -j$(shell nproc) buildworld \
		$(FREEBSD_ARGS)
	touch $(freebsd_world_done)
	touch $(freebsd_change_flag)

buildkernel $(freebsd_kernel_full): $(freebsd_world_done) $(confdir)/QEMU $(toolchain_dest)/bin/clang
	rm -rf $(freebsd_kernel_full)
	cp $(confdir)/QEMU $(freebsd_srcdir)/sys/riscv/conf/QEMU
	cd $(freebsd_srcdir) && env $(FREEBSD_ENV) \
	nice $(freebsd_srcdir)/tools/build/make.py -j$(shell nproc) buildkernel \
		'KERNCONF=QEMU' DEBUG=-g $(FREEBSD_ARGS) \
		CONF_CFLAGS="-DSIGRISCV" MACHINE_CPU=sigriscv
	touch $(freebsd_change_flag)

installworld $(freebsd_world_metalog): $(freebsd_world_done)
	rm -rf $(freebsd_rootfs)/METALOG.world
	cd $(freebsd_srcdir) && env $(FREEBSD_ENV) \
		DESTDIR=$(freebsd_rootfs) METALOG=$(freebsd_rootfs)/METALOG.world \
	nice $(freebsd_srcdir)/tools/build/make.py -j$(shell nproc) installworld \
		$(FREEBSD_ARGS) DESTDIR=$(freebsd_rootfs)
	touch $(freebsd_change_flag)

installkernel $(freebsd_kernel_metalog): $(freebsd_kernel_full)
	rm -rf $(freebsd_rootfs)/METALOG.kernel
	cd $(freebsd_srcdir) && env $(FREEBSD_ENV) \
		DESTDIR=$(freebsd_rootfs) METALOG=$(freebsd_rootfs)/METALOG.kernel \
	nice $(freebsd_srcdir)/tools/build/make.py -j$(shell nproc) installkernel \
		'KERNCONF=QEMU' DEBUG=-g $(FREEBSD_ARGS) DESTDIR=$(freebsd_rootfs)
	touch $(freebsd_change_flag)

distribution $(freebsd_distribution_done): $(freebsd_kernel_metalog) $(freebsd_world_metalog)
	rm -rf $(freebsd_distribution_done)
	cd $(freebsd_srcdir) && env $(FREEBSD_ENV) \
		DESTDIR=$(freebsd_rootfs) METALOG=$(freebsd_rootfs)/METALOG.world \
	nice $(freebsd_srcdir)/tools/build/make.py -j$(shell nproc) distribution \
		$(FREEBSD_ARGS) DESTDIR=$(freebsd_rootfs)
	touch $(freebsd_distribution_done)
	touch $(freebsd_change_flag)

freebsd-all: buildworld buildkernel installworld installkernel distribution

freebsd_custom $(freebsd_custom_done): $(freebsd_rootfs)/root/.shrc
	echo "export LD_LIBRARY_PATH=/usr/local/lib:\$LD_LIBRARY_PATH" >> $(freebsd_rootfs)/root/.shrc
	touch $(freebsd_custom_done)
	touch $(freebsd_change_flag)

.PHONY: disk-image
disk-image $(freebsd_rootfs_img) : $(freebsd_distribution_done) $(freebsd_world_metalog) $(freebsd_kernel_metalog) $(freebsd_change_flag) $(freebsd_custom_done)
	cp -r $(confdir)/freebsd_conf/* $(freebsd_rootfs)
	python3 $(scriptdir)/get_mainfest.py $(freebsd_rootfs) $(freebsd_wrkdir)/METALOG.custom
	cd $(freebsd_rootfs) && $(freebsd_wrkdir_legacy)/bin/makefs -t ffs \
		-o version=2,label=root -o softupdates=1 -Z -b 2g -f 200k -R 4m -M 256m \
		-B le -N $(freebsd_rootfs)/etc  \
		$(freebsd_rootfs).root.img $(freebsd_wrkdir)/METALOG.custom
	cd $(freebsd_rootfs) && $(freebsd_wrkdir_legacy)/bin/mkimg -s gpt \
		-p freebsd-ufs:=$(freebsd_rootfs).root.img \
		-p freebsd-swap/swap::2G \
		-o $(freebsd_rootfs_img)
	rm -f $(freebsd_rootfs).root.img
	$(toolchain_dest)/bin/qemu-img info $(freebsd_rootfs).img

LLVM_CROSS_TOOLCHAIN := CC=$(toolchain_dest)/bin/clang \
		AS=$(toolchain_dest)/bin/clang \
		CXX=$(toolchain_dest)/bin/clang++ \
		LD=$(toolchain_dest)/bin/ld.lld \
		AR=$(toolchain_dest)/bin/llvm-ar \
		NM=$(toolchain_dest)/bin/llvm-nm \
		OBJCOPY=$(toolchain_dest)/bin/llvm-objcopy \
		OBJDUMP=$(toolchain_dest)/bin/llvm-objdump \
		READELF=$(toolchain_dest)/bin/readelf \
		STRIP=$(toolchain_dest)/bin/llvm-strip \
		RANLIB=$(toolchain_dest)/bin/llvm-ranlib

LLVM_CROSS_CFLAGS := -target riscv64-unknown-freebsd16 \
			--sysroot=$(freebsd_rootfs) -B$(toolchain_dest)/bin \
			-mno-relax -menable-experimental-extensions

LLVM_CROSS_RAWCFLAGS := $(LLVM_CROSS_CFLAGS) -march=$(RAW_ISA) -mabi=$(RAW_ABI)

LLVM_CROSS_RAWLDFLAGS := $(LLVM_CROSS_RAWCFLAGS) -fuse-ld=lld \
			--ld-path=$(toolchain_dest)/bin/ld.lld

ifeq ($(MODE),raw)
LLVM_CROSS_CFLAGS += -march=$(RAW_ISA) -mabi=$(RAW_ABI)
else ifeq ($(MODE),sig)
LLVM_CROSS_CFLAGS += -march=$(SIG_ISA) -mabi=$(SIG_ABI)
else
$(error "Unknown MODE $(MODE), please set MODE to raw or sig")
endif

LLVM_CROSS_NOWARN := -Wno-error=unused-command-line-argument -Werror=implicit-function-declaration \
			-Werror=format -Werror=incompatible-pointer-types -Werror=pass-failed \
			-Werror=undefined-internal -Wno-unused-command-line-argument \
			-Wno-error=incompatible-pointer-types-discards-qualifiers

LLVM_CROSS_CFLAGS_NOWARN = $(LLVM_CROSS_CFLAGS) $(LLVM_CROSS_NOWARN)

LLVM_CROSS_LDFLAGS := $(LLVM_CROSS_CFLAGS) -fuse-ld=lld \
			--ld-path=$(toolchain_dest)/bin/ld.lld

.PHONY: lmbench
lmbench: $(lmbench_srcdir) $(freebsd_rootfs)
	make -C $(lmbench_srcdir) clean
	make -C $(lmbench_srcdir) build \
		OS=riscv-FreeBSD \
		$(LLVM_CROSS_TOOLCHAIN) \
		CFLAGS="$(LLVM_CROSS_CFLAGS_NOWARN) -O0 -g" \
		LDFLAGS="$(LLVM_CROSS_LDFLAGS)"
	mkdir -p $(lmbench_install)/src
	mkdir -p $(lmbench_install)/$(MODE)
	cp $(lmbench_srcdir)/bin/riscv-FreeBSD/* $(lmbench_install)/$(MODE)/
	cp $(lmbench_srcdir)/src/*.c $(lmbench_install)/src/
	cp $(lmbench_srcdir)/src/*.h $(lmbench_install)/src/
	touch $(freebsd_change_flag)

.PHONY: unixbench
unixbench: $(unixbench_srcdir) $(freebsd_rootfs)
	make -C $(unixbench_srcdir) clean
	make -C $(unixbench_srcdir) \
		OSNAME=freebsd \
		$(LLVM_CROSS_TOOLCHAIN) \
		CFLAGS="$(LLVM_CROSS_CFLAGS_NOWARN) -O1 -g" \
		LDFLAGS="$(LLVM_CROSS_LDFLAGS)" \
		RAWCFLAGS="$(LLVM_CROSS_RAWCFLAGS)" \
		RAWLDFLAGS="$(LLVM_CROSS_RAWLDFLAGS)"
	mkdir -p $(unixbench_install)/src
	mkdir -p $(unixbench_install)/$(MODE)
	cp $(unixbench_srcdir)/pgms/* $(unixbench_install)/$(MODE)
	cp $(unixbench_srcdir)/testdir/sort.src $(unixbench_install)/$(MODE)
	cp $(unixbench_srcdir)/src/* $(unixbench_install)/src/
	cp $(unixbench_srcdir)/.gdbinit $(unixbench_install)/$(MODE)/
	touch $(freebsd_change_flag)

.PHONY: simple_sigriscv_test
simple_sigriscv_test: $(simple_sigriscv_test_dir) $(freebsd_rootfs)
	$(MAKE) -C $(simple_sigriscv_test_dir)
	$(MAKE) -C $(simple_sigriscv_test_dir) install PREFIX=$(freebsd_bench)
	touch $(freebsd_change_flag)

LLVM_CROSS_TARGET := --prefix=$(freebsd_usr_local) \
		--host=riscv64-unknown-freebsd16 \
		--target=riscv64-unknown-freebsd16 \
		--build=x86_64-pc-linux-gnu

LLVM_CROSS_COMPILE_ARGS := CC='$(toolchain_dest)/bin/clang $(LLVM_CROSS_CFLAGS) $(LLVM_CROSS_LDFLAGS)' \
		CXX='(toolchain_dest)/bin/clang++ $(LLVM_CROSS_CFLAGS) $(LLVM_CROSS_LDFLAGS)' \
		CPP='$(toolchain_dest)/bin/clang-cpp  $(LLVM_CROSS_CFLAGS_NOWARN) $(LLVM_CROSS_LDFLAGS)' \
		CFLAGS='$(LLVM_CROSS_CFLAGS_NOWARN)' \
		CXXFLAGS='$(LLVM_CROSS_CFLAGS_NOWARN)' \
		LDFLAGS='$(LLVM_CROSS_LDFLAGS)'

.PHONY: gmp-cross
gmp-cross $(gmp_lib): $(gmp_srcdir) $(freebsd_rootfs)
	mkdir -p $(gmp_wrkdir)
	cd $(gmp_srcdir) && ./.bootstrap
	cd $(gmp_wrkdir) && $</configure \
		$(LLVM_CROSS_TARGET) \
		$(LLVM_CROSS_TOOLCHAIN) \
		$(LLVM_CROSS_COMPILE_ARGS)
	cd $(gmp_wrkdir) && $(MAKE) -j$(shell nproc)
	cd $(gmp_wrkdir) && $(MAKE) install
	touch $(freebsd_change_flag)

.PHONY: mpfr-cross
mpfr-cross $(mpfr_lib): $(mpfr_srcdir) $(freebsd_rootfs)
	mkdir -p $(mpfr_wrkdir)
	cd $(mpfr_srcdir) && ./autogen.sh
	cd $(mpfr_wrkdir) && $</configure \
		--with-gmp=$(freebsd_usr_local) \
		$(LLVM_CROSS_TARGET) \
		$(LLVM_CROSS_TOOLCHAIN) \
		$(LLVM_CROSS_COMPILE_ARGS)
	cd $(mpfr_wrkdir) && $(MAKE) -j$(shell nproc)
	cd $(mpfr_wrkdir) && $(MAKE) install
	touch $(freebsd_change_flag)
	

GDB_LLVM_CROSS_CFLAGS_NOWARN := $(LLVM_CROSS_CFLAGS_NOWARN) -O2 -fcommon -DRL_NO_COMPAT -DLIBICONV_PLUG

.PHONY: gdb-cross
gdb-cross $(gdb_cross): $(gdb_srcdir) $(gmp_lib) $(mpfr_lib)
	mkdir -p $(gdb_cross_wrkdir)
	cd $(gdb_cross_wrkdir) && $</configure \
		--with-gmp=$(freebsd_usr_local) \
		--with-mpfr=$(freebsd_usr_local) \
		--disable-shared --disable-nls --disable-libstdcxx --enable-tui \
		--disable-ld --disable-gold --disable-sim --enable-64-bit-bfd --without-gnu-as \
		--enable-targets=all --without-python --without-expat --without-libunwind-ia64 \
		$(LLVM_CROSS_TARGET) \
		$(LLVM_CROSS_TOOLCHAIN) \
		CC='$(toolchain_dest)/bin/clang $(GDB_LLVM_CROSS_CFLAGS_NOWARN)' \
		CXX='$(toolchain_dest)/bin/clang++ $(GDB_LLVM_CROSS_CFLAGS_NOWARN)' \
		CPP='$(toolchain_dest)/bin/clang-cpp  $(GDB_LLVM_CROSS_CFLAGS_NOWARN)' \
		CFLAGS='$(GDB_LLVM_CROSS_CFLAGS_NOWARN)' \
		CXXFLAGS='$(GDB_LLVM_CROSS_CFLAGS_NOWARN)' \
		LDFLAGS='-lelf -lmd $(LLVM_CROSS_LDFLAGS)'
	$(MAKE) -C $(gdb_cross_wrkdir) -j$(shell nproc) all-gdb
	$(MAKE) -C $(gdb_cross_wrkdir) -j$(shell nproc) all-binutils
	$(MAKE) -C $(gdb_cross_wrkdir) -j$(shell nproc) all-ld
	$(MAKE) -C $(gdb_cross_wrkdir) install-gdb
	touch $(freebsd_change_flag)

fw_image $(fw_jump): $(opensbi_srcdir) $(toolchain_dest)/bin/clang
	mkdir -p $(opensbi_wrkdir)
	$(MAKE) -C $(opensbi_srcdir) FW_TEXT_START=0x80000000 \
		PLATFORM=generic O=$(opensbi_wrkdir) CROSS_COMPILE=riscv64-unknown-linux-gnu- \
		LLVM=$(toolchain_dest)/bin/ \
		PLATFORM_RISCV_ISA=rv64gc_xsig0p1 \
		SIGRISCV=y \
		firmware-cflags-y="-menable-experimental-extensions -Wno-error=incompatible-pointer-types-discards-qualifiers" \
		firmware-asflags-y="-menable-experimental-extensions"


.PHONY: qemu

qemu $(qemu): $(qemu_srcdir)
	mkdir -p $(qemu_wrkdir)
	mkdir -p $(toolchain_dest)
	cd $(qemu_wrkdir) && $</configure \
		--disable-docs \
		--prefix=$(toolchain_dest) \
		--target-list=riscv64-linux-user,riscv64-softmmu \
		--extra-cflags="-DTARGET_SIGRISCV"
	$(MAKE) -C $(qemu_wrkdir)
	$(MAKE) -C $(qemu_wrkdir) install
	touch -c $@

.PHONY: gdb-native
gdb-native $(gdb_native): $(gdb_srcdir)
	mkdir -p $(gdb_native_wrkdir)
	cd $(gdb_native_wrkdir) && $</configure \
		--disable-nls --enable-tui --disable-ld --disable-libstdcxx \
		--disable-gold --disable-sim --disable-werror \
		--enable-64-bit-bfd --without-gnu-as \
		--prefix=$(toolchain_dest) \
		--enable-targets=all \
		CC=/usr/bin/clang CXX=/usr/bin/clang++ \
		CFLAGS='-O2 -fcommon' CXXFLAGS='-O2 -fcommon' \
		LDFLAGS='-latomic'
	$(MAKE) -C $(gdb_native_wrkdir) -j$(shell nproc) all-gdb
	$(MAKE) -C $(gdb_native_wrkdir) -j$(shell nproc) all-binutils
	$(MAKE) -C $(gdb_native_wrkdir) -j$(shell nproc) all-ld
	$(MAKE) -C $(gdb_native_wrkdir) install-gdb


.PHONY: clean mrproper
clean:
	rm -rf -- $(wrkdir)

mrproper:
	rm -rf -- $(wrkdir) $(toolchain_dest) $(topdir)/rootfs

.PHONY: qemu-run

qemu-run: 
	$(qemu) -M virt -m 2048 -nographic -bios $(fw_jump) \
		-kernel $(freebsd_kernel) \
		-drive if=none,file=$(freebsd_rootfs_img),id=drv,format=raw \
		-device virtio-blk-device,drive=drv \
		-device virtio-rng-pci \
		-virtfs local,path=/home/zyy/sigriscv/riscv-spike-sdk/benchmark/unixbench/UnixBench/src,mount_tag=unixbench_src,security_model=none

qemu-debug: $(qemu) $(fw_jump) $(freebsd_rootfs_img)
	$(qemu) -M virt -m 2048 -nographic -bios $(fw_jump) \
		-kernel $(freebsd_kernel) \
		-drive if=none,file=$(freebsd_rootfs_img),id=drv,format=raw \
		-device virtio-blk-device,drive=drv \
		-device virtio-rng-pci -S -s

qemu-link: $(gdb_native)
	$(gdb_native) $(freebsd_kernel)
