#!/usr/bin/env bash

# initializing the msf db
msfdb init
# https://blog.secureideas.com/2018/09/automating-red-team-homelabs-part-1-kali-automation.html#comment-265
systemctl enable postgresql.service
