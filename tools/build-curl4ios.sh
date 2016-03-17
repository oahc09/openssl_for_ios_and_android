#!/bin/bash
#
#  Copyright (c) 2013 Claudiu-Vlad Ursache <claudiu@cvursache.com>
#  MIT License (see LICENSE.md file)
#
#  Based on work by Felix Schulze:
#
#  Automatic build script for libssl and libcrypto 
#  for iPhoneOS and iPhoneSimulator
#
#  Created by Felix Schulze on 16.12.10.
#  Copyright 2010 Felix Schulze. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

set -u

SOURCE="$0"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
pwd_path="$( cd -P "$( dirname "$SOURCE" )" && pwd )/"

 
# Setup architectures, library name and other vars + cleanup from previous runs
ARCHS=("arm64" "armv7s" "armv7" "i386" "x86_64")
SDKS=("iphoneos" "iphoneos" "iphoneos" "iphonesimulator" "iphonesimulator")
LIB_NAME="curl-7.47.1"
TEMP_LIB_PATH="/tmp/${LIB_NAME}"
LIB_DEST_DIR="lib"
HEADER_DEST_DIR="include"
rm -rf "${HEADER_DEST_DIR}" "${LIB_DEST_DIR}" "${TEMP_LIB_PATH}*" "${LIB_NAME}"
 
# Unarchive library, then configure and make for specified architectures
configure_make()
{
   ARCH=$1; GCC=$2; SDK_PATH=$3;
   LOG_FILE="${TEMP_LIB_PATH}-${ARCH}.log"
   export CC="${GCC}"
   export CFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH}"
   tar xfz "${LIB_NAME}.tar.gz"
   pushd .; cd "${LIB_NAME}";
   if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ]; then
      echo "./configure --prefix=${TEMP_LIB_PATH}-${ARCH} --disable-shared --with-random=/dev/urandom --with-darwinssl"
      ./configure --prefix="${TEMP_LIB_PATH}-${ARCH}" --disable-shared --with-random=/dev/urandom --with-darwinssl > "${LOG_FILE}" 2>$1
   elif [ "${ARCH}" == "arm64" ]; then
      echo "./configure --prefix=${TEMP_LIB_PATH}-${ARCH} --host=arm-apple-darwin --disable-shared --with-random=/dev/urandom --with-darwinssl"
      ./configure --prefix="${TEMP_LIB_PATH}-${ARCH}" --host=arm-apple-darwin --disable-shared --with-random=/dev/urandom --with-darwinssl > "${LOG_FILE}" 2>$1
   else
      echo "./configure --prefix=${TEMP_LIB_PATH}-${ARCH} --host=${ARCH}-apple-darwin --disable-shared --with-random=/dev/urandom --with-darwinssl"
      ./configure --prefix="${TEMP_LIB_PATH}-${ARCH}" --host="${ARCH}-apple-darwin" --disable-shared --with-random=/dev/urandom --with-darwinssl > "${LOG_FILE}" 2>$1
   fi
   make >> "${LOG_FILE}" 2>$1; 
   make install >> "${LOG_FILE}" 2>$1;
   popd; rm -rf "${LIB_NAME}";
}
for ((i=0; i < ${#ARCHS[@]}; i++))
do
   SDK_PATH=$(xcrun -sdk ${SDKS[i]} --show-sdk-path)
   GCC=$(xcrun -sdk ${SDKS[i]} -find gcc)
   configure_make "${ARCHS[i]}" "${GCC}" "${SDK_PATH}"
done

# Combine libraries for different architectures into one
# Use .a files from the temp directory by providing relative paths
create_lib()
{
   LIB_SRC=$1; LIB_DST=$2;
   LIB_PATHS=( "${ARCHS[@]/#/${TEMP_LIB_PATH}-}" )
   LIB_PATHS=( "${LIB_PATHS[@]/%//${LIB_SRC}}" )
   lipo ${LIB_PATHS[@]} -create -output "${LIB_DST}"
}
mkdir "${LIB_DEST_DIR}";
create_lib "lib/libcurl.a" "${LIB_DEST_DIR}/libcurl.a"
 
# Copy header files + final cleanups
mkdir -p "${HEADER_DEST_DIR}"
cp -R "${TEMP_LIB_PATH}-${ARCHS[0]}/include" "${HEADER_DEST_DIR}"
rm -rf "${TEMP_LIB_PATH}-*" "{LIB_NAME}"
