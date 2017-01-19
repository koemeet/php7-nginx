FROM php:7-fpm

ENV DEBIAN_FRONTEND noninteractive
ENV NGINX_VERSION 1.10.1-1~jessie

# we need a terminal to be set for all users by default
RUN touch /etc/profile.d/term && echo "export TERM=xterm" > /etc/profile.d/term

# install necessary prerequisites
RUN apt-get update && apt-get install -y supervisor software-properties-common vim git \
    zlib1g-dev libmemcached-dev wget libpq-dev build-essential xorg libssl-dev libxrender-dev gdebi \
    && rm -rf /var/lib/apt/lists/*

# install php extensions
RUN apt-get update && apt-get -y install libicu-dev \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install intl \
    && docker-php-ext-install opcache \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install pdo_pgsql \
    && pecl install xdebug \
    && pecl install apcu-5.1.3 \
    && docker-php-ext-enable apcu \
    && rm -rf /var/lib/apt/lists/*

# install wkhtmltox
RUN wget -q http://download.gna.org/wkhtmltopdf/0.12/0.12.3/wkhtmltox-0.12.3_linux-generic-amd64.tar.xz \
    && tar -xf wkhtmltox-0.12.3_linux-generic-amd64.tar.xz \
    && mv wkhtmltox/ /opt/

# install gd image manipulation library
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng12-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd exif

# install blackfire probe
RUN export VERSION=`php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;"` \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/${VERSION} \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp \
    && mv /tmp/blackfire-*.so `php -r "echo ini_get('extension_dir');"`/blackfire.so \
    && echo "extension=blackfire.so\nblackfire.agent_socket=\${BLACKFIRE_PORT}" > $PHP_INI_DIR/conf.d/blackfire.ini

# install blackfire agent
RUN wget -O - https://packagecloud.io/gpg.key | apt-key add - \
    && echo "deb http://packages.blackfire.io/debian any main" | tee /etc/apt/sources.list.d/blackfire.list \
    && apt-get update \
    && apt-get install blackfire-agent \
    && rm -rf /var/lib/apt/lists/*

RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
	&& echo "deb http://nginx.org/packages/debian/ jessie nginx" >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
						ca-certificates \
						nginx=${NGINX_VERSION} \
						nginx-module-xslt \
						nginx-module-geoip \
						nginx-module-image-filter \
						nginx-module-perl \
						nginx-module-njs \
						gettext-base \
	&& rm -rf /var/lib/apt/lists/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

COPY php.ini /usr/local/etc/php/php.ini
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80 443 9000

CMD ["/usr/bin/supervisord", "-n"]
