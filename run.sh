#!/bin/bash
cd `dirname $0`

./letsencrypt.sh/letsencrypt.sh -c -d $DOMAIN -t dns-01 -k cloudflare-hook/hook.sh
