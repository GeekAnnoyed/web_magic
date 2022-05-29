#/bin/bash
workingDir='pwd'

SUDO=''
if (( $EUID != 0 )); then
    SUDO='sudo'
fi
whiptail --title "root or sudo required" --msgbox "this script needs to run as root, if the current user is not root I will ask for the user password for sudo user privilage escalation." 10 60

# setup sury.org php repo, get required gpg key, pull in any updates to repo listings
$SUDO sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
$SUDO curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
$SUDO apt-get update

# install any required packages
$SUDO apt install ssh ntp git curl nginx php-fpm php-mysql php-mbstring php-xml php-gd php-curl php-redis php-zip php-imagick php-bcmath php-intl php-tokenizer redis zip unzip unattended-upgrades apt-listchanges apt-transport-https lsb-release ca-certificates -y

# install the required gpg key
# reconfigure to automatically install updates
if (whiptail --title "setup automatic unattended upgrades" --yes-button "Yes" --no-button "No"  --yesno "Setup automatic unattended upgrades?" 10 60) then
    $SUDO dpkg-reconfigure --priority=low unattended-upgrades
else
    continue
fi

if (whiptail --title "build and install brotli PHP extention" --yes-button "Yes" --no-button "No"  --yesno "build and install brotli PHP extention?" 10 60) then
    ## install php-ext-brotli
    apt install php-dev -y
    cd /etc/php
    git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git
    cd php-ext-brotli
    phpize
    ./configure
    make install clean

    #auto install to highest installed version of php
    highestPHP=(/etc/php/*)
    echo "extension=brotli.so" > "etc/php/"${highestPHP[-1]##*/}"/mods-available/brotli.ini"

    phpenmod brotli
    apt purge php-dev -y && apt autoremove -y && apt clean

else
    continue
fi


if (whiptail --title "install mariadb and secure mysql?" --yes-button "Yes" --no-button "No"  --yesno "install mariadb and secure mysql?" 10 60) then
    $SUDO apt install mariadb-server -y 
    $SUDO apt clean
    $SUDO mysql_secure_installation
else
    continue
fi


if (whiptail --title "Copy sane defaults for nginx?" --yes-button "Yes" --no-button "No"  --yesno "Copy sane defaults for nginx?" 10 60) then
    cp $workingDir/configs/default /etc/nginx/sites-available/default
    cp $workingDir/configs/mime.types /etc/nginx/mime.types
    cp $workingDir/configs/nginx.conf /etc/nginx/nginx.conf
    cp $workingDir/configs/whitelist.conf /etc/nginx/whitelist.conf
    cp $workingDir/configs/php.ini /etc/php/7.4/fpm/php.ini
    cp $workingDir/configs/wp-supercache.conf /etc/nginx/snippets/wp-supercache.conf
    cp $workingDir/configs/sshd_config /etc/ssh/sshd_config

else
    continue
fi

