#!/bin/bash

# Written by welshch@
# Mount DFS and/or Active Directory home directory on Ubuntu

set -eu -o pipefail

# Colours
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # No Colour

# Get User Details
USERNAME="$(logname)"

check_sudo () {
    if [ "$EUID" -ne 0 ]
    then
        echo -e "${YELLOW}Sudo permissions required, please run this using;${NC}\nsudo ./$(basename "$0")"
        exit
    fi
}

amend_files () {
    # Add 'wins' option to /etc/nsswitch.conf
    sed -i.bak 's/^\(hosts:  *files\) \(mdns4_minimal\)/\1 wins \2/' /etc/nsswitch.conf
    # Replace '-c' flag with '-t' in /etc/request-key.conf
    sed -Ei.bak 's/^(create\s+cifs\.spnego.*cifs.upcall\s+)-c/\1-t/' /etc/request-key.conf
    # Add '-t' flag to /etc/request-key.d/cifs.spnego.conf
    sed -i.bak 's|create  cifs.spnego    \* \* /usr/sbin/cifs.upcall %k|create  cifs.spnego    \* \* /usr/sbin/cifs.upcall -t %k|g' \
    /etc/request-key.d/cifs.spnego.conf
}

packages_to_install () {
    # Add packages required to array
    PKG_NAMES=("cifs-utils" "keyutils")
    # Run the run_install function if any of the applications are missing
    dpkg -s "${PKG_NAMES[@]}" >/dev/null 2>&1 || ( sudo apt -qq update && sudo apt -qq install --install-suggests -y "${PKG_NAMES[@]}" && amend_files )# <--calling function above
}

create_home_mount () {
    # Create mountpoint
    DFS_NAME="homeDrive"
    DFS_MOUNT="$HOME/$DFS_NAME"
    sudo -u "$USERNAME" mkdir -p "$DFS_MOUNT"
    # Get filepath
    FILEPATH="$(/usr/bin/ldapsearch -Y GSSAPI -Q -H ldap:///dc%3Dant%2Cdc%3Damazon%2Cdc%3Dcom -b \
    DC=ant,DC=amazon,DC=com -s sub cn="$USERNAME" homeDirectory | sed -n -e 's/^homeDirectory: //' -e 's/\\/\//gp')"
    # Check if home folder exists in fstab
    if grep -Fq "$FILEPATH" /etc/fstab
    then
        echo -e "${YELLOW}$FILEPATH already exists in fstab, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
        cp /etc/fstab /etc/fstab.bak
        cat >> /etc/fstab << EOF
#
# Active Directory Home Folder
$FILEPATH    $DFS_MOUNT    cifs    cruid=$USERNAME,sec=krb5,noauto,users,noserverino,vers=2.1,rw    0   0
EOF
    fi
}

