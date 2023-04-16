#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[s]/}eu${DEBUG+xv}o pipefail

function update_os() {

  ## updating
  export DEBIAN_FRONTEND=noninteractive
  case "$PACKER_BUILDER_TYPE" in
    amazon-*)
      kernel_install="linux-image-cloud-amd64"
      kernel_headers="linux-headers-cloud-amd64"
      ;;
    *)
      kernel_install="linux-image-amd64"
      kernel_headers="linux-headers-amd64"
      ;;
  esac
  # from bento project
  # fix for old problem of not having the right repos
  # echo 'deb http://http.kali.org/kali kali-rolling main contrib non-free' > /etc/apt/sources.list
  # echo 'deb-src http://http.kali.org/kali kali-rolling main contrib non-free' >> /etc/apt/sources.list
  (
    apt-get update --fix-missing
    # from bento project
    apt-get -y upgrade -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confnew' "${kernel_install}"
    apt-get -y install "${kernel_headers}"
    apt-get upgrade -y -o Dpkg::Options::='--force-confnew'
    apt-get dist-upgrade -y -o Dpkg::Options::='--force-confnew'
    apt-get autoremove -y -o Dpkg::Options::='--force-confnew'
  ) | tee -a "${logz}"

}

function main() {

  # establishing a log file variable for the upgrade
  logz='packer-upgrade.log'

  update_os
  reboot

}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then
  main "${@}"
fi
