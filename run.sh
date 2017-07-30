#!/bin/bash

set -eu

cd `dirname $0`

./dehydrated/dehydrated --register --accept-terms

./dehydrated/dehydrated -c -d $DOMAIN -t dns-01 -k cloudflare-hook/hook.sh