create_DFS_share () {
    ## Get DFS filepath
    echo -e "${YELLOW}What is the DFS file path of the directory? (include all backslashes \)${NC}"
    read -r -p "> " FILEPATH
    # Replace backslashes with forward slashes
    FILEPATH=${FILEPATH//\\//}
    # Check for Whitespace
    WHITESPACE=" "
    if [[ $FILEPATH =~ $WHITESPACE ]]
    then
        # Replace whitespace with \040 for fstab compliance
        FILEPATH=${FILEPATH// /\\040}
    fi
    # Check fstab for duplicates
    if grep -Fq "$FILEPATH" /etc/fstab
    then
        echo -e "${RED}$FILEPATH already exists in fstab, exiting back to menu...${NC}"
        sleep 3
        main_menu
    fi
    
    ## Name mount point
    echo -e "${YELLOW}What name you wish to call the mount?${NC}"
    read -r -p "> " DFS_MOUNT
    DFS_NAME="$DFS_MOUNT"
    # Check for Whitespace
    if [[ $DFS_MOUNT =~ $WHITESPACE ]]
    then
        DFS_MOUNT=${DFS_MOUNT// /_}
        echo -e "${RED}Whitespace is a bad idea for mountpoints, I am replacing it with underscores!${NC}"
        echo -e "${GREEN}$DFS_MOUNT${NC}"
    fi
    # Check fstab for duplicates
    if grep -Fq "$DFS_MOUNT" /etc/fstab
    then
        echo -e "${RED}$DFS_MOUNT already exists in fstab, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
        # Create directory in $HOME
        DFS_MOUNT="$HOME/$DFS_MOUNT"
        sudo -u "$USERNAME" mkdir -p "$DFS_MOUNT"
        # Backup fstab
        cp /etc/fstab /etc/fstab.bak
        # Add to fstab
        cat >> /etc/fstab << EOF
#
# DFS File Share
$FILEPATH    $DFS_MOUNT    cifs    cruid=$USERNAME,sec=krb5,noauto,users,noserverino,vers=2.1,rw    0   0
EOF
    fi
}

check_mount () {
    if ( sudo -u "$USERNAME" mount "$DFS_MOUNT" )
    then
        echo -e "${GREEN}$DFS_MOUNT is mounted${NC}"
        sleep 3
    else
        echo -e "${RED}$DFS_MOUNT is not mounted, check your filepath and permissions, restoring fstab${NC}"
        mv /etc/fstab.bak /etc/fstab
        sleep 3
        main_menu
    fi
}

create_autostart () {
    # add autostart file to $HOME to allow mounting after logging in
    if [ ! -f "$HOME/.config/autostart/dfs-mount-$DFS_NAME.desktop" ]; then
   cat >> "$HOME/.config/autostart/dfs-mount-$DFS_NAME".desktop << EOF
[Desktop Entry]
Type=Application
Name=Mount $DFS_NAME
Comment=Mount $DFS_NAME
Exec=mount $DFS_MOUNT
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
EOF
        # Change permission to match $HOME
        chown --reference="$HOME" "$HOME/.config/autostart/dfs-mount-$DFS_NAME".desktop
    else
        echo -e "${RED}$DFS_MOUNT already exists in autostart, exiting back to menu...${NC}"
        sleep 3
        main_menu
    fi
}

mount_on_vpn () {
    # If zz-mount-dfs doesn't exist, create it
    if [ ! -f "/etc/NetworkManager/dispatcher.d/zz-mount-dfs" ]; then
    cat >> /etc/NetworkManager/dispatcher.d/zz-mount-dfs << EOF
#!/bin/bash

# Kerberos Ticket
KRB_TICKET="\$(ls /tmp/krb5cc_"\$(id -ru $USERNAME)"_*)"
export KRB5CCNAME="\$KRB_TICKET"

INTERFACE="\$1"
STATUS="\$2"

if [ "\$STATUS" = "up" ]; then
        if [ "\$INTERFACE" = "vpn0" ] || [ "\$INTERFACE" = "cscotun0" ]; then
		# Add Rules Below
		sudo -u $USERNAME mount $DFS_MOUNT
        fi
fi
EOF
        # If zz-mount-dfs does exist, append mount point to "Add Rules Below"
    elif grep -Fq "sudo -u $USERNAME mount $DFS_MOUNT" /etc/NetworkManager/dispatcher.d/zz-mount-dfs
    then
        echo -e "${RED}$DFS_MOUNT already exists in dispatcher script for VPN, exiting back to menu...${NC}"
        sleep 3
        main_menu
    else
        # Backup zz-mount-dfs
        cp /etc/NetworkManager/dispatcher.d/zz-mount-dfs /etc/NetworkManager/dispatcher.d/zz-mount-dfs.bak
        # Add to zz-mount-dfs
        sed -i "/# Add Rules Below/a\\\t\tsudo -u $USERNAME mount $DFS_MOUNT" /etc/NetworkManager/dispatcher.d/zz-mount-dfs
    fi
}

main_menu () {
    clear
    PS3='Please enter your choice: '
    OPTIONS=("Mount DFS Share" "Mount AD Home Folder" "Quit")
    select OPT in "${OPTIONS[@]}"
    do
        case $OPT in
            "Mount DFS Share")
                create_DFS_share
                check_mount
                create_autostart
                mount_on_vpn
                break
            ;;
            "Mount AD Home Folder")
                create_home_mount
                check_mount
                create_autostart
                mount_on_vpn
                break
            ;;
            "Quit")
                exit
            ;;
            *) echo -e "${RED}Invalid Option: $REPLY${NC}, Please try again";;
        esac
    done
}

### SCRIPT COMMANDS ###
check_sudo
packages_to_install
main_menu