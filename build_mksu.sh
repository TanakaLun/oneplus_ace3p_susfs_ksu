#!/bin/bash
set -e

OLD_DIR=$(pwd)
ANDROID_VERSION="android14"
KERNEL_VERSION="6.1"
SUSFS_VERSION="1.5.5"
CPUD="pineapple"

# Initialize repo and sync
rm kernel_platform/common/android/abi_gki_protected_exports_* || echo "No protected exports!"
rm kernel_platform/msm-kernel/android/abi_gki_protected_exports_* || echo "No protected exports!"
sed -i 's/ -dirty//g' kernel_platform/common/scripts/setlocalversion
sed -i 's/ -dirty//g' kernel_platform/msm-kernel/scripts/setlocalversion

# Set up MKSU
cd kernel_platform
curl -LSs "https://raw.githubusercontent.com/5ec1cff/KernelSU/refs/heads/main/kernel/setup.sh" | bash -
cd KernelSU
git revert -m 1 3a73585 -n
KSU_VERSION=$(expr $(/usr/bin/git rev-list --count HEAD) "+" 10200)
sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile

# Set up susfs
cd "$OLD_DIR"
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-${ANDROID_VERSION}-${KERNEL_VERSION}
git clone https://github.com/TanakaLun/kernel_patches4mksu.git
cd kernel_platform
cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
cp ../kernel_patches4mksu/mksu/mksu_susfs.patch ./KernelSU/
cp ../kernel_patches4mksu/mksu/fix.patch ./KernelSU/
cp ../kernel_patches4mksu/mksu/vfs_fix.patch ./KernelSU/
cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch ./common/
cp ../susfs4ksu/kernel_patches/fs/* ./common/fs/
cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/

# Apply patches
cd KernelSU
patch -p1 --forward < 10_enable_susfs_for_ksu.patch || true
patch -p1 --forward < mksu_susfs.patch || true
patch -p1 --forward < fix.patch || true
patch -p1 --forward < vfs_fix.patch || true
# cp ../../kernel_patches4mksu/KernelSU-Next-Implement-SUSFS-v${SUSFS_VERSION}-Universal.patch ./
# patch -p1 < KernelSU-Next-Implement-SUSFS-v${SUSFS_VERSION}-Universal.patch || true
cd ../common
patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch || true
cp ../../kernel_patches4mksu/69_hide_stuff.patch ./
patch -p1 -F 3 < 69_hide_stuff.patch

# Build kernel
cd "$OLD_DIR"
./kernel_platform/build_with_bazel.py -t pineapple gki

# Make AnyKernel3
git clone https://github.com/Kernel-SU/AnyKernel3 --depth=1
rm -rf ./AnyKernel3/.git
cp out/dist/Image ./AnyKernel3/

ZIPNAME="Anykernel3-MKSU-SUSFS-${KSU_VERSION}-OnePlus_ACE_3_Pro.zip"
cd ./AnyKernel3
zip -r "../$ZIPNAME" ./*
