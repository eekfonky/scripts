#!/bin/bash

## Variables
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m'  # No colour
VERSION="$(lsb_release -cs)"

check_sudo () {
    ## Get username & check running as sudo
    USER_ID="$(logname)"
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Please run this using; \nsudo ./$(basename "$0")${NC}"
        exit
    fi
}

up_to_date () {
    echo -e "${YELLOW}Checking sources..."
    sudo add-apt-repository main && \
    sudo add-apt-repository restricted && \
    sudo add-apt-repository multiverse && \
    sudo add-apt-repository universe
}

mount_hdd_fstab () {
    sudo mkdir -p /mnt/extHD
    sudo chown "$USER_ID":"$USER_ID" /mnt/extHD
    cat >> /etc/fstab << EOF
# ExtHD
UUID=f3224a20-0cab-4fea-9670-45e42a9550b6  /mnt/extHD  ext4   defaults  0      0
EOF
}

packages_to_install () {
    echo -e "${YELLOW}Checking for dependencies..."
    PKG_NAMES=("git" "unrar" "unzip" "curl" "mediainfo" "sqlite3" "debconf-utils")
    # Add MediaInfo Repo
    wget https://mediaarea.net/repo/deb/repo-mediaarea_1.0-12_all.deb && \
    sudo dpkg -i repo-mediaarea_1.0-12_all.deb
    # Run the run_install function if any of the applications are missing
    dpkg -s "${PKG_NAMES[@]}" >/dev/null 2>&1 || ( sudo apt install -qqq "${PKG_NAMES[@]}" -y )
}

check_installed () {
    if sudo systemctl is-active --quiet "$SERVICE"
    then
        echo -e "${RED}${SERVICE} is installed, skipping${NC}"
        sleep 3
        main_menu
    fi
}

startup () {
    # Enable $SERVICE at boot & start
    sudo systemctl enable "$SERVICE"
    sudo systemctl start "$SERVICE"
    if ! sudo systemctl is-active --quiet "$SERVICE"
    then
        echo "${RED}${SERVICE} is not running, please check the logs${NC}"
        exit
    fi
    # get internal IP & display URL
    echo -e "${GREEN}$SERVICE is running${NC}"
}

## NZBGet
install_nzbget () {
    # Variables
    SERVICE="nzbget"
    SYSD="/lib/systemd/system/$SERVICE.service"
    # Call "check_installed" function
    check_installed
    # Install NZBGet
    echo -e "${YELLOW}Installing NZBGet...${NC}"
    sleep 3
    sudo apt -qq install -y nzbget
    EXEPATH=$(which nzbget)
    # Create systemd service
    if [ -f "$SYSD" ]; then
        echo -e "${RED}$SERVICE already exists, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
        cat > "$SYSD" << EOF
[Unit]
Description=NZBGet
After=network.target mnt-extHD.mount

[Service]
User=$USER_ID
Group=$USER_ID
Type=forking
ExecStart=$EXEPATH -D
ExecStop=$EXEPATH -Q
ExecReload=$EXEPATH -O
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    fi
    # Change Control IP to allow access to WebGUI
    sudo sed -i.bak 's|ControlIP=127.0.0.1|ControlIP=0.0.0.0|g' /etc/nzbget.conf
    # Change permissons on nzbget.conf file
    sudo chmod 666 /etc/nzbget.conf
    # Call "startup" function to enable service at boot
    startup
}

## Plex Media Server
install_plex () {
    sudo snap install plexmediaserver
}

## Transmission
install_transmission () {
    # Variables
    SERVICE="transmission"
    SYSD="/lib/systemd/system/$SERVICE-daemon.service"
    # Call "check_installed" function
    check_installed
    # Install Transmission
    echo -e "${YELLOW}Installing Transmission...${NC}"
    sleep 3
    sudo apt -qq install -y transmission-daemon
    EXEPATH=$(which transmission-daemon)
    sudo systemctl stop transmission-daemon
    # Create systemd service
    if [ -f "$SYSD" ]; then
        echo -e "${RED}${SERVICE} already exists, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
     cat > "$SYSD" << EOF
[Unit]
Description=Transmission BitTorrent Daemon
After=network.target mnt-extHD.mount

[Service]
User=$USER_ID
Group=$USER_ID
Type=notify
ExecStart=$EXEPATH -f --log-error --allowed *.*.*.*
ExecStop=/bin/kill -s STOP $MAINPID
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    fi
    sudo systemctl daemon-reload
    # Call "startup" function to Enable NZBGet at boot
    startup
}

