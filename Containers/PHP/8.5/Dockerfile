FROM trafex/php-nginx:3.12.0

ARG USER_ID=1000
ARG GROUP_ID=1000

# Install composer from the official image
COPY --from=composer:2.11.2 /usr/bin/composer /usr/bin/composer
COPY --from=mwader/static-ffmpeg:9.0.2 /ffmpeg /usr/local/bin/
COPY --from=mwader/static-ffmpeg:9.0.2 /ffprobe /usr/local/bin/

USER root

# upgrade first so fpm/common match the 8.5.x extensions installed below
RUN apk --update --no-cache upgrade

RUN apk --update --no-cache add \
    php85-fileinfo \
    php85-simplexml \
    php85-tokenizer \
    php85-xmlwriter \
    php85-pdo \
    php85-pdo_mysql \
    php85-pdo_pgsql \
    php85-pdo_sqlite \
    php85-zip \
    php85-iconv \
    php85-sockets \
    php85-sodium \
    php85-exif \
    php85-pcntl \
    php85-redis \
    php85-posix \
    php85-pear \
    php85-dev \
    php85-pecl-rdkafka \
    php85-pecl-imagick \
    php85-ffi \
    vips \
    vips-tools \
    vips-heif \
    vips-poppler \
    sed \
    make \
    g++ \
    autoconf \
    openssl-dev \
    brotli-dev \
    jpegoptim \
    optipng \
    pngquant \
    gifsicle \
    libavif \
    libavif-apps \
    nodejs \
    npm \
    pkgconfig

RUN echo "extension=ffi.so" > /etc/php85/conf.d/00_ffi.ini \
    && echo "ffi.enable=true" >> /etc/php85/conf.d/00_ffi.ini \
    && echo "zend.max_allowed_stack_size=-1" >> /etc/php85/conf.d/00_ffi.ini

RUN ln -sf $(which phpize85 || which phpize8 || which phpize) /usr/bin/phpize \
    && ln -sf $(which php-config85 || which php-config8 || which php-config) /usr/bin/php-config \
    && pecl85 channel-update pecl.php.net \
    && yes no | pecl85 install swoole-6.2.5 \
    && echo "extension=swoole.so" > /etc/php85/conf.d/00_swoole.ini \
    && apk del make g++ autoconf php85-dev php85-pear brotli-dev pkgconfig

RUN echo -e "\n[include]\nfiles = /etc/supervisor/custom.d/*.conf" >> /etc/supervisor/conf.d/supervisord.conf \
    && mkdir -p /etc/supervisor/custom.d

# nginx user uid/gid = owner of the files on the host, otherwise no access to the mounted code
RUN sed -i "s/nginx:x:100:101:/nginx:x:${USER_ID}:${GROUP_ID}:/" /etc/passwd && \
    sed -i "s/nginx:x:101:/nginx:x:${GROUP_ID}:/" /etc/group

RUN chown -R nginx:nginx /var/lib/nginx \
    && chown -R nginx:nginx /run \
    && touch /run/nginx.pid \
    && chown nginx:nginx /run/nginx.pid

# dev: a file change is visible on the very next request (by default opcache rechecks every 2 s)
RUN echo "opcache.revalidate_freq=0" > /etc/php85/conf.d/99_dev.ini

USER nginx
