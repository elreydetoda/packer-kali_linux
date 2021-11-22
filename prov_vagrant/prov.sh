#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[sc]/}eu${DEBUG+xv}o pipefail

function variables_gen() {
  # shellcheck source=/dev/null
  . "${env_file}"

  if [[ -n "${CIRCLECI}" ]]; then
    project_dir="${HOME}/project"
  else
    project_dir='/vagrant'
  fi

  path_to_new_kali_shell_script="${project_dir}/scripts/new-kali.sh"
  # installing deps
  echo 'Installing dependencies...'

  pushd "${project_dir}"
  if [[ -n "${PREZ:-}" ]]; then
    ${path_to_new_kali_shell_script} | grep -v 'vagrant_cloud_token'
  else
    ${path_to_new_kali_shell_script}
  fi
  popd
}

function general_deps() {

  variables_gen
  sudo snap install go --classic
  go get -v github.com/mvdan/sh/cmd/shfmt
  # shellcheck disable=SC2016
  echo 'export PATH="${PATH}:${HOME}/go/bin"' >> ~/.bashrc
  sudo apt-get install -y python3-pip
  pip3 install pipenv
  export PATH="${PATH}:~/.local/bin/"
  pushd "${project_dir}"
  pipenv install --deploy
  pipenv run ansible-galaxy collection install -r ci/ansible-requirements.yml
  pipenv run ansible-galaxy role install -r ci/ansible-requirements.yml
  popd
}

function install_docker() {

  if ! command -v docker; then

    ## for some reason this isn't working...so, going the old fashion way...
    # sudo addgroup --system docker
    # sudo adduser vagrant docker
    # newgrp docker
    # sudo snap install docker circleci
    # sudo snap connect circleci:docker docker
    $new_curl 'https://raw.githubusercontent.com/CircleCI-Public/circleci-cli/master/install.sh' | sudo bash
    $new_curl 'https://get.docker.com' | sudo bash
    sudo usermod -aG docker vagrant

  fi

}
function ci_deps() {

  general_deps
  install_docker
  get_secret

  echo "cd ${HOME}/project" >> "${HOME}/.bashrc"
  echo "export CIRCLECI=true" | sudo tee -a "${env_file}" 1> /dev/null
}

## Project setup functions
function circle_ci() {

  export CIRCLECI=true

  # trying to handle if this script is run outside of a vagrant environment
  # if [[ -d /vagrant ]] && [[ ! -d ~vagrant"/project" ]] ; then
  #   echo "Please uncomment the line below line in the Vagrantfile"
  #   echo '# main.vm.synced_folder ".", "/home/vagrant/project"'
  # elif [[ -d /vagrant ]] && [[ -d ~vagrant"/project" ]] ; then
  #   # do nothing
  #   :
  # else
  #   git clone "${project_url}" "${HOME}/project"
  # fi

  ci_deps
}

function development() {

  if ! command -v pipenv; then
    general_deps
  fi
  sudo apt-get install -y tmux screen
  pushd "${project_dir}"
  pipenv install -d --deploy
  popd

}

function development_w_CI() {
  export CIRCLECI=true
  ci_deps
  development
}

function prez() {
  export PREZ=true
}

# thanks to the bash cookbook for this one:
#   https://github.com/vossenjp/bashcookbook-examples/blob/master/ch03/select_dir
function selection() {

  action_array=(
    'done'
    'variables_gen'    # this is used to ONLY generate the variables file
    'circle_ci'        # this is used to run an imitated environment of what circleci would do
    'development'      # normal local development
    'development_w_CI' # development with the CI environment setup
    'prez'             # for when doing a presentation to not reveal sensative info on recording
  )

  until [ "${action:-}" == 'done' ]; do

    PS3='Action to process? '

    printf '\n\n%s\n' "Select an action to do:" >&2

    select action in "${action_array[@]}"; do

      if [[ "${action}" == "done" ]]; then

        echo "Finishing automation."
        break

      elif [[ -n "${action}" ]]; then

        printf 'You chose number %s, processing %s\n' "${REPLY}" "${action}"
        ${action}
        break

      else

        echo "Invalid selection, please try again."

      fi

    done
  done
  unset PS3

}

get_secret() {

  private_key_location="${HOME}/.ssh/id_rsa"

  echo
  echo "What is the private key that you will be using to ssh into the server with? CTRL-d when done."
  private_key_var=$(cat)
  echo "${private_key_var}" > "${private_key_location}"
  chmod 600 "${private_key_location}"

}

cleanup() {
  sed -i 's,/vagrant/prov_vagrant/prov.sh,,' ~vagrant/.bashrc
}

function main() {

  export CIRCLECI="${CIRCLECI:-}"

  # project_url='https://github.com/elreydetoda/packer-kali_linux.git'
  env_file='/etc/profile.d/circleci.sh'
  new_curl='curl -fsSL'

  sudo apt-get update
  sudo apt-get install -y git

  selection
  cleanup
  exit 0

}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then
  main "${@}"
fi
