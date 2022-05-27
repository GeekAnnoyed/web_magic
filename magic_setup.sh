#!/bin/bash
clear

## update server
apt update && apt upgrade -y && apt autoremove -y && apt clean

## install needed packages
apt install ssh ntp git curl nginx php-fpm php-mysql php-mbstring php-xml php-gd php-curl php-redis php-zip php-imagick php-bcmath php-intl php-tokenizer redis zip unzip unattended-upgrades apt-listchanges -y

## configure unattended upgrades
dpkg-reconfigure --priority=low unattended-upgrades
## need to get additional config files for unattended-upgrades which would eliminate the previous step



## install php-ext-brotli
apt install php-dev -y
cd /etc/php
git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git
cd php-ext-brotli
phpize
./configure
make install clean

#auto install to highest installed version of php
highestPHP=(etc/php/*)

echo "extension=brotli.so" > "etc/php/"${highestPHP[-1]##*/}"/mods-available/brotli.ini"

phpenmod brotli
apt purge php-dev -y && apt autoremove -y && apt clean

cd /root

## database - enable if you are installing a DB on this server
#apt install mariadb-server -y && apt clean
#mysql_secure_installation


## setup temp directory
mkdir /root/.temp
cd /root/.temp

## get config files and copy to proper locations
wget https://config.nxps.me/nginx/default
wget https://config.nxps.me/nginx/mime.types
wget https://config.nxps.me/nginx/nginx.conf
wget https://config.nxps.me/nginx/whitelist.conf
wget https://config.nxps.me/nginx/wp-supercache.conf
wget https://config.nxps.me/php/php.ini
wget https://config.nxps.me/ssh/sshd_config
wget https://config.nxps.me/ssh/generic-key.pub

cp /root/.temp/default /etc/nginx/sites-available/default
cp /root/.temp/mime.types /etc/nginx/mime.types
cp /root/.temp/nginx.conf /etc/nginx/nginx.conf
cp /root/.temp/whitelist.conf /etc/nginx/whitelist.conf
cp /root/.temp/php.ini /etc/php/7.4/fpm/php.ini
cp /root/.temp/wp-supercache.conf /etc/nginx/snippets/wp-supercache.conf
cp /root/.temp/sshd_config /etc/ssh/sshd_config

mkdir /root/.ssh
cp /root/.temp/generic-key.pub /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

## clean up temp files
cd /root
rm -rf /root/.temp

## install scripts
mkdir /root/bin
cd /root/bin
wget https://config.nxps.me/scripts/update
wget https://config.nxps.me/scripts/wp-install
#wget https://config.nxps.me/scripts/mkdb
chmod +x *
cd /root

systemctl restart ssh


## complete
echo
echo
echo "Script Finished - Be Sure To Configure & Start NGINX"
echo "Replace Generic SSH Key If Necessary"
echo
