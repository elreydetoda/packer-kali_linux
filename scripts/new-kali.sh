#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[s]/}eu${DEBUG+xv}o pipefail


# # dependencies
# deps_install(){
#   case $(grep '^ID' /etc/os-release | cut -d '=' -f 2) in
#     ubuntu)
#       packages=("gpg" "wget" "curl" "jq")
#       package_manager="apt"
#   esac
# }
#
# deps=("gpg" "wget" "curl" "jq")
# for dep in "${deps[@]}" ; do
#   if ! which ${dep} ; then
#     echo "need to install ${dep}"
#     deps_install
#     break
#   fi
# done




# if [[ -f $secretFileFullPath ]] ; then
#     hashiName=$(grep vagrant_cloud $secretFileFullPath | cut -d ':' -f 2)
#     vagrant_cloud_token=$(grep vagrant_cloud $secretFileFullPath | cut -d ':' -f 3-)
# elif [[ $CIRCLECI ]] ; then
#     hashiName="${VAGRANT_CLOUD_USER}"
#     vagrant_cloud_token="${VAGRANT_CLOUD_TOKEN}"
# elif [[ "$(whoami)" == 'vagrant' ]] ; then
#   hashiName="${VAGRANT_CLOUD_USER}"
#     vagrant_cloud_token="${VAGRANT_CLOUD_TOKEN}"
# fi

# if [[ ! -z $hashiName ]]; then
#     namez="${hashiName}/${namez}"
#     vagrantBoxUrl="https://app.vagrantup.com/$namez"
#     if curl -sSL $vagrantBoxUrl | grep 'false' 1> /dev/null ; then
#         vm_version='0.0.1'
#     else
#         currentVersion=$($curl $vagrantBoxUrl | jq '{versions}[][0]["version"]' | cut -d '"' -f 2)
#         if [[ $CIRCLECI ]] ; then
#             patch_release_version=$(( $(echo $currentVersion | cut -d '.' -f 3) + 1 ))
#             vm_version="${MAJOR_RELEASE_VERSION}.${MINOR_RELEASE_VERSION}.${patch_release_version}"
#         else
#             echo -e "The current version is $currentVersion, what version would you like?\nPlease keep similar formatting as the current example."
#             read -r vm_version
#         fi
#     fi
# fi

# # current
# currentKaliISOUrl="${kaliCurrentUrl}${currentKaliISO}"
# hashAlgOut=$(echo $hashAlg | rev | cut -d 'S' -f 3- | rev | tr '[:upper:]' '[:lower:]')

# if [[ $CIRCLECI ]] ; then
#   echo "current iso url: $currentKaliISOUrl"
#   echo "current iso $hashAlgOut"
#   echo "current iso checksum: $currentHashAlg"
#   echo "current version: $vm_version"
#   printf '{"iso_url":"%s","iso_checksum_type":"%s","iso_checksum":"%s","vm_name":"%s","vm_version":"%s","vagrant_cloud_token":"%s","headless":"true"}\n' "$currentKaliISOUrl" "$hashAlgOut" "$currentHashAlg" "$namez" "$vm_version" "$vagrant_cloud_token" | jq . > variables.json
# else
#   printf '{"iso_url":"%s","iso_checksum_type":"%s","iso_checksum":"%s","vm_name":"%s","vm_version":"%s","vagrant_cloud_token":"%s"}\n' "$currentKaliISOUrl" "$hashAlgOut" "$currentHashAlg" "$namez" "$vm_version" "$vagrant_cloud_token" | jq . | tee variables.json
# fi
# rm -rf $tmpDir

function info_enum(){

  # kali stable iso
  echo curl url: $(curl -sS $kaliCurrentHashUrl -o - | grep -oP 'href=".*"' | tr -d '"' | cut -d '=' -f 2)
  $curl $kaliCurrentHashUrl -o ${tmpDir}/$hashAlg
  $curl "${kaliCurrentHashUrl}.gpg" -o "${tmpDir}/${hashAlg}.gpg"

  kaliKey=$($curl $kaliKeyUrl  | gpg --import 2>&1 | grep key | cut -d ' ' -f 3 | cut -d ':' -f 1 )

  gpg --fingerprint $kaliKey
  echo "verifying shasums "
  gpg --verify ${tmpDir}/${hashAlg}.gpg ${tmpDir}/$hashAlg

  # current
  echo "getting current kali iso url"
  currentKaliISO=$(curl -s $kaliCurrentUrl | grep -P "linux-\d+\.\d(\w|)+-installer-netinst-amd64" | grep -oE 'href.*' | cut -d '"' -f 2)

  currentHashAlg=$(grep $currentKaliISO ${tmpDir}/$hashAlg | cut -d ' ' -f 1)

  currentKali=$(curl -s $kaliBaseUrl | grep 'kali-' | grep -oE 'href.*' | cut -d '"' -f 2 | cut -d '/' -f 1 | grep -v 'kali-weekly' | tail -n 1 | cut -d '-' -f 2- )

  namez="kali-linux_amd64"
}

function main(){

  ## all initial variables needed for script
  # creating a temporary directory
  tmpDir="$(mktemp -d)"

  ## relevant kali information necessary
  # base url for where to download the kali isos 
  kaliBaseUrl='https://cdimage.kali.org'
  # this is the version in the web path for the folder that has the kali ISOs in it
  #   i.e. https://cdimage.kali.org/kali-weekly/ or https://cdimage.kali.org/kali-2020.3/
  kaliInstallVersion='current'
  # the hash algorithm wanted for the kali version
  #   NOTE: try and always make this the best it can be
  hashAlg='SHA256SUMS'
  # the url for the gpg key that is used to sign the hashes for the ISOs
  kaliKeyUrl='https://www.kali.org/archive-key.asc'


  ## commands and combined variables
  # current version of kali's url combined with the base path
  #   convenient, because it will allow you to switch versions quickly (i.e. 2020.3, current release, 2020.1, etc...)
  kaliCurrentUrl="${kaliBaseUrl}/${kaliInstallVersion}"
  # url for the current hash algorithm
  kaliCurrentHashUrl="${kaliCurrentUrl}/${hashAlg}"
  # re-defining curl to have some extra flags by default (essentially a bash alias)
  curl='curl -fsSL'

}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]] ; then
  main "${@}"
fi
