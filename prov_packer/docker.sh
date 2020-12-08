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

  # getting docker
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
  echo 'deb https://download.docker.com/linux/debian stretch stable' > /etc/apt/sources.list.d/docker.list
  # for outdated kali's
  # apt-get update
  # apt-key adv --keyserver hkp://keys.gnupg.net --recv-keys 7D8D0BF6
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

function main() {
  get_current_user
  add_docker_repo
  add_docker
  docker_group
}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" = "${BASH_SOURCE[0]:-}" ]]; then
  main "${@}"
fi
