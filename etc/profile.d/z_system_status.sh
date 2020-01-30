#!/usr/bin/bash
# Copyright (C) 2020 iDigitalFlame
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

_disks() {
    printf "# Disks:\n"
    df -h | grep -v "tmpfs" | grep -E '/dev/|/opt/|/mnt/' | sort -r | awk '{print ""$1" "$5" ("$3"/"$2")"}' | column -t | awk '{print "#     "$0}'
}

_synced() {
    source "/etc/sysconfig.conf" 2> /dev/null
    if [ $? -ne 0 ]; then
        return 0
    fi
    if [ -z "$SYSCONFIG" ]; then
        return 0
    fi
    if ! [ -d "$SYSCONFIG" ]; then
        return 0
    fi
    SYSCONFIG=${SYSCONFIG%/}
    if ! [ -d "${SYSCONFIG}/.git" ]; then
        return 0
    fi
    if ! [[ -z $(bash -c "cd ${SYSCONFIG}; git status | grep -iE 'modified|deleted|Untracked'") ]]; then
        printf '# Config Repo:\tSync needed, use "syspush"\n'
    else
        printf "# Config Repo:\tUp-to-Date\n"
    fi
}

_uptime() {
    ut=$(uptime --pretty | sed 's/up //g')
    printf "# Uptime:\t$ut\n"
    printf "# Kernel:\t$(uname -r)\n"
}

_network() {
    printf "# Network Addresses:\n"
    for addr in $(ifconfig | grep "inet" | grep -v "::1" | grep -v "127.0.0.1" | grep -v "<link>" | awk '{print $2}'); do
        printf "#     $addr\n"
    done
}

_services() {
    sl=$(netstat -panut 2>/dev/null | grep LISTEN | wc -l)
    se=$(netstat -panut 2>/dev/null | grep ESTABLISHED | wc -l)
    st=$(systemctl --all --no-legend --no-pager | grep ".timer" | wc -l)
    sa=$(systemctl --state=active --no-legend --no-pager | grep ".service" | grep "running" | wc -l)
    sf=$(systemctl --state=failed --no-legend --no-pager | grep ".service" | wc -l)
    if [ -f "/var/run/updates.list" ]; then
        ul="$(cat "/var/run/updates.list" | wc -l) Pending"
    else
        if [ $UID -eq 0 ]; then
            systemctl start checkupdates.service
            ul="Checking for updates.."
        else
            ul="Updates check pending.."
        fi
    fi
    printf "# Updates:\t$ul\n"
    printf "# Connections:\t$se Established, $sl Listening\n"
    printf "# Services:\t$sa Running, $sf Failed, $st Timers\n"
}

if [[ $- != *i* ]] || [ ! -z "$SSH_CLIENT" ]; then
    printf "#############################################################################\n"
    _disks
    _network
    _uptime
    _synced
    _services
    printf "#############################################################################\n"
fi
