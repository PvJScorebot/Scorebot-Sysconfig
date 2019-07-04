#!/usr/bin/bash

VERBOSE=0

SCOREBOT_BRANCH=""
SCOREBOT_DIR="/opt/scorebot"
SCOREBOT_URL="https://github.com/iDigitalFlame/scorebot-core"

SYSCONFIG_DIR="/opt/sysconfig"
SYSCONFIG_URL="https://github.com/iDigitalFlame/scorebot-sysconfig"

if [ $# -eq 2 ] && ([ $1 == "-v"] || [ $2 == "-v" ]); then
    VERBOSE=1
fi

log() {
    if [ $# -ne 1 ]; then
        return 0
    fi
    printf "[+] $1\n"
}
run() {
    if [ $# -ne 1 ]; then
        return 0
    fi
    if [ $VERBOSE -eq 1 ]; then
        printf "[V] Running \"$1\"\n"
    fi
    bash -c "$1; exit \$?"
    if [ $? -ne 0 ]; then
        printf "[!] Command \"$1\" did not exit with zero, quitting!\n"
        exit 1
    fi
    return 1
}

setup() {
    log "Updating system.."
    run "pacman -Syy" 1> /dev/null
    run "pacman -Syu --noconfirm --noprogressbar"
    log "Installing required packages.."
    run "pacman -S git net-tools pacman-contrib --noconfirm --noprogressbar"
    log "Downloading sysconfig base from github.."
    if [ -d "$SYSCONFIG_DIR" ]; then
        mv "$SYSCONFIG_DIR" "${SYSCONFIG_DIR}.old"
    fi
    run "git clone \"$SYSCONFIG_URL\" \"$SYSCONFIG_DIR\""
    if [ -d "${$SYSCONFIG_DIR}.old/etc/systemd/network" ]; then
        mkdir -p "${SYSCONFIG_DIR}/etc/systemd/network"
        cp ${SYSCONFIG_DIR}.old/etc/systemd/network/* "${SYSCONFIG_DIR}/etc/systemd/network/"
    fi
    if [ -d "${SYSCONFIG_DIR}.old/etc/udev/rules.d" ]; then
        mkdir -p "${SYSCONFIG_DIR}/etc/udev/rules.d"
        cp ${SYSCONFIG_DIR}.old/etc/udev/rules.d/* "${SYSCONFIG_DIR}/etc/udev/rules.d/"
    fi
    run "rm -rf \"${SYSCONFIG_DIR}/.git\""
    printf "SYSCONFIG=${SYSCONFIG_DIR}\n" > "/etc/sysconfig.conf"
    chmod 444 "/etc/sysconfig.conf"
    log "Initilizing sysconfig.."
    run "rm /etc/hostname" 2> /dev/null
    run "touch /etc/hostname"
    run "chmod 555 ${SYSCONFIG_DIR}/bin/relink"
    run "chmod 555 ${SYSCONFIG_DIR}/bin/syslink"
    run "bash \"${SYSCONFIG_DIR}/bin/relink\" \"${SYSCONFIG_DIR}\" / " 1> /dev/null
    run "bash \"${SYSCONFIG_DIR}/bin/syslink\"" 1> /dev/null
    run "syslink" 1> /dev/null
    log "Enabling required services.."
    run "systemctl enable sshd.service" 2> /dev/null
    run "systemctl enable fstrim.timer" 2> /dev/null
    run "systemctl enable checkupdates.timer" 2> /dev/null
    run "systemctl enable checkupdates.service" 2> /dev/null
    run "systemctl enable reflector.timer" 2> /dev/null
    run "systemctl enable reflector.service" 2> /dev/null
    run "locale-gen" 1> /dev/null
    log "Finished basic setup.."
}
setup_db() {
    db_root_pw=""
    db_scorebot_pw=""
    db_scorebot_ip=""
    while [ -z "$db_root_pw" ] || [ -z "$db_scorebot_pw" ] || [ -z "$db_scorebot_ip" ]; do
        printf "MySQL root password? "
        read db_root_pw
        printf "MySQL scorebot password? "
        read db_scorebot_pw
        printf "Scorebot API IP Address? "
        read db_scorebot_ip
    done
    log "Scorebot IP is \"$db_scorebot_ip\", this can be changed in the \"/etc/hosts\" file.."
    printf "scorebot-database" > "${SYSCONFIG_DIR}/etc/hostname"
    printf "$db_scorebot_ip\tscorebot-core\n" >> "${SYSCONFIG_DIR}/etc/hosts"
    log "Installing database dependencies.."
    run "pacman -S mariadb --noconfirm --noprogressbar"
    log "Installing inital database.."
    run "mysql_install_db --basedir=/usr --ldata=/var/lib/mysql --user=mysql" 1> /dev/null
    run "systemctl enable mariadb" 2> /dev/null
    run "systemctl start mariadb"
    log "Securing database.."
    run "mysql -u root -e \"DELETE FROM mysql.user WHERE User='';\""
    run "mysql -u root -e \"DELETE FROM mysql.user WHERE User='mysql';\""
    run "mysql -u root -e \"DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');\""
    run "mysql -u root -e \"DROP DATABASE IF EXISTS test;\""
    run "mysql -u root -e \"DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';\""
    run "mysql -u root -e \"FLUSH PRIVILEGES;\""
    run "mysql -u root -e \"CREATE DATABASE scorebot_db;\""
    run "mysql -u root -e \"GRANT ALL ON scorebot_db.* TO 'scorebot'@'scorebot-core' IDENTIFIED BY '$db_scorebot_pw';\""
    run "mysql -u root -e \"UPDATE mysql.global_priv SET priv=json_set(priv, '$.plugin', 'mysql_native_password', '$.authentication_string', PASSWORD('$db_root_pw')) WHERE User='root';\""
    run "systemctl restart mariadb"
    log "Database setup complete, please configure the core component to use the supplied password!"
}
setup_core() {
    core_db_pw=""
    core_db_ip=""
    core_django_pw=""
    while [ -z "$core_db_pw" ] || [ -z "$core_django_pw" ] || [ -z "$core_db_ip "]; do
        printf "Django root password? "
        read core_django_pw
        printf "MySQL scorebot password? "
        read core_db_pw
        printf "MySQL Server IP Address? "
        read core_db_ip
    done
    printf "scorebot-core" > "${SYSCONFIG_DIR}/etc/hostname"
    printf "$proxy_scorcore_db_ipebot_ip\tscorebot-database\n" >> "${SYSCONFIG_DIR}/etc/hosts"
    log "MySQL Server IP is \"$core_db_ip\", this can be changed in the \"/etc/hosts\" file.."
    log "Installing core dependencies.."
    run "pacman -S apache mod_wsgi python python-pip python-virtualenv python-django gcc mariadb-clients python-mysqlclient --noconfirm --noprogressbar"
    run "mkdir -p \"${SCOREBOT_DIR}/versions\""
    log "Building virtual env.."
    run "virtualenv --always-copy \"${SCOREBOT_DIR}/python\"" 1> /dev/null
    run "git clone \"$SCOREBOT_URL\" \"${SCOREBOT_DIR}/version/release\""
    if ! [ -z "$SCOREBOT_BRANCH" ]; then
        run "cd \"${SCOREBOT_DIR}/version/release\"; git checkout $SCOREBOT_BRANCH"
    fi
    run "ln -s \"${SCOREBOT_DIR}/version/release\" \"${SCOREBOT_DIR}/current\"" 1> /dev/null
    log "Installing PIP requirements.."
    run "source \"${SCOREBOT_DIR}/python/bin/activate\"; cd \"${SCOREBOT_DIR}/current\"; unset PIP_USER; pip install -r requirements.txt" 1> /dev/null
    run "sed -ie 's/\"PASSWORD\": \"password\",/\"PASSWORD\": \"$core_db_pw\",/g' \"${SCOREBOT_DIR}/current/scorebot/settings.py\""
    run "rm ${SCOREBOT_DIR}/current/scorebot/*e"
    log "Attempting to push migrations to database server \"$core_db_ip\".."
    run "source \"${SCOREBOT_DIR}/python/bin/activate\"; cd \"${SCOREBOT_DIR}/current\"; env SBE_SQLLITE=0 python manage.py makemigrations scorebot_grid scorebot_core scorebot_game" 1> /dev/null
    run "source \"${SCOREBOT_DIR}/python/bin/activate\"; cd \"${SCOREBOT_DIR}/current\"; env SBE_SQLLITE=0 python manage.py migrate" 1> /dev/null
    run "source \"${SCOREBOT_DIR}/python/bin/activate\"; cd \"${SCOREBOT_DIR}/current\"; env SBE_SQLLITE=0 python manage.py shell -c \"from django.contrib.auth.models import User; User.objects.create_superuser('root', '', '$core_django_pw')\""
    log "Created Django admin account \"root\" with supplied password!"
    run "ln -s \"${SYSCONFIG_DIR}/etc/httpd/conf/roles/core.conf\" \"/etc/httpd/conf/scorebot-role.conf\"" 1> /dev/null
    run "ln -s /usr/lib/python3.*/site-packages/django/contrib/admin/static/admin \"${SCOREBOT_DIR}/current/scorebot_static/admin\"" 1> /dev/null
    run "chown root:http -R \"${SCOREBOT_DIR}\""
    run "chmod 550 -R \"${SCOREBOT_DIR}/currebt\""
    run "mkdir -p \"${SCOREBOT_DIR}/current/scorebot_media\""
    run "chown http:http \"${SCOREBOT_DIR}/current/scorebot_media\""
    run "chmod 775 \"${SCOREBOT_DIR}/current/scorebot_media\""
    run "systemctl enable httpd.service" 2> /dev/null
    run "systemctl enable scorebot.service" 2> /dev/null
    run "systemctl start httpd.service"
    run "systemctl start scorebot.service"
    log "Core setup complete!"
}
setup_proxy() {
    proxy_scorebot_ip=""
    while [ -z "$proxy_scorebot_ip" ]; do
        printf "Scorebot API IP Address? "
        read proxy_scorebot_ip
    done
    printf "scorebot-proxy" > "${SYSCONFIG_DIR}/etc/hostname"
    printf "$proxy_scorebot_ip\tscorebot-core\n" >> "${SYSCONFIG_DIR}/etc/hosts"
    log "Scorebot IP is \"$proxy_scorebot_ip\", this can be changed in the \"/etc/hosts\" file.."
    log "Installing proxy dependencies.."
    run "pacman -S apache --noconfirm --noprogressbar"
    log "Enabling and starting Apache proxy..."
    run "ln -s \"${SYSCONFIG_DIR}/etc/httpd/conf/roles/proxy.conf\" \"/etc/httpd/conf/scorebot-role.conf\"" 1> /dev/null
    run "systemctl enable httpd.service" 2> /dev/null
    run "systemctl start httpd.service"
    log "Proxy setup complete, please ensure to configure the core component!"
}

log "Scorebot Setup v2"
log "iDigitalFlame, The Scorebot Project 2019"

if [ $# -eq 1 ] && [ $1 != "-v" ]; then
    sbe_role=$1
fi
if [ $# -eq 2 ]; then
    if [ $1 != "-v" ]; then
        sbe_role=$1
    fi
    if [ $2 != "-v" ]; then
        sbe_role=$2
    fi
fi

if [ -z "$sbe_role" ]; then
    log "Select the role for this server.."
    printf "[?] Roles:\n\t1: Core\n\t2: DB\n\t3: Proxy\nChoice [1-3]: "
    read sbe_role
fi

case $sbe_role in
    1)
    setup
    setup_core
    ;;
    2)
    setup
    setup_db
    ;;
    3)
    setup
    setup_proxy
    ;;
    *)
    log "Invalid role selected! Please try again..\nGoodbye"
    exit 255
    ;;
esac

log "Finilizing with a syslink.."
run "syslink" 1> /dev/null
log "Done\nHave Fun!"
exit 0
