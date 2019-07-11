#!/bin/bash

## NZBGet
install_nzbget () {
    # Create directory & change permissions
    sudo mkdir -r /opt/nzbget && sudo chown -R osmc:osmc /opt/nzbget
    # Download nzbget latest to /tmp
    wget https://nzbget.net/download/nzbget-latest-bin-linux.run -P /tmp
    # Make executable
    chmod +x /tmp/nzbget-latest-bin-linux.run
    # Launch into /opt/nzbget
    sh /tmp/nzbget-latest-bin-linux.run --destdir /opt/nzbget

[Unit]
Description=NZBGet
After=network.target

[Service]
User=osmc
Group=osmc
Type=forking
ExecStart=/opt/nzbget/nzbget -D
ExecStop=/opt/nzbget/nzbget -Q
ExecReload=/opt/nzbget/nzbget -O
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target

sudo systemctl enable nzbget
sudo systemctl start nzbget
sudo systemctl status nzbget
}

## Sonarr
install_sonarr () {
    # Install Mono Repo
    sudo apt install apt-transport-https dirmngr gnupg ca-certificates
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
--recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
echo "deb https://download.mono-project.com/repo/debian stable-stretch main" | \
sudo tee /etc/apt/sources.list.d/mono-official-stable.list
sudo apt update

# Install mediaInfo Repo
wget https://mediaarea.net/repo/deb/repo-mediaarea_1.0-9_all.deb && \
sudo dpkg -i repo-mediaarea_1.0-9_all.deb && apt-get update

# Add Sonarr Repo
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
--recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8
echo "deb https://apt.sonarr.tv/debian stretch main" | \
sudo tee /etc/apt/sources.list.d/sonarr.list
sudo apt update

# Install Sonarr
sudo apt install sonarr
}