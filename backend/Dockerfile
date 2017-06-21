# Take PHP 7.1 as a base image
FROM php:7.1-alpine

# Install curl for the healthcheck
RUN apk add --update curl

# Install PHP Redis extension (for a later assignment)
RUN apk update \
    && apk add \
    --virtual .build-dependencies \
        autoconf \
        g++ \
        make \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-dependencies \
    && php -m | grep redis

# Expose a running instance of PHP's built-in web server
ENTRYPOINT ["php", "-S", "0.0.0.0:80", "-t", "web/"]

# The built-in PHP webserver only responds to SIGINT, not to SIGTERM
STOPSIGNAL SIGINT

# The code will be in /opt
COPY ./ /opt
WORKDIR /opt
