# RISCV should either be unset, or set to point to a directory that contains
# a toolchain install tree that was built via other means.
RISCV ?= $(CURDIR)/toolchain
PATH := $(RISCV)/bin:$(PATH)
MODE ?= raw
JULIET_BRANCH ?=
RAW_ISA = rv64imafd_zifencei_zicsr
RAW_ABI = lp64d
SIG_ISA = rv64imafd_zifencei_zicsr_xsig0p1
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
llvm_debug_wrkdir := $(wrkdir)/llvm-project-debug
llvm_sysroot :=	$(toolchain_dest)/sysroot
LLVM_VERSION :=  Release
LLVM_DEBUG_VERSION := Debug

freebsd_srcdir := $(srcdir)/freebsd
freebsd_wrkdir := $(wrkdir)/freebsd
freebsd_wrkdir_legacy := $(freebsd_wrkdir)/$(freebsd_srcdir)/riscv.riscv64/tmp/legacy
freebsd_rootfs := $(topdir)/rootfs/freebsd_sysroot
freebsd_rootfs_img := $(freebsd_rootfs).img
freebsd_rootfs_conf := QEMU_MIN
freebsd_kernel_full := $(freebsd_wrkdir)/$(freebsd_srcdir)/riscv.riscv64/sys/$(freebsd_rootfs_conf)/kernel.full
freebsd_kernel := $(freebsd_rootfs)/boot/kernel/kernel
freebsd_usr_local := $(freebsd_rootfs)/usr/local

freebsd_world_done := $(freebsd_wrkdir)/.buildworld.done
freebsd_distribution_done := $(freebsd_wrkdir)/.distribution.done
freebsd_world_metalog := $(freebsd_rootfs)/METALOG.world
freebsd_kernel_metalog := $(freebsd_rootfs)/METALOG.kernel
freebsd_custom_done := $(freebsd_wrkdir)/.custom.done
freebsd_change_flag := $(freebsd_wrkdir)/.change.flag

freebsd_bench := $(topdir)/rootfs/bench
freebsd_bench_img := $(freebsd_bench).img
freebsd_bench_metalog := $(freebsd_wrkdir)/METALOG.bench
freebsd_bench_root_img := $(freebsd_bench).root.img

lmbench_srcdir := $(benchdir)/lmbench
unixbench_srcdir := $(benchdir)/unixbench/UnixBench
coremark_srcdir := $(benchdir)/coremark
simple_sigriscv_test_dir := $(benchdir)/simple-sigriscv-test
juliet_srcdir   := $(benchdir)/juliet-test-suite-c
unixbench_install := $(freebsd_bench)/unixbench
lmbench_install := $(freebsd_bench)/lmbench
coremark_install := $(freebsd_bench)/coremark
simple_sigriscv_test_install := $(freebsd_bench)/simple-sigriscv-test
juliet_install  := $(freebsd_bench)/juliet
juliet_wrkdir   := $(wrkdir)/juliet

# CWEs selected for SigRISCV memory-safety validation (see docs/juliet-test-selection.md)
JULIET_SELECTED_CWES := \
	CWE121_Stack_Based_Buffer_Overflow \
	CWE122_Heap_Based_Buffer_Overflow \
	CWE123_Write_What_Where_Condition \
	CWE124_Buffer_Underwrite \
	CWE415_Double_Free \
	CWE416_Use_After_Free \
	CWE476_NULL_Pointer_Dereference \
	CWE562_Return_of_Stack_Variable_Address \
	CWE590_Free_Memory_Not_on_Heap \
	CWE761_Free_Pointer_Not_at_Start_of_Buffer

opensbi_srcdir := $(srcdir)/opensbi
opensbi_wrkdir := $(wrkdir)/opensbi
fw_jump := $(opensbi_wrkdir)/platform/generic/firmware/fw_jump.elf

qemu_srcdir := $(srcdir)/qemu
qemu_wrkdir := $(wrkdir)/qemu
qemu :=  $(toolchain_dest)/bin/qemu-system-riscv64

