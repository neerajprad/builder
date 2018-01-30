#!/bin/bash

if [ ! -d wheelhousecpu ]
then
	echo "Error: wheelhousecpu directory not found"
	exit 1
fi

mkdir -p pytorch-whls-bkp
aws s3 sync s3://pyro-ppl/ci pytorch-whls-bkp --profile pyro-ci
aws s3 rm s3://pyro-ppl/ci --recursive --profile pyro-ci

ls -t wheelhousecpu/ | grep -m 2 -E "cp35m|cp27mu" | xargs -I {} bash -c 'aws s3 cp wheelhousecpu/{} s3://pyro-ppl/ci/ --acl public-read --profile pyro-ci'
