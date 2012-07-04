#!/bin/bash

# Original script downloaded from: https://github.com/st3fan/ios-openssl
# Yay shell scripting! This script builds a static version of
# OpenSSL ${OPENSSL_VERSION} for iOS 5.1 that contains code for armv6, armv7 and i386.
# Modified by Dmitry Stepanushkin to enhance usability

set -x

# Setup paths to stuff we need
OPENSSL_VERSION="1.0.1c"
DEVELOPER="/Applications/Xcode.app/Contents/Developer"
SDK_VERSION="5.1"
IPHONEOS_PLATFORM="${DEVELOPER}/Platforms/iPhoneOS.platform"
IPHONEOS_SDK="${IPHONEOS_PLATFORM}/Developer/SDKs/iPhoneOS${SDK_VERSION}.sdk"
IPHONEOS_GCC="${IPHONEOS_PLATFORM}/Developer/usr/bin/gcc"
IPHONESIMULATOR_PLATFORM="${DEVELOPER}/Platforms/iPhoneSimulator.platform"
IPHONESIMULATOR_SDK="${IPHONESIMULATOR_PLATFORM}/Developer/SDKs/iPhoneSimulator${SDK_VERSION}.sdk"
IPHONESIMULATOR_GCC="${IPHONESIMULATOR_PLATFORM}/Developer/usr/bin/gcc"
BUILD_DIR=./tmp

# Clean up whatever was left from our previous build
if [[ ! -d ${BUILD_DIR} ]]; then
rm -rf ${BUILD_DIR}
mkdir ${BUILD_DIR}
fi
rm -rf include lib
rm -rf "${BUILD_DIR}/openssl-${OPENSSL_VERSION}-*"

# Convert relative path to absolute path
pushd ${BUILD_DIR}
BUILD_DIR=`pwd`
popd

# Build for ARMv6/ARMv7/x86
build()
{
ARCH=$1
GCC=$2
SDK=$3
rm -rf "openssl-${OPENSSL_VERSION}"
if [[ -e "openssl-${OPENSSL_VERSION}.tar.gz" ]]; then 
tar xfv "openssl-${OPENSSL_VERSION}.tar.gz"
elif [[ -e "openssl-${OPENSSL_VERSION}.tar.bz2" ]]; then
tar xfv "openssl-${OPENSSL_VERSION}.tar.bz2"
else
curl "ftp://ftp.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" > "openssl-${OPENSSL_VERSION}.tar.gz"
if [[ -e "openssl-${OPENSSL_VERSION}.tar.gz" ]]; then
tar xfv "openssl-${OPENSSL_VERSION}.tar.gz"
else
exit
fi
fi
pushd .
cd "openssl-${OPENSSL_VERSION}"
./Configure BSD-generic32 --openssldir="${BUILD_DIR}/openssl-${OPENSSL_VERSION}-${ARCH}"
perl -i -pe 's|static volatile sig_atomic_t intr_signal|static volatile int intr_signal|' crypto/ui/ui_openssl.c
perl -i -pe "s|^CC= gcc|CC= ${GCC} -arch ${ARCH}|g" Makefile
perl -i -pe "s|^CFLAG= (.*)|CFLAG= -isysroot ${SDK} \$1|g" Makefile
NUM_CPU=`sysctl -n hw.ncpu`
make -j${NUM_CPU}
make install
popd
rm -rf "openssl-${OPENSSL_VERSION}"
}

# Run build for each architecture
build "armv6" "${IPHONEOS_GCC}" "${IPHONEOS_SDK}"
build "armv7" "${IPHONEOS_GCC}" "${IPHONEOS_SDK}"
build "i386" "${IPHONESIMULATOR_GCC}" "${IPHONESIMULATOR_SDK}"

# Copy headers to install location
mkdir include
cp -r ${BUILD_DIR}/openssl-${OPENSSL_VERSION}-i386/include/openssl include/

# Make libraries universal binaries and copy them to install location
mkdir lib
lipo \
"${BUILD_DIR}/openssl-${OPENSSL_VERSION}-armv6/lib/libcrypto.a" \
"${BUILD_DIR}/openssl-${OPENSSL_VERSION}-armv7/lib/libcrypto.a" \
"${BUILD_DIR}/openssl-${OPENSSL_VERSION}-i386/lib/libcrypto.a" \
-create -output lib/libcrypto.a
lipo \
"${BUILD_DIR}/openssl-${OPENSSL_VERSION}-armv6/lib/libssl.a" \
"${BUILD_DIR}/openssl-${OPENSSL_VERSION}-armv7/lib/libssl.a" \
"${BUILD_DIR}/openssl-${OPENSSL_VERSION}-i386/lib/libssl.a" \
-create -output lib/libssl.a

# Cleanup
sleep 5
rm -rf "${BUILD_DIR}"
