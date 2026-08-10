#!/bin/bash
#
# Hydrogen Kernel build script
# Brought to you by z3rokwq @ pissarro-development
#

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to display help message
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [CODENAME]

Build script for Hydrogen Kernel

OPTIONS:
    -h, --help      Show this help message and exit
    -c, --clean     Perform a full clean build (removes out directory)

ARGUMENTS:
    CODENAME        Device codename (default: pissarro)

EXAMPLES:
    $0                      # Build for default device
    $0 -c                   # Clean build for default device
    $0 <codename>           # Build for specific device
    $0 -c <codename>        # Clean build for specific device

EOF
}

# Initial Setup
KERNEL_NAME="Hydrogen"
KERNEL_VERSION="v2.0"

DEVICE="pissarro"

CLEAN_BUILD=false

DATE=$(date '+%Y%m%d-%H%M')
SECONDS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -*)
            echo "Error: Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
        *)
            DEVICE="$1"
            shift
            ;;
    esac
done

DEFCONFIG="${DEVICE}_defconfig"

ZIPNAME="${KERNEL_NAME}Kernel-${KERNEL_VERSION}-${DEVICE}-${DATE}.zip"

echo -e "Building for device: $DEVICE\n"

# Toolchain Setup
CLANG_VERSION="clang-r563880c"
TC_DIR="$HOME/toolchains"
if [ ! -d "$TC_DIR/$CLANG_VERSION" ]; then
    echo -e "Toolchain not found, downloading AOSP clang...\n"
    git clone --depth=1 --branch=android-16.0.0_r4 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 "$TC_DIR/.tmp/"
    mv "$TC_DIR/.tmp/$CLANG_VERSION" "$TC_DIR"
    rm -rf "$TC_DIR/.tmp/"
    echo -e "\nToolchain successfully downloaded and extracted!\n"
fi
export PATH="$TC_DIR/$CLANG_VERSION/bin:$PATH"

# If the -c flag is specified, perform a full clean
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "Performing a full clean...\n"
    rm -rf out
    make -i mrproper
fi

# Compilation Variables
export ARCH=arm64
export SUBARCH=arm64

# Apply defconfig
echo -e "Preparing kernel configuration...\n"

make O=out \
     ARCH=$ARCH \
     SUBARCH=$SUBARCH \
     LLVM=1 \
     LLVM_IAS=1 \
     CC="ccache clang" \
     CROSS_COMPILE=aarch64-linux-gnu- \
     CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
     $DEFCONFIG

# Start the build
echo -e "\nStarting kernel compilation...\n"

if make -j$(nproc --all) \
        O=out \
        ARCH=$ARCH \
        SUBARCH=$SUBARCH \
        LLVM=1 \
        LLVM_IAS=1 \
        CC="ccache clang" \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        Image.gz; then

    echo -e "\nKernel compiled successfully! Packing into a zip archive...\n"

    # Cloning AnyKernel3
    git clone --depth=1 --branch=hydrogen-4.14.y https://github.com/pissarro-development/anykernel3.git anykernel3/

    # Copying the prebuilts images
    cp prebuilts/dtbo.img anykernel3/
    cp prebuilts/dtb.img anykernel3/

    # Copying the compiled images
    cp out/arch/arm64/boot/Image.gz anykernel3/

    # Creating the zip archive
    (cd anykernel3 && zip -r9 "../$ZIPNAME" ./* -x '*.git*' README.md '*placeholder')

    # Cleanup
    rm -rf anykernel3

    echo -e "\nCompleted in $((SECONDS / 60)) min(s) and $((SECONDS % 60)) sec(s)!"
    echo "Kernel installer zip: $ZIPNAME"
else
    echo -e "\nBuild failed!"
    exit 1
fi
