#!/usr/bin/env bash

set -e

curl="curl -sSL"

get_version(){
  counterz=0
  version_array=()
  case $1 in
    virtualbox)
      version_url='https://download.virtualbox.org/virtualbox/'
      ;;
    packer)
      version_url="${hashicorp_base}/packer/"
      ;;
    vagrant)
      version_url="${hashicorp_base}/vagrant/"
      ;;
  esac
  version_response=$(${curl} ${version_url} | grep -oP '\d+\.\d+\.\d+/' | sort -ru | cut -d '/' -f 1 | head )
  for line in ${version_response}; do
    version_array+=${line}
    printf "%s) %s\n" ${counterz} ${version_array[${counterz}]}
    counterz=$(( ${counterz} + 1 ))
  done

  echo "Please choose a version (default = ${version_array[0]})"
  read SOFTWARE_VERSION

  if [[ -z $SOFTWARE_VERSION ]] ; then
    SOFTWARE_VERSION=${version_array[0]}
  fi
}

checksum(){
  hashAlg='SHA256SUMS'
  hashicorp_base='https://releases.hashicorp.com'
  tmpDir='/tmp/keys'

  case $1 in
    virtualbox)
      # virtualbox doesn't sign package...
      exit 0
      ;;
    packer)
      keyUrl="${hashicorp_base}/${1}"
      ;;
    vagrant)
      keyUrl=""
      ;;
  esac

  mkdir ${tmpDir}

  $curl 
}

get_software(){
  get_version "${1}"
  #checksum "${1}"
}

dependencies(){
  case $(grep "^ID=" /etc/*release | cut -d '=' -f 2 | tr '[:upper:]' '[:lower:]') in
    ubuntu | debian)
      echo "${FUNCNAME[0]} + case"
      packages_array=( "gpgv" "curl" "wget" "jq" "unzip" )
      package_manager='apt-get'
      package_cmds_array=("update")
      package_auto_yes_flag='-y'
      package_install_cmd="install"
      ;;
  esac

  echo hello
  # updating cache and upgrading packages that need to
  for cmd in "${package_cmds_array[@]}" ; do
    if [[ "${cmd}" == 'update' ]] ; then
      sudo ${package_manager} ${cmd}
    else
      sudo ${package_manager} ${cmd} ${package_auto_yes_flag} 
    fi
  done

  # installing deps
  sudo ${package_manager} ${package_install_cmd} ${package_auto_yes_flag} "${packages_array[@]}"
}

main(){
  software_array=( "virtualbox" "packer" "vagrant" )
  echo "${FUNCNAME[0]}"
  dependencies

  # for software in "${software_array[@]}" ; do
  #   get_software ${software}
  # done
}

main
