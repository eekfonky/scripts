#!/bin/bash

## NZBGet
install_nzbget () {
sudo mkdir -r /opt/nzbget && sudo chown -R osmc:osmc /opt/nzbget
wget https://nzbget.net/download/nzbget-latest-bin-linux.run -P /tmp
chmod +x /tmp/nzbget-latest-bin-linux.run
sh /tmp/nzbget-latest-bin-linux.run --destdir /opt/nzbget


#sudo systemctl list-units --type=mount
#sudo vim /etc/systemd/system/nzbget.service

[Unit]
Description=NZBGet
After=network.target #mnt-extHD.mount

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
    dpkg -i repo-mediaarea_1.0-9_all.deb && apt-get update

    
}