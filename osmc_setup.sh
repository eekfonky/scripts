#!/bin/bash

RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

check_sudo () {
    ## Get username & check running as sudo
    USER_ID="$(logname)"
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Please run this using;${NC} \n${BOLD}sudo ./$(basename "$0")${NC}"
        exit
    fi
}

packages_to_install () {
    PKG_NAMES=("git" "mediainfo" "unrar" "openssl" "python3")
    # Run the run_install function if any of the applications are missing
    dpkg -s "${PKG_NAMES[@]}" >/dev/null 2>&1 || sudo apt update && sudo apt install -y "${PKG_NAMES[@]}"
}

check_installed () {
    if sudo systemctl is-active --quiet "$SERVICE"
    then
    echo -e "${RED}$SERVICE is installed, skipping${NC}"
    exit
    fi
}

startup () {
    # Enable Medusa at boot & start
    sudo systemctl enable "$SERVICE"
    sudo systemctl start "$SERVICE"
    if ! sudo systemctl is-active --quiet "$SERVICE"
    then
    echo -e "${RED}Service is not running, please check the logs${NC}"
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
    cat > /etc/systemd/system/$SERVICE.service << EOF
[Unit]
Description=NZBGet
After=network.target

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
    git clone https://github.com/pymedusa/Medusa.git /opt/$SERVICE
    sudo chown -R "$USER_ID":"$USER_ID" /opt/$SERVICE
    
    # Create systemd service
    cat > /etc/systemd/system/$SERVICE.service << EOF
[Unit]
Description=Medusa
After=network.target media-extHD.mount

[Service]
User=$USER_ID
Group=$USER_ID

Type=forking
ExecStart=/usr/bin/python3 /opt/$SERVICE/start.py -q --daemon --nolaunch
TimeoutStopSec=25
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    
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
    sudo apt update && sudo apt install $SERVICE -y
    
    # Create systemd service
    cat > /etc/systemd/system/$SERVICE.service << EOF
[Unit]
Description=Sonarr
After=network.target media-extHD.mount

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
    
    # Call "startup" function to Enable Service at boot
    startup
}

## Radarr
install_radarr () {
    # Variables
    SERVICE="radarr"
    PORT="7878"
    # Installing
    echo -e "${YELLOW}Installing Radarr...${NC}"
    sleep 3
    # Clone Radarr git repo
    sudo mkdir -p /opt/$SERVICE && sudo chown "$USER_ID":"$USER_ID" /opt/$SERVICE
    git clone https://github.com/Radarr/Radarr.git /opt/$SERVICE
    sudo chown -R "$USER_ID":"$USER_ID" /opt/$SERVICE
    
    # Create systemd service
    cat > /etc/systemd/system/$SERVICE.service << EOF
[Unit]
Description=Radarr
After=network.target media-extHD.mount

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
    
    # Call "startup" function to Enable Service at boot
    startup
}

# main menu function
main_menu () {
  clear
  PS3="Select a number: "
  OPTIONS=("Install NZBGet" "Install Sonarr" "Install Radarr" "Install Medusa" "Quit")
  select OPT in "${OPTIONS[@]}"
  do
    case $OPT in
        "Install NZBGet")
            # Call install_nzbget Function
            install_nzbget
            ;;
        "Install Sonarr")
            # Call install_sonarr Function
            install_sonarr
            ;;
        "Install Radarr")
            # Call install_radarr Function
            install_radarr
            ;;
        "Install Medusa")
            # Call install_medusa Function
            install_medusa
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
packages_to_install
main_menu