gem5_srcdir := $(srcdir)/gem5
gem5_wrkdir := $(wrkdir)/gem5
gem5_builddir := $(gem5_wrkdir)/build/RISCV
gem5_bin := $(toolchain_dest)/bin/gem5.opt
gem5_freebsd_config := $(gem5_srcdir)/configs/sigriscv/freebsd.py
GEM5_FREEBSD_CPU_TYPE ?= atomic
GEM5_FREEBSD_MEM_SIZE ?= 2GiB
GEM5_FREEBSD_SYS_CLOCK ?= 10MHz
GEM5_FREEBSD_MAX_TICKS ?= 0
GEM5_FREEBSD_ROOT_MOUNTFROM ?= ufs:/dev/ufs/root
GEM5_FREEBSD_ROOTDEVNAME ?= ufs:/dev/ufs/root\\nufs:/dev/vtbd0
GEM5_FREEBSD_CHECKPOINT_DIR ?=
GEM5_FREEBSD_RESTORE_CHECKPOINT ?=
GEM5_FREEBSD_READFILE ?=
GEM5_ARGS ?=
GEM5_FREEBSD_KERNEL_ARGS ?=
GEM5_FREEBSD_EXTRA_ARGS ?=
GEM5_OUTDIR ?= $(CURDIR)/m5out

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

m5_srcdir := $(gem5_srcdir)/util/m5
m5_wrkdir := $(m5_srcdir)/build
m5_result := $(m5_wrkdir)/riscv/out/m5
m5_cross := $(freebsd_rootfs)/sbin/m5

.PHONY: llvm llvm-debug
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
		-DLLVM_USE_LINKER=lld \
		$(llvm_srcdir)/llvm
	free -h
	$(CMAKE) --build $(llvm_wrkdir) --target install

llvm-debug: $(llvm_srcdir)
	mkdir -p $(llvm_debug_wrkdir) $(toolchain_dest)
	cd $(llvm_debug_wrkdir); $(CMAKE) -G Ninja -DLLVM_ENABLE_PROJECTS="clang;lld" \ \
		-DCMAKE_BUILD_TYPE:String=$(LLVM_DEBUG_VERSION) -DLLVM_ENABLE_ASSERTIONS=True \
		-DLLVM_USE_SPLIT_DWARF=False \
		-DLLVM_OPTIMIZED_TABLEGEN=False \
		-DCMAKE_INSTALL_PREFIX=$(toolchain_dest) \
		-DLLVM_DEFAULT_TARGET_TRIPLE=riscv64-unknown-linux-gnu \
		-DLLVM_TARGETS_TO_BUILD="RISCV" \
		-DDEFAULT_SYSROOT=$(llvm_sysroot) \
		-DLLVM_USE_LINKER=lld \
		$(llvm_srcdir)/llvm
	free -h
	$(CMAKE) --build $(llvm_debug_wrkdir) --target install

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
	-Wno-tautological-constant-out-of-range-compare -Wno-uninitialized -Wno-implicit-function-declaration"

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

