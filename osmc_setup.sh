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
        echo -e "Please run this using; \nsudo ./$(basename "$0")"
        exit
    fi
}

up_to_date () {
    sudo apt update && apt dist-upgrade -y
    clear
}

packages_to_install () {
    PKG_NAMES=("git" "mediainfo")
    # Run the run_install function if any of the applications are missing
    dpkg -s "${PKG_NAMES[@]}" >/dev/null 2>&1 || sudo apt install -y ${PKG_NAMES[@]}
}

## NZBGet
install_nzbget () {
    echo -e "${YELLOW}Installing NZBGet...${NC}"
    sleep 3
    # Create directory & change permissions
    sudo mkdir -r /opt/nzbget && chown -R $USER_ID:$USER_ID /opt/nzbget 
    # Download nzbget latest to /tmp
    wget https://nzbget.net/download/nzbget-latest-bin-linux.run -P /tmp
    # Make executable
    chmod +x /tmp/nzbget-latest-bin-linux.run
    # Launch into /opt/nzbget
    sh /tmp/nzbget-latest-bin-linux.run --destdir /opt/nzbget
    sudo chown -R $USER_ID:$USER_ID /opt/nzbget
    # Create systemd service
    sudo cat > /etc/systemd/system/nzbget.service << EOF
[Unit]
Description=NZBGet
After=network.target

[Service]
User=$USER_ID
Group=$USER_ID
Type=forking
ExecStart=/opt/nzbget/nzbget -D
ExecStop=/opt/nzbget/nzbget -Q
ExecReload=/opt/nzbget/nzbget -O
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable NZBGet at boot & start
sudo systemctl enable nzbget
sudo systemctl start nzbget
if ! sudo systemctl is-active --quiet nzbget
then
echo "${RED}Service is not running, please check the logs${NC}"
exit
fi

# get internal IP & display URL
INTERNAL=$(hostname -I)
echo "NZBGet is running on http://""$INTERNAL"":6789"
}

## Sonarr
install_sonarr () {
    # Install Mono Repo
    sudo apt install apt-transport-https dirmngr gnupg ca-certificates mediainfo
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
    --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
    echo "deb https://download.mono-project.com/repo/debian stable-stretch main" | \
    sudo tee /etc/apt/sources.list.d/mono-official-stable.list

    # Add Sonarr Repo
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
    --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8
    echo "deb https://apt.sonarr.tv/debian stretch main" | \
    sudo tee /etc/apt/sources.list.d/sonarr.list

    # Install Sonarr
    sudo apt update && sudo apt install sonarr -y
    }

# main menu function
main_menu () {
  clear
  PS3="Select a number: "
    if [ -d "$HOME_DIR" ]
    then
    mapfile -t USERNAME < <(find "$HOME_DIR" -mindepth 1 -maxdepth 1 -type d | sed 's!.*/!!' | sort)
    # Get basename for users;
    string="@(${USERNAME[0]}"
    for((i=1;i<${#USERNAME[@]};i++))
    do
      string+="|${USERNAME[$i]}"
    done
    string+=")"
    select NAME in "Clear ALL Users" "${USERNAME[@]}" "Quit"
    do
        case $NAME in
        "Clear ALL Users")
            # Call clear_cache_all Function
            clear_cache_all
            exit
            ;;
        $string)
            # Call clear_cache_user Function
            clear_cache_user
            ;;
        "Quit")
            exit
            ;;
            *)
            echo "Invalid option, please try again";;
        esac
    done
    else
      echo -e "${RED}Error: Cannot find home directories...exiting${NC}"
    fi
}

## SCRIPT COMMANDS ##
check_sudo
up_to_date
packages_to_install
main_menu
