FROM php:8.1.19-fpm-alpine3.18

RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk --no-cache add bash

RUN docker-php-ext-install bcmath pdo_mysql

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY --chown=www-data:www-data web/laravel /var/www/web/laravel

RUN composer install --working-dir=/var/www/web/laravel --no-progress --no-suggest --prefer-dist --optimize-autoloader

RUN chown www-data:www-data /var/www/web/laravel
USER www-data
WORKDIR /var/www/web/laravel

COPY --chown=www-data:www-data ecs/dev/container/php-fpm/startup.sh /startup.sh
RUN chmod 700 /startup.sh

CMD ["/startup.sh"]
EXPOSE 9000
