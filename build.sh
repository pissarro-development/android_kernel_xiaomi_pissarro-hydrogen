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
Build script for Hydrogen Kernel

Usage: $0 [OPTIONS] [CODENAME]

OPTIONS:
    -h, --help               Show this help message and exit
    -c, --clean              Perform a full clean build (removes out directory)
    -v, --variant <variant>  Select build variant:
                             - vanilla  (Vanilla)
                             - ksu      (KernelSU with SuSFS)
                             - ksunext  (KernelSU-Next with SuSFS)
                             - resukisu (ReSukiSU with SuSFS)
                             (default: vanilla)

ARGUMENTS:
    CODENAME                 Device codename
                             (default: pissarro)

EOF
}

# Initial Setup
KERNEL_NAME="Hydrogen"
KERNEL_VERSION="v2.0"

CLEAN_BUILD=false
VARIANT="vanilla"
DEVICE="pissarro"

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
        -v|--variant)
            if [[ -n "$2" && "$2" != -* ]]; then
                VARIANT="$2"
                shift 2
            else
                echo "Error: Argument for $1 is missing"
                exit 1
            fi
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

# Validate build variant
case "${VARIANT,,}" in
    vanilla)
        VARIANT_NAME="Vanilla"
        ;;
    ksu)
        VARIANT_NAME="KernelSU with SuSFS"
        ;;
    ksunext)
        VARIANT_NAME="KernelSU-Next with SuSFS"
        ;;
    resukisu)
        VARIANT_NAME="ReSukiSU with SuSFS"
        ;;
    *)
        echo "Error: Invalid variant '$VARIANT_NAME'!"
        echo "Supported variants: Vanilla, KernelSU, KernelSU-Next, ReSukiSU"
        exit 1
        ;;
esac

DEFCONFIG="${DEVICE}_defconfig"
ZIPNAME="${KERNEL_NAME}Kernel-${KERNEL_VERSION}-${DEVICE}-${VARIANT}-${DATE}.zip"

echo -e "Building for device: $DEVICE"
echo -e "Building variant: $VARIANT_NAME\n"

# Toolchain Setup
CLANG_VERSION="clang-r563880c"
TC_DIR="$HOME/toolchains"
if [ ! -d "$TC_DIR/$CLANG_VERSION" ]; then
    echo -e "Toolchain not found, downloading AOSP clang...\n"
    git clone --depth=1 --branch=android-16.0.0_r4 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 "$TC_DIR/.tmp/"
    mv "$TC_DIR/.tmp/$CLANG_VERSION" "$TC_DIR"
    rm -rf "$TC_DIR/.tmp/"
    echo -e "Toolchain successfully downloaded and extracted!\n"
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
echo -e "\nPreparing kernel configuration...\n"

make O=out \
     ARCH=$ARCH \
     SUBARCH=$SUBARCH \
     LLVM=1 \
     LLVM_IAS=1 \
     CC="ccache clang" \
     CROSS_COMPILE=aarch64-linux-gnu- \
     CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
     $DEFCONFIG

# Apply root solution config
echo -e "\nPreparing root solution configuration for $VARIANT_NAME...\n"

./scripts/kconfig/merge_config.sh -m \
                                  -O out \
                                  out/.config \
                                  arch/arm64/configs/root/$VARIANT.config

make O=out \
     ARCH=$ARCH \
     SUBARCH=$SUBARCH \
     LLVM=1 \
     LLVM_IAS=1 \
     CC="ccache clang" \
     CROSS_COMPILE=aarch64-linux-gnu- \
     CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
     olddefconfig

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
