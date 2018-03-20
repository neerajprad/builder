#!/usr/bin/env bash
set -e

BUILD_VERSION=0.3.1
BUILD_NUMBER=1

if [[ "$OSTYPE" == "darwin"* ]]; then
    rm -rf whl
    mkdir -p whl

    # osx no CUDA builds
    ./build_wheel.sh 2
    ./build_wheel.sh 3.5
    ./build_wheel.sh 3.6
fi
