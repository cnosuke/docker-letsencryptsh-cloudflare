# What's this?

Dockerfile to create TLS certs file with [Let's Encrypt](https://letsencrypt.org/)
using [letsencrypt.sh](https://github.com/lukas2511/letsencrypt.sh)
with Cloudflare API hooks.

# Usage

```
% cat envs
CF_API_KEY=cloudflare_api_key_here
CF_API_MAIL=your_cloudflare_account_email@example.com
CF_ZONE=example.com
CF_SUBDOMAIN=subdomain_here_if_exist
DOMAIN=subdomain_here_if_exist.example.com
```

```
% docker run --rm --env-file envs -v path_to_save_certs_file_on_host:/certs cnosuke/letsencryptsh-cloudflare
```

# LICENSE

- MIT LICENSE.
- Copyright (c) 2016 Shinnosuke Takeda (cnosuke)
