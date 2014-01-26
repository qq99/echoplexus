#!/bin/bash

./configure \
    --prefix=/usr/share/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/lock/nginx.lock \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/access.log \
    --user=www-data \
    --group=www-data \
    --with-http_spdy_module \
    --with-ipv6 \
    --with-http_ssl_module \
    --with-http_spdy_module \
    --with-http_stub_status_module \
    --with-http_gzip_static_module \
    --add-module=/home/anthony/nginx_modules/headers-more-nginx-module
