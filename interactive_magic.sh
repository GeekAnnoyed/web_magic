#/bin/bash


FILE=$(which whiptail)
if ! [ -f "$FILE" ]
then
    echo "File $FILE does not exist"
fi


SUDO=''
if (( $EUID != 0 )); then
    SUDO='sudo'
fi

$SUDO apt install whiptail -y

workingDir=$(pwd)

echo "this script needs to run as root, if the current user is not root it will ask for the user password for sudo user privilage escalation."
whiptail --title "root or sudo required" --msgbox "this script needs to run as root, if the current user is not root I will ask for the user password for sudo user privilage escalation." 10 60


# install required packages 
#TODO fix so only required packages are installed for each function
#
$SUDO apt install whiptail ssh ntp git curl nginx php-fpm php-mysql php-mbstring php-xml php-gd php-curl php-redis php-zip php-imagick php-bcmath php-intl php-tokenizer redis zip unzip unattended-upgrades apt-listchanges apt-transport-https lsb-release ca-certificates -y
    
tempfile=$(mktemp)
trap 'rm -f "$tempfile"' EXIT



function PHP(
# setup sury.org php repo, get required gpg key, pull in any updates to repo listings
    #$SUDO sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee -a  /etc/apt/sources.list.d/php.list'
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
    $SUDO cp -rf . $INSTLLOCAL
    #clean up temp dir
    $SUDO rm -rf $TEMPD

    #move to wordpress dir
    cd $instdir
    #create wp config
    cp wp-config-sample.php wp-config.php

    #set database details with perl find and replace
    perl -pi -e "s/database_name_here/$DBNAME/g" wp-config.php
    perl -pi -e "s/username_here/$DBUSER/g" wp-config.php
    perl -pi -e "s/password_here/$DBPASS/g" wp-config.php

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
    $SUDO mkdir wp-content/uploads
    $SUDO chmod 775 wp-content/uploads

    #change ownership
    $SUDO chown -R www-data:www-data $instdir
    
    #create mysql database
    $SUDO mysql -e "create database ${DBNAME};"
    #create mysql user
    $SUDO mysql -e "create user '${DBUSER}'@'localhost' identified by '${DBPASS}';"
    #set mysql permissions & flush privileges
    $SUDO mysql -e "grant all privileges on ${DBNAME}.* to '${DDNAME}'@'localhost';"
    $SUDO mysql -e "flush privileges;"

)



if TASKS=$(whiptail --title "Install task?" 3>&1 >&2 --output-fd 3 --checklist \
    "Choose Install and configuration tasks" 20 100 10 \
    "unattended_upgrades" "Install security updates and reboot at 2am if needed" ON \
    "PHP" "Newer PHP packages from sury.org" ON \
    "Brotli" "Brotli, build (git), install and activate" ON \
    "MYSQL" "Install mariadb and run secure_mysql" ON \
    "NGINX" "Set 'sane' defaults for nginx" ON \
    "WordPress" "install and configure Wordpress" ON
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
        DBNAME=''
        DBPASS=''
        DBUSER=''

        DBNAME=$(whiptail --inputbox "What is would you like as your DB name? Leave bank for random" 8 39 --title "database name" 3>&1 1>&2 2>&3)
        DBUSER=$(whiptail --inputbox "What would you like as database username? leave blank for random" 8 39 --title "database username" 3>&1 1>&2 2>&3)
        DBPASS=$(whiptail --inputbox "what wouuld you like as the database password? leave blank for random" 8 39 --title "database pasword" 3>&1 1>&2 2>&3)
        INSTLLOCAL=$(whiptail --inputbox "Where would you like to install Wordpress? e.g /var/www/sitedomain" 8 39 --title "Install location" 3>&1 1>&2 2>&3)
        if [[ -n $DBNAME ]];
        then
            
            echo "Not generating DBNAME"
        else
            echo "random DBNAME made"
            DBNAME=$(date +%s | sha256sum | base64 | head -c 32)
            echo $DBNAME
            
        fi

        if [[ -n $DBPASS ]];
        then

            echo "Not generating DBPASS"
        else
            echo "random DBPASS made"
            DBUSER=$(date +%s | sha256sum | base64 | head -c 32)
            echo $DBUSER            
        fi

        if [[ -n $DBPASS ]];
        then
            echo "not generating DBUSER"

        else
            echo "random DBUSER made"
            DBPASS=$(date | md5sum)
            echo $DBPASS
            
        fi

        

        wordpress
    fi

