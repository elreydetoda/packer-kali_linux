#!/bin/sh -eux

case "$PACKER_BUILDER_TYPE" in
  amazon-*)
    userz='ec2-user'
  ;;
  *)
    userz='vagrant'
  ;;
esac

# thanks to bento project for this script
# set a default HOME_DIR environment variable if not set
HOME_DIR="${HOME_DIR:-/home/${userz}}";

pubkey_url="https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub";
mkdir -p $HOME_DIR/.ssh;
if command -v wget >/dev/null 2>&1; then
    wget --no-check-certificate "$pubkey_url" -O $HOME_DIR/.ssh/authorized_keys;
elif command -v curl >/dev/null 2>&1; then
    curl --insecure --location "$pubkey_url" > $HOME_DIR/.ssh/authorized_keys;
elif command -v fetch >/dev/null 2>&1; then
    fetch -am -o $HOME_DIR/.ssh/authorized_keys "$pubkey_url";
else
    echo "Cannot download vagrant public key";
    exit 1;
fi
chown -R "${userz}" $HOME_DIR/.ssh;
chmod -R go-rwsx $HOME_DIR/.ssh;
