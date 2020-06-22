#!/bin/bash
# This bash script bumps the minor version for v1.0.
if [ "$#" -ne 2 ]
then
    echo "2 arguments required, $# provided"
    echo "We need an old version and a new version, like:"
    echo "./bump-minor-version v1.0.2 v1.0.3"
    exit 1
fi

RAW_OLD_VERSION=$1
OLD_VERSION=$(echo $1 | sed 's/\./\\./g')
NEW_VERSION=$2

find v1.0 _includes/v1.0/ \( -name '*.md' -or -name '*.tf' \) -exec sed -i '' "s/$OLD_VERSION/$NEW_VERSION/g" {} \;
