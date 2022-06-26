#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[s]/}eu${DEBUG+xv}o pipefail

function get_current_user() {

  case "${PACKER_BUILDER_TYPE:-}" in
    amazon-*)
      userz='kali'
      ;;
    *)
      userz='vagrant'
      ;;
  esac

}

function add_docker_repo() {

  # https://github.com/elreydetoda/all-linux-tings/blob/c8642bbbd0232a9272b01711bea7e11c15a494bf/scripts/finished/hashicorp_repos-kali.sh#L8
  debian_version="$(curl -fsSL 'https://www.debian.org/releases/stable/' | grep 'Release Information' | grep '<h1>' | grep -oP ';.*&' | tr -d ';|&')"
  # updating based on kali docs PR:
  # https://gitlab.com/kalilinux/documentation/kali-docs/-/merge_requests/115
  curl -fsSL https://download.docker.com/linux/debian/gpg |
    sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-ce-archive-keyring.gpg
  apt-add-repository -u "deb https://download.docker.com/linux/debian ${debian_version} stable"
  apt-get update

}

function add_docker() {

  # be careful this will remove your current docker
  apt-get remove docker docker-engine docker.io -y
  apt-get install docker-ce -y

}

function docker_group() {

  # adding user to docker group
  usermod -aG docker "${userz}"

}

function deps() {
  apt-get install -y curl gnupg software-properties-common
}
function main() {
  deps
  get_current_user
  add_docker_repo
  add_docker
  docker_group
}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" == "${BASH_SOURCE[0]:-bash}" ]]; then
  main "${@}"
fi
