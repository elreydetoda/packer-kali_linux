#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[s]/}eu${DEBUG+xv}o pipefail

function check_amazon() {

  case "$PACKER_BUILDER_TYPE" in
    amazon-*) exit 0 ;;
  esac

}

function modify_interface() {

  cat << EOF >> /etc/network/interfaces

# this was created to ensure kali will auto start the first interface for vagrant
auto eth0
iface eth0 inet dhcp
EOF

}

function main() {
  check_amazon
  modify_interface
}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" = "${BASH_SOURCE[0]}" ]]; then
  main "${@}"
fi
