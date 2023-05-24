#!/bin/sh
php /var/www/web/laravel/artisan optimize:clear
php /var/www/web/laravel/artisan optimize
php /var/www/web/laravel/artisan migrate --force
php-fpm
