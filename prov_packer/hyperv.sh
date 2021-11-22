#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[sc]/}eu${DEBUG:+xv}o pipefail

# inspired by:
# - prov_packer/bento/packer_templates/ubuntu/scripts/hyperv.sh
# - https://gitlab.com/kalilinux/packages/kali-tweaks/-/blob/9436ff1d6f201b638e7dd9ac908c6470fa1b9062/helpers/hyperv-enhanced-mode

function configure_xrdp(){
  sed -i                                                      \
    -e 's|^ *port=3389|port=vsock://-1:3389|'                 \
    -e 's|^ *security_layer=.*|security_layer=rdp|'           \
    -e 's|^ *crypt_level=.*|crypt_level=none|'                \
    -e 's|^ *bitmap_compression=.*|bitmap_compression=false|' \
    "${xrdp_base}/xrdp.ini"

  sed -i                                                    \
    -e 's|^ *X11DisplayOffset=.*|X11DisplayOffset=0|'       \
    -e 's|^ *FuseMountName=.*|FuseMountName=shared-drives|' \
    "${xrdp_base}/sesman.ini"
}

function configure_polkit(){
  cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla << 'EOF'
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
}

function load_hv_s_module(){
  echo "hv_sock" > /etc/modules-load.d/hv_sock.conf
  systemctl restart systemd-modules-load.service
}

function backup_changed_files(){
  for modified_file in "${modified_files[@]}" ; do
    cp -v "${modified_file}"{,.orig}
  done
}

function deps(){
  logz='packer-upgrade.log'
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${deps[@]}" | tee -a $logz
}

function startup_service(){
  systemctl enable --now "${services[@]}"
}

function main(){

  deps=(
    'xrdp'
    # should already be installed, but just in case
    'hyperv-daemons'
  )
  xrdp_base='/etc/xrdp'
  modified_files=(
    "${xrdp_base}/xrdp.ini"
    "${xrdp_base}/sesman.ini"
  )
  services=(
    'xrdp'
  )

  case "$PACKER_BUILDER_TYPE" in
    hyperv-iso)
      deps
      backup_changed_files
      configure_xrdp
      configure_polkit
      load_hv_s_module
    ;;
  esac
}

# https://elrey.casa/bash/scripting/main
if [[ "${0}" = "${BASH_SOURCE[0]:-bash}" ]] ; then
  main "${@}"
fi