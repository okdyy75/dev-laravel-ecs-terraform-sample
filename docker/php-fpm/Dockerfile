FROM php:8.1.19-fpm-alpine3.18

RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk --no-cache add bash

RUN docker-php-ext-install bcmath pdo_mysql

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/web

CMD ["php-fpm"]