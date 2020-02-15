#!/bin/bash

## Variables
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
BOLD='\033[1m'
NC='\033[0m'  # No colour
CL='\033[2K'  # Clear line
UP1='\033[1A' # Move up 1 line
SYSD="/etc/systemd/system/$SERVICE.service"

check_sudo () {
    ## Get username & check running as sudo
    USER_ID="$(logname)"
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Please run this using; \nsudo ./$(basename "$0")${NC}"
        exit
    fi
}

spinner () {
    i=1
    sp='/-\|'
    echo -n ' '
    while [ -d /proc/$PID ]
    do
        printf "\b${sp:i++%${#sp}:1}"
        sleep .25
    done
}

up_to_date () {
    echo -e "${YELLOW}Checking for updates..."
    sudo apt -qqq update && sudo apt -qqq dist-upgrade &
    PID=$!
    # Call "spinner" function
    spinner
    echo -e "${NC}${CL}${UP1}"
}

packages_to_install () {
    echo -e "${YELLOW}Checking for dependencies..."
    PKG_NAMES=("git" "mediainfo" "unrar" "openssl" "python3" "python3-lxml")
    # Run the run_install function if any of the applications are missing
    dpkg -s "${PKG_NAMES[@]}" >/dev/null 2>&1 || sudo apt install -qqq "${PKG_NAMES[@]}"
    PID=$!
    # Call "spinner" function
    spinner
    echo -e "${NC}${CL}${UP1}"
}

check_installed () {
    if sudo systemctl is-active --quiet "$SERVICE"
    then
        echo -e "${RED}$SERVICE is installed, skipping${NC}"
        sleep 3
        main_menu
    fi
}

startup () {
    # Enable Medusa at boot & start
    sudo systemctl enable "$SERVICE"
    sudo systemctl start "$SERVICE"
    if ! sudo systemctl is-active --quiet "$SERVICE"
    then
        echo "${RED}Service is not running, please check the logs${NC}"
        exit
    fi
    # get internal IP & display URL
    INTERNAL=$(hostname -I)
    echo -e "${GREEN}$SERVICE is running on http://$INTERNAL:$PORT${NC}"
}

## NZBGet
install_nzbget () {
    # Variables
    SERVICE="nzbget"
    PORT="6789"
    # Call "check_installed" function
    check_installed
    # Install NZBGet
    echo -e "${YELLOW}Installing NZBGet...${NC}"
    sleep 3
    # Create directory & change permissions
    sudo mkdir -r /opt/$SERVICE
    # Download nzbget latest to /tmp
    wget https://$SERVICE.net/download/$SERVICE-latest-bin-linux.run -P /tmp
    # Make executable
    chmod +x /tmp/$SERVICE-latest-bin-linux.run
    # Launch into /opt/nzbget
    sh /tmp/$SERVICE-latest-bin-linux.run --destdir /opt/$SERVICE
    sudo chown -R "$USER_ID":"$USER_ID" /opt/$SERVICE
    # Create systemd service
    if [ -f "$SYSD" ]; then
        echo -e "${RED}$SERVICE already exists, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
        cat > "$SYSD" << EOF
[Unit]
Description=NZBGet
After=network.target #media-extHD.mount

[Service]
User=$USER_ID
Group=$USER_ID
Type=forking
ExecStart=/opt/$SERVICE/$SERVICE -D
ExecStop=/opt/$SERVICE/$SERVICE -Q
ExecReload=/opt/$SERVICE/$SERVICE -O
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Call "startup" function to Enable NZBGet at boot
    startup
}

## Medusa
install_medusa () {
    # Variables
    SERVICE="medusa"
    PORT="8081"
    # Call "check_installed" function
    check_installed
    # Installing
    echo -e "${YELLOW}Installing Medusa...${NC}"
    sleep 3
    # Clone Medusa git repo
    sudo mkdir -p /opt/$SERVICE && sudo chown "$USER_ID":"$USER_ID" /opt/$SERVICE
    sudo git clone https://github.com/pymedusa/Medusa.git /opt/$SERVICE
    sudo chown -R "$USER_ID":"$USER_ID" /opt/$SERVICE
    
    # Create systemd service
    if [ -f "$SYSD" ]; then
        echo -e "${RED}$SERVICE already exists, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
        cat > "$SYSD" << EOF
[Unit]
Description=Medusa
After=network.target #media-extHD.mount

[Service]
User=$USER_ID
Group=$USER_ID

Type=simple
ExecStart=/usr/bin/python3 /opt/$SERVICE/start.py -q --nolaunch --datadir=/opt/$SERVICE
TimeoutStopSec=25
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Call "startup" function to Enable Service at boot
    startup
}

## Sonarr
install_sonarr () {
    # Variables
    SERVICE="sonarr"
    PORT="8989"
    # Call "check_installed" function
    check_installed
    # Installing
    echo -e "${YELLOW}Installing Sonarr...${NC}"
    sleep 3
    # Install Mono Repo
    sudo apt install apt-transport-https dirmngr gnupg ca-certificates
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
    --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
    echo "deb https://download.mono-project.com/repo/debian stable-stretch main" | \
    sudo tee /etc/apt/sources.list.d/mono-official-stable.list
    
    # Add Sonarr Repo
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
    --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8
    echo "deb https://apt.$SERVICE.tv/debian stretch main" | \
    sudo tee /etc/apt/sources.list.d/$SERVICE.list
    
    # Install Sonarr
    sudo apt -qqq update && sudo apt -qqq install $SERVICE -y &
    PID=$!
    # Call "spinner" function
    spinner
    echo -e "${NC}${CL}${UP1}"
    
    # Create systemd service
    if [ -f "$SYSD" ]; then
        echo -e "${RED}$SERVICE already exists, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
        cat > "$SYSD" << EOF
[Unit]
Description=Sonarr
After=network.target #media-extHD.mount

[Service]
User=$USER_ID
Group=$USER_ID

Type=simple
ExecStart=/usr/bin/mono /opt/$SERVICE/$SERVICE.exe --nobrowser
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

## Radarr
install_radarr () {
    # Variables
    SERVICE="radarr"
    PORT="7878"
    # Call "check_installed" function
    check_installed
    # Installing
    echo -e "${YELLOW}Installing Radarr...${NC}"
    sleep 3
    # Clone Radarr git repo
    sudo mkdir -p /opt/$SERVICE && sudo chown "$USER_ID":"$USER_ID" /opt/$SERVICE
    sudo git clone https://github.com/Radarr/Radarr.git /opt/$SERVICE
    sudo chown -R "$USER_ID":"$USER_ID" /opt/$SERVICE
    
    # Create systemd service
    if [ -f "$SYSD" ]; then
        echo -e "${RED}$SERVICE already exists, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
        cat > "$SYSD" << EOF
[Unit]
Description=Radarr
After=network.target #media-extHD.mount

[Service]
User=$USER_ID
Group=$USER_ID

Type=simple
ExecStart=/usr/bin/mono /opt/$SERVICE/$SERVICE.exe --nobrowser
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
    OPTIONS=("NZBGet" "Medusa" "Radarr" "Sonarr" "Quit")
    select OPT in "${OPTIONS[@]}"
    do
        case $OPT in
            "NZBGet")
                install_nzbget
            ;;
            "Medusa")
                install_medusa
            ;;
            "Radarr")
                install_radarr
            ;;
            "Sonarr")
                install_sonarr
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
main_menu