buildkernel $(freebsd_kernel_full): $(freebsd_world_done) $(confdir)/$(freebsd_rootfs_conf) $(toolchain_dest)/bin/clang
	rm -rf $(freebsd_kernel_full)
	cp $(confdir)/$(freebsd_rootfs_conf) $(freebsd_srcdir)/sys/riscv/conf/$(freebsd_rootfs_conf)
	cd $(freebsd_srcdir) && env $(FREEBSD_ENV) \
	nice $(freebsd_srcdir)/tools/build/make.py -j$(shell nproc) buildkernel \
		'KERNCONF=$(freebsd_rootfs_conf)' DEBUG=-g $(FREEBSD_ARGS) \
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
		'KERNCONF=$(freebsd_rootfs_conf)' DEBUG=-g $(FREEBSD_ARGS) DESTDIR=$(freebsd_rootfs)
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
# disk-image $(freebsd_rootfs_img) : $(freebsd_distribution_done) $(freebsd_world_metalog) $(freebsd_kernel_metalog) $(freebsd_change_flag) $(freebsd_custom_done)
disk-image $(freebsd_rootfs_img) :
	cp -r $(confdir)/freebsd_conf/* $(freebsd_rootfs)
	chmod 755 $(freebsd_rootfs)/usr/local/bin/*
	mkdir -p $(freebsd_rootfs)/bench
	touch $(freebsd_rootfs)/fastboot
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

.PHONY: bench-image
bench-image $(freebsd_bench_img):
	python3 $(scriptdir)/get_mainfest.py $(freebsd_bench) $(freebsd_bench_metalog)
	cd $(freebsd_bench) && $(freebsd_wrkdir_legacy)/bin/makefs -t ffs \
		-o version=2,label=bench -o softupdates=1 -Z -b 1g -f 128k -R 4m -M 128m \
		-B le -N $(freebsd_rootfs)/etc \
		$(freebsd_bench_root_img) $(freebsd_bench_metalog)
	cd $(freebsd_bench) && $(freebsd_wrkdir_legacy)/bin/mkimg -s gpt \
		-p freebsd-ufs:=$(freebsd_bench_root_img) \
		-o $(freebsd_bench_img)
	rm -f $(freebsd_bench_root_img)
	$(toolchain_dest)/bin/qemu-img info $(freebsd_bench_img)

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

LLVM_CROSS_NOWARN := -Wno-error=unused-command-line-argument \
			-Wno-error=implicit-function-declaration -Wno-error=format \
			-Wno-error=incompatible-pointer-types -Wno-error=pass-failed \
			-Wno-error=undefined-internal -Wno-unused-command-line-argument \
			-Wno-error=incompatible-pointer-types-discards-qualifiers \
			-Wno-error

LLVM_CROSS_CFLAGS_NOWARN = $(LLVM_CROSS_CFLAGS) $(LLVM_CROSS_NOWARN)

LLVM_CROSS_LDFLAGS := $(LLVM_CROSS_CFLAGS) -fuse-ld=lld \
			--ld-path=$(toolchain_dest)/bin/ld.lld

.PHONY: lmbench
lmbench: $(lmbench_srcdir)
	make -C $(lmbench_srcdir) clean
	make -C $(lmbench_srcdir) build \
		OS=riscv-FreeBSD \
		$(LLVM_CROSS_TOOLCHAIN) \
		CFLAGS="$(LLVM_CROSS_CFLAGS_NOWARN) -O1 -g -fPIC -fPIE" \
		LDFLAGS="$(LLVM_CROSS_LDFLAGS)"
	mkdir -p $(lmbench_install)/src
	mkdir -p $(lmbench_install)/$(MODE)
	cp $(lmbench_srcdir)/bin/riscv-FreeBSD/* $(lmbench_install)/$(MODE)/
	cp $(lmbench_srcdir)/src/*.c $(lmbench_install)/src/
	cp $(lmbench_srcdir)/src/*.h $(lmbench_install)/src/

.PHONY: unixbench
unixbench: $(unixbench_srcdir)
	make -C $(unixbench_srcdir) clean
	make -C $(unixbench_srcdir) \
		OSNAME=freebsd \
		$(LLVM_CROSS_TOOLCHAIN) \
		CFLAGS="$(LLVM_CROSS_CFLAGS_NOWARN) -O1 -g -fPIE -fPIC" \
		LDFLAGS="$(LLVM_CROSS_LDFLAGS)" \
		RAWCFLAGS="$(LLVM_CROSS_RAWCFLAGS)" \
		RAWLDFLAGS="$(LLVM_CROSS_RAWLDFLAGS)"
	mkdir -p $(unixbench_install)/src
	mkdir -p $(unixbench_install)/$(MODE)
	cp $(unixbench_srcdir)/pgms/* $(unixbench_install)/$(MODE)
	cp $(unixbench_srcdir)/testdir/sort.src $(unixbench_install)/$(MODE)
	cp $(unixbench_srcdir)/src/* $(unixbench_install)/src/
	cp $(unixbench_srcdir)/.gdbinit $(unixbench_install)/$(MODE)/

.PHONY: coremark
coremark: $(coremark_srcdir)
	make -C $(coremark_srcdir) clean
	make -C $(coremark_srcdir) compile \
		PORT_DIR=freebsd \
		NO_LIBRT=1 \
		ITERATIONS=0 \
		REBUILD=1 \
		$(LLVM_CROSS_TOOLCHAIN) \
		XCFLAGS="$(LLVM_CROSS_CFLAGS_NOWARN) -O1 -g" \
		LFLAGS_END="$(LLVM_CROSS_LDFLAGS)"
	mkdir -p $(coremark_install)/src
	mkdir -p $(coremark_install)/$(MODE)
	cp $(coremark_srcdir)/coremark.exe $(coremark_install)/$(MODE)/
	cp $(coremark_srcdir)/execute.sh $(coremark_install)/$(MODE)/
	cp $(coremark_srcdir)/*.c $(coremark_install)/src/
	cp $(coremark_srcdir)/*.h $(coremark_install)/src/
	cp $(coremark_srcdir)/posix/core_portme.c $(coremark_install)/src/
	cp $(coremark_srcdir)/posix/core_portme.h $(coremark_install)/src/

include $(topdir)/Makefile.spec2006.inc

.PHONY: juliet
juliet: $(juliet_srcdir)
	mkdir -p $(juliet_wrkdir)
	if [ -n "$(JULIET_BRANCH)" ]; then cd $(juliet_srcdir) && git checkout $(JULIET_BRANCH); fi
	{ \
	  echo 'set(CMAKE_SYSTEM_NAME FreeBSD)'; \
	  echo 'set(CMAKE_SYSTEM_PROCESSOR riscv64)'; \
	  echo 'set(CMAKE_C_COMPILER "$(toolchain_dest)/bin/clang")'; \
	  echo 'set(CMAKE_AR "$(toolchain_dest)/bin/llvm-ar" CACHE FILEPATH "" FORCE)'; \
	  echo 'set(CMAKE_RANLIB "$(toolchain_dest)/bin/llvm-ranlib" CACHE FILEPATH "" FORCE)'; \
	  echo 'set(CMAKE_C_FLAGS_INIT "$(LLVM_CROSS_CFLAGS_NOWARN) -g")'; \
	  echo 'set(CMAKE_EXE_LINKER_FLAGS_INIT "$(LLVM_CROSS_LDFLAGS)")'; \
	  echo 'set(CMAKE_C_COMPILER_FORCED TRUE)'; \
	  echo 'set(CMAKE_CXX_COMPILER_FORCED TRUE)'; \
	  echo 'set(CMAKE_FIND_ROOT_PATH "$(freebsd_rootfs)")'; \
	  echo 'set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)'; \
	  echo 'set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)'; \
	  echo 'set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)'; \
	} > $(juliet_wrkdir)/toolchain.cmake
	for CWE in $(JULIET_SELECTED_CWES); do \
		CWEDIR=$(juliet_srcdir)/testcases/$$CWE; \
		rm -f "$$CWEDIR/CMakeCache.txt"; \
		cp $(scriptdir)/juliet-CMakeLists.txt $$CWEDIR/CMakeLists.txt; \
		cmake -DCMAKE_TOOLCHAIN_FILE=$(juliet_wrkdir)/toolchain.cmake \
			-S $$CWEDIR -B $$CWEDIR || exit 1; \
		$(MAKE) -C $$CWEDIR -j$(shell nproc) -k; \
	done
	mkdir -p $(juliet_install)/$(MODE)
	cp -r $(juliet_srcdir)/bin/. $(juliet_install)/$(MODE)/
	cp $(juliet_srcdir)/juliet-run.sh $(juliet_install)/$(MODE)/
	sed -i 's|INPUT_FILE="/tmp/in.txt"|INPUT_FILE="/tmp/in.txt"; touch "$$INPUT_FILE"|' \
		$(juliet_install)/$(MODE)/juliet-run.sh


.PHONY: simple_sigriscv_test
simple_sigriscv_test: $(simple_sigriscv_test_dir)
	$(MAKE) -C $(simple_sigriscv_test_dir)
	make -p $(freebsd_bench)
	$(MAKE) -C $(simple_sigriscv_test_dir) install PREFIX=$(freebsd_bench)

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

M5_LLVM_CROSS_CFLAGS := $(LLVM_CROSS_CFLAGS_NOWARN)
M5_LLVM_CROSS_LDFLAGS := $(LLVM_CROSS_LDFLAGS)

.PHONY: cross-m5
cross-m5 $(m5_cross): $(m5_srcdir) $(toolchain_dest)/bin/clang $(freebsd_distribution_done)
	mkdir -p $(m5_wrkdir)
	cd $(m5_srcdir) && scons \
		CC='$(toolchain_dest)/bin/clang' \
		CXX='$(toolchain_dest)/bin/clang++' \
		AS='$(toolchain_dest)/bin/clang' \
		AR='$(toolchain_dest)/bin/llvm-ar' \
		LD='$(toolchain_dest)/bin/ld.lld' \
		RANLIB='$(toolchain_dest)/bin/llvm-ranlib' \
		riscv.CCFLAGS='$(M5_LLVM_CROSS_CFLAGS)' \
		riscv.CXXFLAGS='$(M5_LLVM_CROSS_CFLAGS)' \
		riscv.ASFLAGS='$(M5_LLVM_CROSS_CFLAGS)' \
		riscv.LINKFLAGS='$(M5_LLVM_CROSS_LDFLAGS)' \
		build/riscv/out/m5
	mkdir -p $(freebsd_rootfs)/sbin
	cp $(m5_result) $(m5_cross)
	chmod 755 $(m5_cross)
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

.PHONY: gem5-create
gem5-create:
	conda create -n gem5-build python=3.10 -y
	conda activate gem5-build

.PHONY: gem5
gem5 $(gem5_bin): $(gem5_srcdir)
	mkdir -p $(gem5_wrkdir)
	cd $(gem5_wrkdir) && scons -C $(gem5_srcdir) build/RISCV/gem5.opt -j$(shell nproc)
	mkdir -p $(toolchain_dest)/bin
	cp $(gem5_builddir)/gem5.opt $(gem5_bin)
	ln -sf $(gem5_bin) $(toolchain_dest)/bin/gem5

.PHONY: clean mrproper
clean:
	rm -rf -- $(wrkdir)

mrproper:
	rm -rf -- $(wrkdir) $(toolchain_dest) $(topdir)/rootfs

.PHONY: qemu-run

qemu-run: 
	$(qemu) -M virt -m 2048 -nographic -bios $(fw_jump) \
		-kernel $(freebsd_kernel) \
		-append '-s' \
		-drive if=none,file=rootfs/freebsd_sysroot.img,id=rootdisk,format=raw \
		-device virtio-blk-device,drive=rootdisk \
		-drive if=none,file=rootfs/bench.img,id=benchdisk,format=raw \
		-device virtio-blk-device,drive=benchdisk \
		-device virtio-rng-pci

qemu-debug: $(qemu) $(fw_jump) $(freebsd_rootfs_img)
	$(qemu) -M virt -m 2048 -nographic -bios $(fw_jump) \
		-kernel $(freebsd_kernel) \
		-drive if=none,file=$(freebsd_rootfs_img),id=rootdisk,format=raw \
		-device virtio-blk-device,drive=rootdisk \
		-drive if=none,file=$(freebsd_bench_img),id=benchdisk,format=raw \
		-device virtio-blk-device,drive=benchdisk \
		-device virtio-rng-pci -S -s

qemu-link: $(gdb_native)
	$(gdb_native) $(freebsd_kernel)

.PHONY: gem5-run-freebsd

gem5-checkpoint: GEM5_FREEBSD_CPU_TYPE = atomic
gem5-checkpoint: GEM5_OUTDIR = $(CURDIR)/m5out-cpt
gem5-checkpoint: GEM5_FREEBSD_CHECKPOINT_DIR = $(CURDIR)/m5out-cpt/checkpoints
gem5-checkpoint: GEM5_FREEBSD_READFILE = $(CURDIR)/m5out-cpt/readfile
gem5-checkpoint: GEM5_FREEBSD_KERNEL_ARGS = -s

gem5-restore: GEM5_FREEBSD_CPU_TYPE = minor
gem5-restore: GEM5_OUTDIR = $(CURDIR)/m5out-rs
gem5-restore: GEM5_FREEBSD_RESTORE_CHECKPOINT = $(CURDIR)/m5out-cpt/checkpoints/cpt.40803368800000
gem5-restore: GEM5_FREEBSD_CHECKPOINT_DIR = $(CURDIR)/m5out-rs/checkpoints
gem5-restore: GEM5_FREEBSD_READFILE = $(CURDIR)/m5out-rs/readfile
gem5-restore: GEM5_FREEBSD_KERNEL_ARGS = -s

gem5-run-freebsd: $(m5_cross)
	$(gem5_bin) -d $(GEM5_OUTDIR) \
		$(GEM5_ARGS) $(gem5_freebsd_config) \
		--bootloader $(fw_jump) \
		--kernel $(freebsd_kernel) \
		--disk-image $(freebsd_rootfs_img) \
		--bench-image $(freebsd_bench_img) \
		--cpu-type $(GEM5_FREEBSD_CPU_TYPE) \
		--sys-clock $(GEM5_FREEBSD_SYS_CLOCK) \
		--mem-size $(GEM5_FREEBSD_MEM_SIZE) \
		--root-mountfrom '$(GEM5_FREEBSD_ROOT_MOUNTFROM)' \
		--rootdevname '$(GEM5_FREEBSD_ROOTDEVNAME)' \
		--checkpoint-dir '$(GEM5_FREEBSD_CHECKPOINT_DIR)' \
		--restore-checkpoint '$(GEM5_FREEBSD_RESTORE_CHECKPOINT)' \
		--readfile '$(GEM5_FREEBSD_READFILE)' \
		--max-ticks $(GEM5_FREEBSD_MAX_TICKS) \
		--kernel-args='$(GEM5_FREEBSD_KERNEL_ARGS)' \
		$(GEM5_FREEBSD_EXTRA_ARGS)

gem5-checkpoint: gem5-run-freebsd
gem5-restore: gem5-run-freebsd

.PHONY: gem5-link
gem5-link:
	python3 $(gem5_srcdir)/util/term/gem5term 3457
