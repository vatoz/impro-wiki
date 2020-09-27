FROM php:7.3-apache

RUN apt-get update
RUN apt-get install -y --no-install-recommends \
  git \
  librsvg2-bin \
  python3 \
  unzip \
  imagemagick

RUN set -eux; \
  savedAptMark="$(apt-mark showmanual)"; \
  apt-get install -y --no-install-recommends \
    postgresql \
    libpq-dev \
    libicu-dev; \
  docker-php-ext-install -j "$(nproc)" \
    pgsql \
    intl \
    mbstring \
    opcache \
  ; \
  apt-mark auto '.*' > /dev/null; \
  apt-mark manual $savedAptMark; \
  ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    | awk '/=>/ { print $3 }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual; \
   apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  rm -rf /var/lib/apt/lists/*


RUN curl -SL https://getcomposer.org/composer-stable.phar > /usr/local/bin/composer
RUN chmod +x /usr/local/bin/composer

# Enable Short URLs
RUN set -eux; \
  a2enmod rewrite; \
  { \
    echo '<Directory /var/www/html>'; \
    echo '  RewriteEngine On'; \
    echo '  RewriteCond %{REQUEST_FILENAME} !-f'; \
    echo '  RewriteCond %{REQUEST_FILENAME} !-d'; \
    echo '  RewriteRule ^ %{DOCUMENT_ROOT}/index.php [L]'; \
    echo '</Directory>'; \
  } > "$APACHE_CONFDIR/conf-available/short-url.conf"; \
  a2enconf short-url

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.fast_shutdown=1'; \
  } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Version
ENV MEDIAWIKI_MAJOR_VERSION 1.34
ENV MEDIAWIKI_BRANCH REL1_34
ENV MEDIAWIKI_VERSION 1.34.4
ENV MEDIAWIKI_SHA512 3a03ac696e2d5300faba0819ba0d876a21798c8dcdc64cc2792c6db0aa81d4feaced8dc133b6ca3e476c770bf51516b0a624cb336784ae3d2b51c8c0aa5987a0

# MediaWiki setup
RUN set -eux; \
	curl -fSL "https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_MAJOR_VERSION}/mediawiki-${MEDIAWIKI_VERSION}.tar.gz" -o mediawiki.tar.gz; \
	echo "${MEDIAWIKI_SHA512} *mediawiki.tar.gz" | sha512sum -c -; \
	tar -x --strip-components=1 -f mediawiki.tar.gz; \
	rm mediawiki.tar.gz; \
	chown -R www-data:www-data extensions skins cache images

COPY install-extension.sh install-extension.sh
COPY improliga-logo.png resources/assets/improliga-logo.png
COPY improliga-logo-small.png resources/assets/improliga-logo-small.png

RUN ./install-extension.sh https://extdist.wmflabs.org/dist/extensions/HitCounters-REL1_34-48dd6cb.tar.gz HitCounters
RUN ./install-extension.sh https://extdist.wmflabs.org/dist/extensions/TopTenPages-REL1_34-9b9c4b8.tar.gz TopTenPages
RUN ./install-extension.sh https://extdist.wmflabs.org/dist/extensions/ConfirmEdit-REL1_34-45ca059.tar.gz ConfirmEdit
RUN ./install-extension.sh https://github.com/edwardspec/mediawiki-aws-s3/archive/v0.11.0.tar.gz AWS

COPY LocalSettings.php LocalSettings.php

