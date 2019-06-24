#!/usr/bin/bash

chmod 555 /etc/ssh
chmod 550 /etc/iptables
chmod 440 /etc/iptables/*
chmod 555 -R /etc/systemd
chmod 550 -R /etc/security
chmod 550 -R /etc/pacman.d
chmod 550 -R /etc/sysctl.d
chmod 555 -R /etc/profile.d
chmod 555 -R /etc/syscheck.d
chmod 550 -R /etc/modprobe.d

chown root:root -R /etc/systemd
chown root:root -R /etc/iptables
chown root:root -R /etc/pacman.d
chown root:root -R /etc/security
chown root:root -R /etc/sysctl.d
chown root:root -R /etc/profile.d
chown root:root -R /etc/syscheck.d
chown root:root -R /etc/modprobe.d

find /etc/ssh -type f -exec chmod 400 {} \;
find /etc/systemd -type f -exec chmod 444 {} \;
find /etc/pacman.d -type f -exec chmod 440 {} \;
find /etc/sysctl.d -type f -exec chmod 440 {} \;
find /etc/security -type f -exec chmod 440 {} \;
find /etc/modprobe.d -type f -exec chmod 440 {} \;

chmod 444 /etc/motd
chmod 444 /etc/hosts
chmod 444 /etc/hostname
chmod 444 /etc/locale.gen
chmod 400 /etc/pacman.conf
chmod 400 /etc/vconsole.conf
chmod 444 /etc/sysconfig.conf
chmod 444 /etc/ssh/ssh_config
chmod 400 /etc/mkinitcpio.conf

chown root:root /etc/motd
chown root:root /etc/hosts
chown root:root /etc/hostname
chown root:root /etc/locale.gen
chown root:root /etc/pacman.conf
chown root:root /etc/vconsole.conf
chown root:root /etc/sysconfig.conf
chown root:root /etc/mkinitcpio.conf
