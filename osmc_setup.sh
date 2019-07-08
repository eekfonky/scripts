#!/bin/bash
sudo mkdir -r /opt/nzbget && sudo chown -R osmc:osmc /opt/nzbget
wget https://nzbget.net/download/nzbget-latest-bin-linux.run -P /tmp
chmod +x /tmp/nzbget-latest-bin-linux.run
sh /tmp/nzbget-latest-bin-linux.run --destdir /opt/nzbget


[Unit]
Description=NZBGet Daemon
Documentation=http://nzbget.net/Documentation
After=network.target

[Service]
User=<replace_with_the_user_you_want>
Group=<replace_with_the_group_you_want>
Type=forking
ExecStart=</path/to/nzbget/nzbget> -D
ExecStop=</path/to/nzbget/nzbget> -Q
ExecReload=</path/to/nzbget/nzbget> -O
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
