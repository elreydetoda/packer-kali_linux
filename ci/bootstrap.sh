#!/usr/bin/env bash

set -e

curl="curl -sSL"

get_version(){
  echo ${FUNCNAME[0]}
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
    version_array+=(${line})
    if [[ ! ${CIRCLECI} ]] ; then
      printf "%s) %s\n" ${counterz} ${version_array[${counterz}]}
    fi
    counterz=$(( ${counterz} + 1 ))
  done

  if [[ ! $CIRCLECI ]] ; then

    echo "Please choose a version (default = ${version_array[1]})"
    read SOFTWARE_VERSION

    if [[ -z $SOFTWARE_VERSION ]] ; then
      SOFTWARE_VERSION=${version_array[1]}
    fi
  else

    SOFTWARE_VERSION=${version_array[1]}
  fi

  eval "${1}_SOFTWARE_VERSION=${SOFTWARE_VERSION}"
  export "${1}_SOFTWARE_VERSION"
}

checksum(){
  echo ${FUNCNAME[0]}
  tmpDir='/tmp/keys'
  hashAlg='SHA256SUMS'
  case $1 in
    virtualbox)
      hashUrl="${software_base_url}/${hashAlg}"
      ;;
    packer | vagrant)
      hashUrl="${software_base_url}/${1}_${!SOFT_VERSION}_${hashAlg}"
      ;;
  esac

  mkdir -p ${tmpDir}
  hash_file_path="${tmpDir}/${hashAlg}"

  $curl ${hashUrl} -o ${hash_file_path}

  should_be_hash=$(grep -i ${file_name} ${hash_file_path} | cut -d ' ' -f 1)
  current_hash=$($(echo ${hashAlg} | tr '[:upper:]' '[:lower:]' | cut -d 's' -f 1-3) ${file_path} | cut -d ' ' -f 1)

  if [[ ! $1 == "virtualbox" ]] ; then

    $curl ${hashiKeyUrl} | gpg --import -- &>/dev/null

    $curl "${hashUrl}.sig" -o "${tmpDir}/${hashAlg}.sig"

    echo
    echo "checking signature for package: ${1}"
    echo "if the script errors out here, that means there was a bad signature on the package."
    gpg --verify  "${tmpDir}/${hashAlg}.sig" "${tmpDir}/${hashAlg}" 2>/dev/null
  fi

  if [[ ! "${should_be_hash}" == "${current_hash}" ]] ; then
    echo "Hashes are wrong."
    echo "current hash of file downloaded is: ${current_hash}"
    echo "it should be: ${should_be_hash}"
    exit 1
  fi

}

get_software(){
  echo ${FUNCNAME[0]}

  hashicorp_base='https://releases.hashicorp.com'


  get_version "${1}"
  echo ${FUNCNAME[0]}
  SOFT_VERSION="${1}_SOFTWARE_VERSION"
  software_base_url="${hashicorp_base}/${1}/${!SOFT_VERSION}"
  hashiKeyUrl="https://keybase.io/hashicorp/key.asc"

  case $1 in
    virtualbox)
      software_base_url="https://download.virtualbox.org/virtualbox/${!SOFT_VERSION}"
      os_version=$(grep 'CODENAME' /etc/*release | cut -d '=' -f 2 | sort -u)
      if [[ -z ${os_version} ]]  ; then
        os_version=$(grep '^VERSION=' /etc/*release | cut -d '=' -f 2 | tr -d '[:punct:]' | tr -d '[:digit:]' | tr -d '[:space:]')
      fi
      file_name=$(curl -sSL ${software_base_url} | grep href | cut -d '"' -f 2 | grep deb | grep $os_version)
      software_url="${software_base_url}/${file_name}"
      echo ${software_url}
      file_path="/tmp/${1}.deb"
      $curl -o ${file_path} ${software_url}
      ;;
    vagrant)
      file_name="${1}_${!SOFT_VERSION}_$(uname -m).deb"
      software_url="${software_base_url}/${file_name}"
      echo ${software_url}
      file_path="/tmp/${1}.deb"
      $curl -o ${file_path} ${software_url}
      ;;
    packer)
      file_name="${1}_${!SOFT_VERSION}_linux_amd64.zip"
      software_url="${software_base_url}/${file_name}"
      echo ${software_url}
      file_path="/tmp/${1}.zip"
      $curl -o ${file_path} ${software_url}
      ;;
  esac

  checksum "${1}"
  echo ${FUNCNAME[0]}

  # $curl
}

setup_software(){
  echo ${FUNCNAME[0]}
  case $1 in 
    virtualbox | vagrant)
      sudo ${package_manager} ${package_install_cmd} -f ${package_auto_yes_flag} "/tmp/${1}.deb"
      ;;
    packer) 
      packer_path='/opt/packer'
      mkdir -p ${packer_path}
      unzip -d ${packer_path} /tmp/packer.zip
      ln -sf ${packer_path}/packer /usr/bin/packer
  esac
}

dependencies(){
  echo ${FUNCNAME[0]}
  case $(grep "^ID=" /etc/*release | cut -d '=' -f 2 | tr '[:upper:]' '[:lower:]') in
    ubuntu | debian)
      packages_array=( "gpgv" "curl" "jq" "unzip" "linux-headers-$(uname -r)" "gcc" "make" "perl" "ufw" )
      package_manager='DEBIAN_FRONTEND=noninteractive apt-get'
      package_cmds_array=("update")
      package_auto_yes_flag='-y'
      package_install_cmd="install"
      ;;
  esac

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

ufw_setup(){
  echo "Setting firewall rules to only allow ssh, because sekurity :D"
  ufw allow ssh
  ufw default allow outgoing
  ufw --force enable
}

prep_for_packer(){
  pushd /opt/packer_kali
  echo 'building' | tee /opt/packer_kali/status.txt
  session_name=packer_build
  cp templates/template.json kali.json
  tmux new-session -s "${session_name}" -d
  tmux send-keys -t "$session_name:0" 'time packer build -var-file variables.json kali.json &> packer.log && echo "success" > status.txt || echo "failed" > status.txt' Enter
}

main(){
  echo ${FUNCNAME[0]}
  software_array=( "virtualbox" "vagrant" "packer" )
  dependencies

  for software in "${software_array[@]}" ; do
    get_software ${software}
    setup_software ${software}
  done
  ufw_setup
  prep_for_packer
  echo done
}

main
