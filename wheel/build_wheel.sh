#!/usr/bin/env bash
set -e

PYTHON_VERSION=$1

echo "Building for Python: $PYTHON_VERSION Commit: $BUILD_COMMIT"

echo "OSX. No CUDA/CUDNN"

###########################################################
export CONDA_ROOT_PREFIX=$(conda info --root)

conda install -y cmake

conda remove --name py2k  --all -y || true
conda remove --name py35k --all -y || true
conda remove --name py36k --all -y || true
conda info --envs

# create env and activate
if [ $PYTHON_VERSION -eq 2 ]
then
    echo "Requested python version 2. Activating conda environment"
    conda create -n py2k python=2 -y
    export CONDA_ENVNAME="py2k"
    source activate py2k
    export PREFIX="$CONDA_ROOT_PREFIX/envs/py2k"
elif [ $PYTHON_VERSION == "3.5" ]; then
    echo "Requested python version 3.5. Activating conda environment"
    conda create -n py35k python=3.5 -y
    export CONDA_ENVNAME="py35k"
    source activate py35k
    export PREFIX="$CONDA_ROOT_PREFIX/envs/py35k"
elif [ $PYTHON_VERSION == "3.6" ]; then
    echo "Requested python version 3.6. Activating conda environment"
    conda create -n py36k python=3.6.0 -y
    export CONDA_ENVNAME="py36k"
    source activate py36k
    export PREFIX="$CONDA_ROOT_PREFIX/envs/py36k"
fi

conda install -n $CONDA_ENVNAME -y numpy==1.11.3 nomkl setuptools pyyaml cffi

# now $PREFIX should point to your conda env
##########################
# now build the binary

echo "Conda root: $CONDA_ROOT_PREFIX"
echo "Env root: $PREFIX"

export PYTORCH_BINARY_BUILD=1
export TH_BINARY_BUILD=1

echo "Python Version:"
python --version

export MACOSX_DEPLOYMENT_TARGET=10.10

rm -rf pytorch-src
git clone https://github.com/pytorch/pytorch pytorch-src
pushd pytorch-src
git submodule update --init --recursive
if [ ! -z "${BUILD_COMMIT}" ]; then
    git reset --hard ${BUILD_COMMIT}
fi

pip install -r requirements.txt || true
MACOSX_DEPLOYMENT_TARGET=10.9 CC=clang CXX=clang++ python setup.py bdist_wheel -d ../whl/

popd
