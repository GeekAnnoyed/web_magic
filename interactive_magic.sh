#/bin/bash

workingDir=$(pwd)

echo "this script needs to run as root, if the current user is not root it will ask for the user password for sudo user privilage escalation."
whiptail --title "root or sudo required" --msgbox "this script needs to run as root, if the current user is not root I will ask for the user password for sudo user privilage escalation." 10 60

SUDO=''
if (( $EUID != 0 )); then
    SUDO='sudo'
fi

# install required packages 
#TODO fix so only required packages are installed for each function

# $SUDO apt whiptail install ssh ntp git curl nginx php-fpm php-mysql php-mbstring php-xml php-gd php-curl php-redis php-zip php-imagick php-bcmath php-intl php-tokenizer redis zip unzip unattended-upgrades apt-listchanges apt-transport-https lsb-release ca-certificates -y
    
tempfile=$(mktemp)
trap 'rm -f "$tempfile"' EXIT

if TASKS=$(whiptail --title "Install task?" 3>&1 >&2 --output-fd 3 --checklist \
    "Choose Install and configuration tasks" 20 100 10 \
    "unattended_upgrades" "Install security updates and reboot at 2am if needed" ON \
    "PHP" "Newer PHP packages from sury.org" ON \
    "Brotli" "Brotli, build (git), install and activate" ON \
    "MYSQL" "Install mariadb and run secure_mysql" ON \
    "NGINX" "Set 'sane' defaults for nginx" ON \
    "WordPress" "install and configure Wordpress" OFF
    )   
    then
        mapfile -t choices <<< "$TASKS"
        printf 'You chose:\n'
        printf '  %s\n' "${choices[@]}"
    else
        printf >&2 'Aborted\n'
        exit 1
    fi

    if [[ "$TASKS" == *"unattended_upgrades"* ]]; then
        # execute unattended_upgrades function
        unattended_upgrades
    fi
    if [[ "$TASKS" == *"PHP"* ]]; then
        # execute PHP function
        PHP 
    fi
    if [[ "$TASKS" == *"Brotli"* ]]; then
        # execute Brotli function
        Brotli
    fi
    if [[ "$TASKS" == *"MYSQL"* ]]; then
        # execute MYSQL function
        mysql
    fi
    if [[ "$TASKS" == *"NGINX"* ]]; then
        # execute NGINX function
        nginx
    fi
    if [[ "$TASKS" == *"WordPress"* ]]; then
        # execute Wordpress function
        wordpress
    fi


function PHP(
# setup sury.org php repo, get required gpg key, pull in any updates to repo listings
    $SUDO sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
    $SUDO curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
    $SUDO apt-get update
)


function unattended_upgrades(
# # reconfigure to automatically install updates
    $SUDO dpkg-reconfigure --priority=low unattended-upgrades
)


function brotli(
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

)


function mysql(
    $SUDO apt install mariadb-server -y 
    $SUDO apt clean
    $SUDO mysql_secure_installation
)

function nginx(
    cp $workingDir/configs/default /etc/nginx/sites-available/default
    cp $workingDir/configs/mime.types /etc/nginx/mime.types
    cp $workingDir/configs/nginx.conf /etc/nginx/nginx.conf
    cp $workingDir/configs/whitelist.conf /etc/nginx/whitelist.conf
    cp $workingDir/configs/php.ini /etc/php/7.4/fpm/php.ini
    cp $workingDir/configs/wp-supercache.conf /etc/nginx/snippets/wp-supercache.conf
    cp $workingDir/configs/sshd_config /etc/ssh/sshd_config
)

function wordpress(
    # wordpress install





    #create destination
    mkdir $instdir
    # Create a temporary directory and store its name in a variable.
    TEMPD=$(mktemp -d)

    # Exit if the temp directory wasn't created successfully.
    if [ ! -e "$TEMPD" ]; then
        >&2 echo "Failed to create temp directory"
        exit 1
    fi

    # Make sure the temp directory gets removed on script exit.
    trap "exit 1"           HUP INT PIPE QUIT TERM
    trap 'rm -rf "$TEMPD"'  EXIT
    cd $TEMPD

    #download wordpress
    curl -O https://wordpress.org/latest.tar.gz
    #unzip wordpress
    tar -zxvf latest.tar.gz
    #change dir to wordpress
    cd wordpress
    #copy files to destination
    cp -rf . $instdir
    #move back to temp
    cd /root/.temp
    #clean up temp dir
    rm -rf *

    #move to wordpress dir
    cd $instdir
    #create wp config
    cp wp-config-sample.php wp-config.php
    #set database details with perl find and replace
    perl -pi -e "s/database_name_here/$dbname/g" wp-config.php
    perl -pi -e "s/username_here/$dbuser/g" wp-config.php
    perl -pi -e "s/password_here/$dbpass/g" wp-config.php

    #set WP salts
    perl -i -pe'
    BEGIN {
        @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
        push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
        sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
    }
    s/put your unique phrase here/salt()/ge
    ' wp-config.php

    #create uploads folder and set permissions
    mkdir wp-content/uploads
    chmod 775 wp-content/uploads

    #change ownership
    chown -R www-data:www-data $instdir
    cd /root

    #create mysql database
    mysql -e "create database ${dbname};"
    #create mysql user
    mysql -e "create user '${dbuser}'@'localhost' identified by '${dbpass}';"
    #set mysql permissions & flush privileges
    mysql -e "grant all privileges on ${dbname}.* to '${dbuser}'@'localhost';"
    mysql -e "flush privileges;"

)