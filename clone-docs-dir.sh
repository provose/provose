#!/bin/bash
# This script ONLY clones the docs directory for the Provose repo.
set -Eeuxo pipefail
rm -rf ./cache ./$1
git clone --quiet --single-branch --branch $1.x --quiet --depth 1 --filter=blob:none --no-checkout https://github.com/provose/provose cache
cd cache
git checkout $1.x -- docs 2> /dev/null
cd ..
mv cache/docs $1
rm -rf ./cache
