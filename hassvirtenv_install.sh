#!/bin/bash

##### hassvirtenv_install.sh 
### originally written by Will Heid (bassclarinetl2)
### last updated 2017-11-01 


error() {
  printf '\E[31m'; echo "$@"; printf '\E[0m'
}

initil(){
## check if running with root permissions
if [[ $EUID -ne 0 ]]; then
    error "This script should be run using sudo or as the root user"
    exit 1
fi

## install dialog (needed for fancy menu)
apt install -y dialog

release_file="/etc/os-release"

##get os-release if exists
if [[ ! -e "${release_file}" ]]; then
        error "Error, cannot see my OS info in ${release_file}" 
        exit -1
    else
        source /etc/os-release
fi
}

##install python3-pip and the dev package (sorry, no non-debian love yet)
install_base_packages(){
    case "${ID}" in
        rhel|fedora)
            error "I'm not able to handle non-debian based distros's at the moment"
            ;;
        debian)
            apt update
            apt upgrade
            apt install python3-pip python3-dev
            pip3 install --upgrade virtualenv
            ;; 
esac
}

add_system_user(){
    if grep -q 'homeassistant:' /etc/passwd; then echo "homeassistant user already exists"; else adduser --system homeassistant fi;
    if grep -q 'homeassistant:' /etc/group; then echo "homeassistant group already exists"; else addgroup homeassistant fi;
}

grant_zwave_perm(){
    usermod -G dialout -a homeassistant
}

create_hass_dir(){

    if [[ ! -d /srv/homeassistant ]]; then 
        mkdir -p /srv/homeassistant
        chown homeassistant:homeassistant /srv/homeassistant
    fi
}

create_venv(){
    su -c 'virtualenv -p python3 /srv/homeassistant' homeassistant
    su -c 'source /srv/homeassistant/bin/activate' homeassistant
    su -c 'pip3 install --upgrade homeassistant' homeassistant
}

create_autostart(){
    AUTOSTARTER="$(ps -p 1 -o comm=)"

    if [[ $AUTOSTARTER -ne "systemd" ]]; then
        error "Looks like you're using init. I can't handle that yet"
    else
        cat > /etc/systemd/system.home-assistant.service<<EOL
[Unit]
Description=Home Assistant
After=network.target

[Service]
Type=simple
User=%i
ExecStart=/srv/homeassistant/bin/hass -c "/home/homeassistant/.homeassistant"

[Install]
WantedBy=multi-user.target
EOL

    systemctl --system daemon-reload
    systemctl enable home-assistant
    fi
}

create_sftp_user(){
    useradd sftpedit mynewuser -G homeassistant
    chpasswd << 'END'
mynewuser:sftpedit123
END
}

alldone(){
        echo "All Done"
        echo -e '\a'
        menu_disp
}

menu_disp(){
HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=4
BACKTITLE="Home Assistant Venv Install Script Thingy"
TITLE="Version .7"
MENU="Waddya want to do?"

OPTIONS=(1 "Install the whole thing"
         2 "Install base packages"
         3 "Add system user"
         4 "Grant ZWave permissions"
         5 "Create homeassistant directory"
         6 "Create the Virtual Env"
         7 "Create autostart script"
         8 "Create sftp user"
         0 "Exit")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
    1) ##install the whole thing
        install_base_packages
        add_system_user
        grant_zwave_perm
        create_hass_dir
        create_venv
        create_autostart
        create_sftp_user
        alldone
        ;;
    2) #only base packages
        install_base_packages
        alldone
        ;;
    3) #add system user
        add_system_user
        alldone
        ;;
    4) #only zwave permissions
        grant_zwave_perm
        alldone
        ;;
    5) #homeasst dir
        create_hass_dir
        alldone
        ;;
    6) #just the virt env
        create_venv
        alldone
        ;;
    7) #just the autostart
        create_autostart
        alldone
        ;;
    8) #just the sftp user
        create_sftp_user
        alldone
        ;;
    0) #exit
        exit 1
        ;;
esac
}

##run the functions

initil
menu_disp


