#!/usr/bin/bash

printf "[?] Scorebot Setup v1\n"

printf "[?] IP Address with Slash: "
read address

printf "[?] Gateway: "
read gateway

printf "[?] DNS 1: "
read dns1

printf "[?] DNS 2: "
read dns2

if [ -z $address ] || [ -z $gateway ] || [ -z $dns1 ] || [ -z $dns2 ]; then
    printf "[!] Invalid network settings! Quitting!\n"
    exit 1
fi

printf "[?] Role (0 - Core, 1 - DB, 2 - Proxy) [0-2]: "
read role

packages=""
case $role in
    0)
    packages="apache mod_wsgi python python-pip python-virtualenv python-django gcc mariadb-clients python-mysqlclient"
    ;;
    1)
    packages="mariadb"
    ;;
    2)
    packages="apache"
    ;;
    *)
    printf "[!] Invalid role! Quitting\n"
    exit 1
    ;;
esac

printf "[+] Updating system....\n"
pacman -Syu --noconfirm
printf "[+] Installing required packages..\n"
pacman -S git net-tools pacman-contrib --noconfirm
pacman -S $packages --noconfirm

if [ $role -eq 0 ] || [ $role -eq 2 ]; then
    rm -rf /etc/httpd/conf/extra
    rm /etc/httpd/conf/httpd.conf
fi

if [ -d /opt/sysconfig ]; then
    mv /opt/sysconfig /opt/sysconfig.bak
fi

git clone https://github.com/iDigitalFlame/scorebot-sysconfig /opt/sysconfig
printf "SYSCONFIG=/opt/sysconfig\n" > /etc/sysconfig.conf
chmod 444 /etc/sysconfig.conf

mkdir -p /opt/sysconfig/etc/udev.d/rules.d
mkdir -p /opt/sysconfig/etc/systemd/network
mac=$(ifconfig | grep ether | awk '{print $2}')
printf "[Match]\nName=en0\n\n[Network]Address=$address\nDNS=$dns1\nDNS=dns$2\n\n[Route]\nGateway=$gateway\n" > /opt/sysconfig/etc/systemd/network/en0.network
printf "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$mac\", NAME=\"en0\"" > /opt/sysconfig/etc/udev.d/rules.d/10-network.rules

bash /opt/sysconfig/bin/relink /opt/sysconfig / 2> /dev/null
bash /opt/sysconfig/bin/syslink 1> /dev/null 2> /dev/null
syslink 1> /dev/null 2> /dev/null

systemctl enable sshd.service 1> /dev/null
systemctl enable fstrim.timer  1> /dev/null
systemctl enable checkupdates.timer 1> /dev/null
systemctl enable checkupdates.service 1> /dev/null
systemctl enable reflector.timer 1> /dev/null
systemctl enable reflector.service 1> /dev/null

if [ $role -eq 0 ]; then
    printf "scorebot-core" > /opt/sysconfig/etc/hostname
    syslink 1> /dev/null
    mkdir /opt/scorebot/versions -p
    printf "[+] Building virtual env...\n"
    virtualenv --always-copy /opt/scorebot/python 1> /dev/null
    git clone https://github.com/iDigitalFlame/scorebot-core /opt/scorebot/version/release
    ln -s /opt/scorebot/version/release /opt/scorebot/current
    printf "[+] Installing PIP requirements..\n"
    bash -c "source /opt/scorebot/python/bin/activate; cd /opt/scorebot/current; unset PIP_USER; pip install -r requirements.txt" 1> /dev/null
    printf "[?] Databse server IP? "
    read sbe_db
    printf "[?] Databse 'Scorebot' password? "
    read sbe_db_pass
    sed -ie "s/\"PASSWORD\": \"password\",/\"PASSWORD\": \"$sbe_db_pass\",/g" /opt/scorebot/current/scorebot/settings.py
    rm /opt/scorebot/current/scorebot/*e
    printf "127.0.0.1 scorebot\n$sbe_db scorebot-db\n" > /opt/sysconfig/etc/hosts
    syslink
    bash -c "source /opt/scorebot/python/bin/activate; cd /opt/scorebot/current; env SBE_SQLLITE=0 python manage.py makemigrations scorebot_grid scorebot_core scorebot_game"
    bash -c "source /opt/scorebot/python/bin/activate; cd /opt/scorebot/current; env SBE_SQLLITE=0 python manage.py migrate"
    printf "[?] Django superuser password? "
    read db_pass
    bash -c "source /opt/scorebot/python/bin/activate; cd /opt/scorebot/current; env SBE_SQLLITE=0 python manage.py shell -c \"from django.contrib.auth.models import User; User.objects.create_superuser('root', '', '$db_pass')\""
    printf "[+] Created default account \"root\" with supplied password!\n"
    ln -s /opt/sysconfig/etc/httpd/conf/roles/core.conf /etc/httpd/conf/scorebot-role.conf
    ln -s /usr/lib/python3.*/site-packages/django/contrib/admin/static/admin /opt/scorebot/current/scorebot_static/admin
    chown root:http -R /opt/scorebot/
    chmod 550 -R /opt/scorebot/current/
    mkdir -p /opt/scorebot/current/scorebot_media
    chown http:http /opt/scorebot/current/scorebot_media
    chmod 775 /opt/scorebot/current/scorebot_media
    systemctl enable httpd.service 1> /dev/null
    systemctl enable scorebot.service 1> /dev/null
    systemctl start httpd.service 1> /dev/null
    systemctl start scorebot.service 1> /dev/null
fi

if [ $role -eq 1 ]; then
    printf "scorebot-db" > /opt/sysconfig/etc/hostname
    syslink
    mysql_install_db --basedir=/usr --ldata=/var/lib/mysql --user=mysql
    systemctl enable mysqld 1> /dev/null
    systemctl start mysqld 1> /dev/null
    mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
    mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -u root -e "DROP DATABASE IF EXISTS test;"
    mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    mysql -u root -e "FLUSH PRIVILEGES;"
    mysql -u root -e "CREATE DATABASE scorebot_db;"
    printf "[?] Scorebot user password? "
    read sbe_db_pass
    printf "[?] Scorebot server IP? "
    read sbe_core
    printf "127.0.0.1 scorebot-db\n$sbe_core scorebot-core\n" > /opt/sysconfig/etc/hosts
    syslink
    mysql -u root -e "GRANT ALL ON scorebot_db.* TO 'scorebot'@'scorebot-core' IDENTIFIED BY '$sbe_db_pass';"
    printf "[?] Mysql root password? "
    read django_pass
    mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('$django_pass') WHERE User='root';"
    printf "[+] Created default account \"root\" with supplied password!\n"
    systemctl restart mysqld 1> /dev/null
fi

if [ $role -eq 2 ]; then
    printf "scorebot-proxy" > /opt/sysconfig/etc/hostname
    syslink
    printf "Scorebot IP to proxy? "
    read sbe_core
    ln -s /opt/sysconfig/etc/httpd/conf/roles/proxy.conf /etc/httpd/conf/scorebot-role.conf
    printf "127.0.0.1 scorebotproxy\n$sbe_core scorebot-core\n" > /opt/sysconfig/etc/hosts
    syslink
    systemctl enable httpd.service 1> /dev/null
    systemctl start httpd.service 1> /dev/null
fi

syslink
printf "[+] Done\n"