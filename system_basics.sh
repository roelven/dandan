#!/bin/bash

#

# System basics

#

# Copyright (c) 2019 Roel van der Ven (hello@roelvanderven.com)

# based on https://www.linode.com/stackscripts/view/123

#

###########################################################

# Updates & Basic Configs

###########################################################

function lower {

    # helper function

    echo $1 | tr '[:upper:]' '[:lower:]'

}

function system_update {

    apt-get update && apt-get install -y aptitude

    aptitude -y full-upgrade

}

function system_install_basics {

    locale-gen en_US en_US.UTF-8 en_GB.UTF-8 en_GB

    dpkg-reconfigure locales

    #set timezone to UTC

    ln -s -f /usr/share/zoneinfo/UTC /etc/localtime

    aptitude -y install monit wget curl less htop mytop fail2ban logrotate bash-completion rsync

    sed -i -e 's/^#PS1=/PS1=/' /root/.bashrc # enable the colorful root bash prompt

    sed -i -e "s/^#alias ll='ls -l'/alias ll='ls -al'/" /root/.bashrc # enable ll list long alias <3

}

function system_security_configure_ufw {

    ufw logging on

    ufw default deny

    ufw allow ssh/tcp

    ufw limit ssh/tcp

    ufw enable

}

function system_update_hostname {

	# system_update_hostname(hostname)

    if [ -z "$1" ]; then

        echo "system_update_hostname() requires the system hostname as its first argument"

        return 1;

    fi

    echo $1 > /etc/hostname

    hostname -F /etc/hostname

    echo -e "\n127.0.0.1 $1 $1.local\n" >> /etc/hosts

}

function system_sshd_security {

    # Disables root SSH access and password logins.

    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

    sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

    touch /tmp/restart-ssh

}

function system_restart_services {

    # restarts upstart services that have a file in /tmp/

    system_restart_initd_services

    for service_name in $(ls /tmp/ | grep restart-* | cut -d- -f2-10); do

        service $service_name restart

        rm -f /tmp/restart-$service_name

    done

}

function system_restart_initd_services {

    # restarts upstart services that have a file in /tmp

    for service_name in $(ls /tmp/ | grep restart_initd-* | cut -d- -f2-10); do

        /etc/init.d/$service_name restart

        rm -f /tmp/restart_initd-$service_name

    done

}

function install_php-fpm {

    add-apt-repository ppa:ondrej/php -y && apt update -y

    apt install -y php5.6-fpm php5.6-mysql php5.6-curl php5.6-gd php5.6-mcrypt php5.6-memcache php5.6-zip php5.6-common php5.6-mbstring php5.6-opcache

}

function install_mariadb {

    apt install -y mariadb-server mariadb-client

    echo "Sleeping while MySQL starts up for the first time..."

    sleep 5

    echo "0 0 * * 0 mysqlcheck -o --user=root --password="$DB_PASSWORD" -A" | crontab -

}

function install_nginx {

    add-apt-repository -y ppa:nginx/stable

    aptitude update

    aptitude -y install nginx

    cat <<EOT > /etc/nginx/fastcgi_config

fastcgi_intercept_errors on;

fastcgi_ignore_client_abort on;

fastcgi_connect_timeout 60;

fastcgi_send_timeout 180;

fastcgi_read_timeout 180;

fastcgi_buffer_size 128k;

fastcgi_buffers 4 256k;

fastcgi_busy_buffers_size 256k;

fastcgi_temp_file_write_size 256k;

fastcgi_max_temp_file_size 0;

fastcgi_index index.php;

EOT

    cat <<EOT > /etc/nginx/sites-available/nginx_status

server {

    listen 127.0.0.1:80;

    location /nginx_status {

        stub_status on;

        access_log off;

    }

}

EOT

    ln -sf /etc/nginx/sites-available/nginx_status /etc/nginx/sites-enabled/nginx_status

    service nginx stop

    sed -i 's/# gzip_types/gzip_types/' /etc/nginx/nginx.conf

    sed -i 's/# gzip_vary/gzip_vary/' /etc/nginx/nginx.conf

}

###########################################################

# Users and Authentication

###########################################################

function user_add_sudo {

    # Installs sudo if needed and creates a user in the sudo group.

    #

    # $1 - Required - username

    # $2 - Required - password

    USERNAME="$1"

    USERPASS="$2"

    if [ ! -n "$USERNAME" ] || [ ! -n "$USERPASS" ]; then

        echo "No new username and/or password entered"

        return 1;

    fi

    

    aptitude -y install sudo

    adduser $USERNAME --disabled-password --gecos ""

    echo "$USERNAME:$USERPASS" | chpasswd

    usermod -aG sudo $USERNAME

}

function user_add_pubkey {

    # Adds the users public key to authorized_keys for the specified user. Make sure you wrap your input variables in double quotes, or the key may not load properly.

    #

    #

    # $1 - Required - username

    # $2 - Required - public key

    USERNAME="$1"

    USERPUBKEY="$2"

    

    if [ ! -n "$USERNAME" ] || [ ! -n "$USERPUBKEY" ]; then

        echo "Must provide a username and the location of a pubkey"

        return 1;

    fi

    

    if [ "$USERNAME" == "root" ]; then

        mkdir /root/.ssh

        echo "$USERPUBKEY" >> /root/.ssh/authorized_keys

        return 1;

    fi

    

    mkdir -p /home/$USERNAME/.ssh

    echo "$USERPUBKEY" >> /home/$USERNAME/.ssh/authorized_keys

    chown -R "$USERNAME":"$USERNAME" /home/$USERNAME/.ssh

}

function ssh_disable_root {

    # Disables root SSH access.

    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

    touch /tmp/restart-ssh

    

}

