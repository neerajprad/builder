#!/usr/bin/env bash

set -xe

export NO_CUDA=1
export CMAKE_LIBRARY_PATH="/opt/intel/lib:/lib:$CMAKE_LIBRARY_PATH"

WHEELHOUSE_DIR="wheelhousecpu"

yum install -y epel-release
yum install -y cmake3
yum remove -y cmake

ln -sf /usr/bin/cmake3 /usr/bin/cmake

rm -rf /usr/local/cuda*
rm -rf /opt/python/cpython-2.6.9-ucs2  /opt/python/cpython-2.6.9-ucs4
# rm -rf /opt/python/cp35*  # TODO: remove
# rm -rf /opt/python/cp27*  # TODO: remove
ls /opt/python

# ########################################################
# # Compile wheels
# #######################################################
# clone pytorch source code
git clone https://github.com/pytorch/pytorch || echo 'using existing clone'
pushd pytorch
git pull
git submodule update --init --recursive

OLD_PATH=$PATH
for PYDIR in /opt/python/*; do
    export PATH=$PYDIR/bin:$OLD_PATH
    python setup.py clean
    pip install -r requirements.txt
    pip install numpy==1.11
    time python setup.py bdist_wheel -d $WHEELHOUSE_DIR
done

popd

#######################################################################
# ADD DEPENDENCIES INTO THE WHEEL
# 
# auditwheel repair doesn't work correctly and is buggy
# so manually do the work of copying dependency libs and patchelfing
# and fixing RECORDS entries correctly
######################################################################
yum install -y zip

fname_with_sha256() {
    HASH=$(sha256sum $1 | cut -c1-8)
    DIRNAME=$(dirname $1)
    BASENAME=$(basename $1)
    if [[ $BASENAME == "libnvrtc-builtins.so" ]]; then
	echo $1
    else
	INITNAME=$(echo $BASENAME | cut -f1 -d".")
	ENDNAME=$(echo $BASENAME | cut -f 2- -d".")
	echo "$DIRNAME/$INITNAME-$HASH.$ENDNAME"
    fi
}

make_wheel_record() {
    FPATH=$1
    if echo $FPATH | grep RECORD >/dev/null 2>&1; then
	# if the RECORD file, then
	echo "$FPATH,,"
    else
	HASH=$(openssl dgst -sha256 -binary $FPATH | openssl base64 | sed -e 's/+/-/g' | sed -e 's/\//_/g' | sed -e 's/=//g')
	FSIZE=$(ls -nl $FPATH | awk '{print $5}')
	echo "$FPATH,sha256=$HASH,$FSIZE"
    fi
}

DEPS_LIST=(
    "/usr/lib64/libgomp.so.1"
)

DEPS_SONAME=(
    "libgomp.so.1"
)

mkdir -p /$WHEELHOUSE_DIR
cp pytorch/$WHEELHOUSE_DIR/*.whl /$WHEELHOUSE_DIR

for whl in /$WHEELHOUSE_DIR/torch*linux*.whl; do
    rm -rf tmp
    mkdir -p tmp
    cd tmp
    cp $whl .

    unzip -q $(basename $whl)
    rm -f $(basename $whl)
    
    # copy over needed dependent .so files over and tag them with their hash
    patched=()
    for filepath in "${DEPS_LIST[@]}"
    do
	filename=$(basename $filepath)
	destpath=torch/lib/$filename
	cp $filepath $destpath
	
	patchedpath=$(fname_with_sha256 $destpath)
	patchedname=$(basename $patchedpath)
	mv $destpath $patchedpath
	patched+=("$patchedname")
	echo "Copied $filepath to $patchedpath"
    done

    echo "patching to fix the so names to the hashed names"
    for ((i=0;i<${#DEPS_LIST[@]};++i));
    do
	find torch -name '*.so*' | while read sofile; do
	    origname=${DEPS_SONAME[i]}
	    patchedname=${patched[i]}
	    set +e
	    patchelf --print-needed $sofile | grep $origname 2>&1 >/dev/null
	    ERRCODE=$?
	    set -e
	    if [ "$ERRCODE" -eq "0" ]; then
		echo "patching $sofile entry $origname to $patchedname"
		patchelf --replace-needed $origname $patchedname $sofile
	    fi
	done
    done
    
    # set RPATH of _C.so and similar to $ORIGIN, $ORIGIN/lib
    find torch -maxdepth 1 -type f -name "*.so*" | while read sofile; do
	echo "Setting rpath of $sofile to " '$ORIGIN:$ORIGIN/lib'
	patchelf --set-rpath '$ORIGIN:$ORIGIN/lib' $sofile
	patchelf --print-rpath $sofile
    done
    
    # set RPATH of lib/ files to $ORIGIN
    find torch/lib -maxdepth 1 -type f -name "*.so*" | while read sofile; do
	echo "Setting rpath of $sofile to " '$ORIGIN'
	patchelf --set-rpath '$ORIGIN' $sofile
	patchelf --print-rpath $sofile
    done


    # regenerate the RECORD file with new hashes 
    record_file=`echo $(basename $whl) | sed -e 's/-cp.*$/.dist-info\/RECORD/g'`
    echo "Generating new record file $record_file"
    rm -f $record_file
    # generate records for torch folder
    find torch -type f | while read fname; do
	echo $(make_wheel_record $fname) >>$record_file
    done
    # generate records for torch-[version]-dist-info folder
    find torch*dist-info -type f | while read fname; do
	echo $(make_wheel_record $fname) >>$record_file
    done

    # zip up the wheel back
    zip -rq $(basename $whl) torch*

    # replace original wheel
    rm -f $whl
    mv $(basename $whl) $whl
    cd ..
    rm -rf tmp
done

mkdir -p /remote/$WHEELHOUSE_DIR
cp /$WHEELHOUSE_DIR/torch*.whl /remote/$WHEELHOUSE_DIR/

# Removed by @fritzo
# # remove stuff before testing
# rm -rf /opt/rh
# 
# export OMP_NUM_THREADS=4 # on NUMA machines this takes too long
# pushd pytorch/test
# for PYDIR in /opt/python/*; do
#     "${PYDIR}/bin/pip" uninstall -y torch
#     "${PYDIR}/bin/pip" install torch --no-index -f /$WHEELHOUSE_DIR
#     LD_LIBRARY_PATH="/usr/local/nvidia/lib64" PYCMD=$PYDIR/bin/python ./run_test.sh
# done