## Sonarr
install_sonarr () {
    # Variables
    SERVICE="sonarr"
    SYSD="/lib/systemd/system/$SERVICE.service"
    # Call "check_installed" function
    check_installed
    # Installing
    echo -e "${YELLOW}Installing Sonarr...${NC}"
    sleep 3

    # Add Mono Repo
    sudo apt -qq install -y gnupg ca-certificates
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
    echo "deb https://download.mono-project.com/repo/ubuntu stable-$VERSION main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
    
    # Add Sonarr Repo
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8
    echo "deb https://apt.sonarr.tv/ubuntu $VERSION main" | sudo tee /etc/apt/sources.list.d/sonarr.list
    
    # Install Sonarr
    sudo DEBIAN_FRONTEND=noninteractive apt install $SERVICE -y

    # Change Users and Group
cat << EOF | sudo debconf-set-selections
sonarr  sonarr/owning_user      string  $USER_ID
sonarr  sonarr/owning_group     string  $USER_ID                                                                                                                                                             
sonarr  sonarr/owning_umask     string  0002
sonarr  sonarr/config_directory string  /var/lib/sonarr
EOF
    # Reconfigure Sonarr
    sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure $SERVICE
    
    # Create systemd service
    cat > "$SYSD" << EOF
[Unit]
Description=Sonarr Daemon
After=network.target mnt-extHD.mount

[Service]
User=$USER_ID
Group=$USER_ID
UMask=0002

Type=simple
ExecStart=/usr/bin/mono --debug /usr/lib/sonarr/bin/Sonarr.exe -nobrowser -data=/var/lib/sonarr
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # reload systemctl service
    sudo systemctl daemon-reload
}

## Radarr
install_radarr () {
    # Variables
    SERVICE="radarr"
    SYSD="/etc/systemd/system/$SERVICE.service"
    # Call "check_installed" function
    check_installed
    # Installing
    echo -e "${YELLOW}Installing Radarr...${NC}"
    sleep 3
        
    # Add MediaInfo Repo
    wget https://mediaarea.net/repo/deb/repo-mediaarea_1.0-12_all.deb && \
    sudo dpkg -i repo-mediaarea_1.0-12_all.deb

    # Clone Radarr git repo
    wget --content-disposition 'http://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64'
    # Move to /opt and set permissions
    tar -xvzf Radarr*.linux*.tar.gz
    sudo mv Radarr /opt
    sudo chown -R "$USER_ID":"$USER_ID" /opt/Radarr
    
    # Create systemd service
    if [ -f "$SYSD" ]; then
        echo -e "${RED}${SERVICE} already exists, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
        cat > "$SYSD" << EOF
[Unit]
Description=Radarr
After=network.target mnt-extHD.mount

[Service]
User=$USER_ID
Group=$USER_ID

Type=simple
ExecStart=/opt/Radarr/Radarr -nobrowser -data=/home/$USER_ID/.config/Radarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    fi
    # Call "startup" function to Enable Service at boot
    startup
}

# main menu function
main_menu () {
    clear
    PS3="Select a number to install application: "
    OPTIONS=("NZBGet" "Transmission" "Radarr" "Sonarr" "Plex" "Quit")
    select OPT in "${OPTIONS[@]}"
    do
        case $OPT in
            "NZBGet")
                install_nzbget
            ;;
            "Transmission")
                install_transmission
            ;;
            "Radarr")
                install_radarr
            ;;
            "Sonarr")
                install_sonarr
            ;;
            "Plex")
                install_plex
            ;;
            "Quit")
                break
            ;;
            *)
            echo -e "${RED}Invalid option, please try again${NC}";;
        esac
    done
}

## SCRIPT COMMANDS ##
check_sudo
up_to_date
packages_to_install
mount_hdd_fstab
main_menu
