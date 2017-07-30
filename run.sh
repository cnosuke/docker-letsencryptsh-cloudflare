#!/bin/bash
cd `dirname $0`

./dehydrated/dehydrated -c -d $DOMAIN -t dns-01 -k cloudflare-hook/hook.sh
