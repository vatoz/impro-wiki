#!/usr/bin/env bash
full_path=/var/www/html/extensions/$2

mkdir $full_path
curl -SL $1 | tar --strip 1 -x -z -C $full_path

if [ -f $full_path/composer.json ]; then
  cd $full_path
  composer install
  cd ..
fi
