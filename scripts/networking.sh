#!/bin/bash

cat <<EOF >>/etc/network/interfaces

# this was created to ensure kali will auto start the first interface for vagrant
auto eth0
iface eth0 inet dhcp
EOF
