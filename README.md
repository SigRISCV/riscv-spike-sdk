# RISC-V FREEBSD SDK

We have implemented the RISC-V FreeBSD SDK based on Sycuricon's RISC-V SPIKE SDK. This SDK replaces the traditional riscv-linux-gnu-gcc with LLVM as the cross-compiler, supporting the simulation execution of the FreeBSD operating system. This SDK supports the latest versions of FreeBSD, LLVM, OpenSBI, QEMU, and other components. The core components are as follows:

|       Folder        |      Description       |   Version      |
| :-----------------: | :--------------------: | :------------: |
|	repo/freebsd	  |  kernel and rootfs	   |  FREEBSD 16    |
|   repo/opensbi      |  bootloader and sbi    |  opensbi v1.7  |
|	repo/qemu		  |  simulator             |  qemu 10.1.50  |
|   repo/llvm-project |  compiler toolchain    |  clang 22.0.0  |

## Quickstart

Build dependencies on Ubuntu 24.04:
```bash
$ sudo apt-get install device-tree-compiler autoconf automake autotools-dev    \
curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
gperf libtool patchutils bc zlib1g-dev libexpat-dev python3-dev unzip \
libglib2.0-dev libpixman-1-dev git rsync wget cpio clang 
```

```bash
git clone https://github.com/SigRISCV/riscv-spike-sdk.git

# For people who only want to have a try
sh quickstart.sh
# For people who want to develop the whole system
git submodule update --init -depth 1

make qemu-run
```

## Target Instruction

This section describes the dependencies between the core flow targets and the functionality of each target. Users can execute targets according to their needs.

|       Target        |      Description                        |
| :-----------------: | :-------------------------------------: |
|	qemu-run	      |  run freebsd on qemu                    |
|   qemu-debug        |  run qemu in debug mode                 |
|	disk-image		  |  make rootfs to image                   |
|   distribution      |  install some configuration in rootfs   |
|   installkernel     |  install kernel modules in rootfs       |
|   installworld      |  install user program as rootfs         |
|   buildkernel       |  build freebsd's kernel modules         |
|   buildworld        |  build freebsd's user program           |
|   fw-image          |  build opensbi for freebsd              |
|   qemu              |  build qemu in riscv64 arch             |
|   llvm              |  build llvm as rv64 compile toolchain   |

```text

        qemu-run/qemu-debug
                |
        +-------+---------------+
        |       |               |
    fw_image  qemu          disk-image
        |                       |
        |                   distribution
        |                       |
        |       +---------------+
        |       |               |
        |   installworld    installkernel
        |       |               |
        |   buildworld      buildkernel
        |       |               |
        |       |               |
        +-------+---------------+
                |
               llvm

```

Additionally, we can cross-compile some benchmarks and user-space programs, then install them into the FreeBSD rootfs for execution. These targets are described below:

|       Target        |      Description                        |
| :-----------------: | :-------------------------------------: |
|   gdb-native        |  construct gdb working on host          |
|   gdb-cross         |  compile and install gdb on rootfs      |
|   gmp-cross         |  compile and install gmp on rootfs      |
|   mpfr-cross        |  compile and install mpfr on rootfs     |
|   lmbench           |  compile and install lmbench on rootfs  |
|   unixbench         |  compile and install unixbench on rootfs|

```text

        gdb-cross
            |
        +---+-------+
        |           |
    gmp-cross   mpfr-cross  lmbench     unixbench
        |           |           |           |
        +---+-------+-----------+-----------+
            |
        freebsd_rootfs

```
