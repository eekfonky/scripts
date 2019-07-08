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