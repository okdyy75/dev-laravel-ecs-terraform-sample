FROM nginx:1.24.0-alpine3.17

ARG PHP_FPM_UPSTREAM="127.0.0.1:9000"

COPY ecs/dev/container/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ecs/dev/container/nginx/templates /etc/nginx/templates

RUN echo "upstream php-fpm { server ${PHP_FPM_UPSTREAM}; }" > /etc/nginx/conf.d/upstream.conf


CMD ["nginx"]

EXPOSE 80