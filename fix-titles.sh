#!/bin/bash
set -Eeuxo pipefail
export DIR_NAME=$1
export TITLE_NAME=$2
# TODO: Run `find` only once.
find $DIR_NAME \( -type d -name .git -prune \) -o -type f -iname '*.md' -exec sed -i "s/^title: Docs/title: Docs $TITLE_NAME/" {} ';'
find $DIR_NAME \( -type d -name .git -prune \) -o -type f -iname '*.md' -exec sed -i "s/^parent: Docs/parent: Docs $TITLE_NAME/" {} ';'
find $DIR_NAME \( -type d -name .git -prune \) -o -type f -iname '*.md' -exec sed -i "s/^grand_parent: Docs/grand_parent: Docs $TITLE_NAME/" {} ';'
find $DIR_NAME \( -type d -name .git -prune \) -o -type f -iname '*.md' -exec sed -i "s/^parent: Reference/parent: Reference $TITLE_NAME/" {} ';'
