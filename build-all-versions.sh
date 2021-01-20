#!/bin/bash
# This script is the authoritative source for what Provose Git branches
# belong in the official documentation.
#
# For example, we want to exclude branches that are not yet public.
set -Eeuxo pipefail
rm -rfv docs _site
./clone-docs-dir.sh v1.0
./clone-docs-dir.sh v1.1
./clone-docs-dir.sh v2.0
./clone-docs-dir.sh v3.0
./fix-titles.sh v1.0 "v1.0 (Deprecated)"
./fix-titles.sh v1.1 "v1.1 (Deprecated)"
./fix-titles.sh v2.0 "v2.0 (Deprecated)"
./fix-titles.sh v3.0 "v3.0 (Stable)"
jekyll build
touch docs/.nojekyll
cp CNAME docs