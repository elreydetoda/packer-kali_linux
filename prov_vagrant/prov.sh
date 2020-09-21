#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[sc]/}eu${DEBUG+xv}o pipefail

function variables_gen(){
  # shellcheck source=/dev/null
  . "${env_file}"

  if [[ -n "${CIRCLECI}" ]] ; then
    project_dir="${HOME}/project"
  else
    project_dir='/vagrant'
  fi

  path_to_new_kali_shell_script="${project_dir}/scripts/new-kali.sh"
  # installing deps
  echo 'Installing dependencies...'
  
  pushd ${project_dir}
  chmod +x ${path_to_new_kali_shell_script}
  ${path_to_new_kali_shell_script}
}

function general_deps(){
  sudo apt install -y python3-pip
  pip3 install pipenv
  export PATH="${PATH}:~/.local/bin/"
}

function ci_deps(){

  general_deps

  ## for some reason this isn't working...so, going the old fashion way...
  # sudo addgroup --system docker
  # sudo adduser vagrant docker
  # newgrp docker
  # sudo snap install docker circleci
  # sudo snap connect circleci:docker docker
  $new_curl 'https://raw.githubusercontent.com/CircleCI-Public/circleci-cli/master/install.sh' | sudo bash
  $new_curl 'https://get.docker.com' | sudo bash
  sudo usermod -aG docker vagrant
  pushd "${current_project_dir}"
  pipenv install --deploy
  popd

  echo "export CIRCLECI=true" | sudo tee -a "${env_file}" 1>/dev/null
  export CIRCLECI=true
}

## Project setup functions
function circle_ci(){

  ci_deps

  if [[ -d /vagrant ]] ; then
    ln -sf /vagrant/ "${HOME}/project"
  else
    git clone "${project_url}" "${HOME}/project"
  fi
  echo "cd ${HOME}/project" >> "${HOME}/.bashrc"

  variables_gen

  get_secret
}

function development(){

  general_deps
  sudo apt install -y tmux screen
  pushd "${current_project_dir}"
  pipenv install -d --deploy
  pipenv run ansible-galaxy collection install -r ci/ansible-requirements.yml
  pipenv run ansible-galaxy role install -r ci/ansible-requirements.yml
  popd

}

function development_w_CI(){
  ci_deps
  development
}

# thanks to the bash cookbook for this one:
#   https://github.com/vossenjp/bashcookbook-examples/blob/master/ch03/select_dir
function selection(){

  action_array=(
    'done'
    'variables_gen' # this is used to ONLY generate the variables file
    'circle_ci' # this is used to run an imitated environment of what circleci would do
    'development' # normal local development
    'development_w_CI' # development with the CI environment setup
  )

  until [ "${action:-}" == 'done' ] ; do

    PS3='Action to process? '

    printf '\n\n%s\n' "Select an action to do:" >&2

    select action in "${action_array[@]}" ; do

      if [[ "${action}" == "done" ]] ; then

        echo "Finishing automation."
        break

      elif [[ -n "${action}" ]] ; then

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

get_secret(){

  private_key_location="${HOME}/.ssh/id_rsa"

  echo
  echo "What is the private key that you will be using to ssh into the server with? CTRL-d when done."
  private_key_var=$(cat)
  echo "${private_key_var}" > "${private_key_location}"
  chmod 600 "${private_key_location}"

}

cleanup(){
  sed -i 's,/vagrant/prov_vagrant/prov.sh,,' ~vagrant/.bashrc
}

function main(){

  export CIRCLECI="${CIRCLECI:-}"

  project_url='https://github.com/elreydetoda/packer-kali_linux.git'
  env_file='/etc/profile.d/circleci.sh'
  new_curl='curl -fsSL'
  if [[ -n "${CIRCLECI}" ]] ; then
    current_project_dir="${HOME}/project"
  else
    current_project_dir="/home/vagrant/project_folder"
  fi

  sudo apt-get update
  sudo apt-get install -y git

  selection
  cleanup
  exit 0

}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" = "${BASH_SOURCE[0]}" ]] ; then
  main "${@}"
fi
