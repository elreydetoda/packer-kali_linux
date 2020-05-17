#!/usr/bin/env bash

set -${-//[s]/}eu${DEBUG+xv}o pipefail

tmpDir='./tmp'
kaliKeyUrl='https://www.kali.org/archive-key.asc'
hashAlg='SHA256SUMS'
kaliBaseUrl='https://cdimage.kali.org/'
# current
kaliCurrentUrl="${kaliBaseUrl}current/"
kaliCurrentSHAUrl="${kaliCurrentUrl}${hashAlg}"
curl='curl -fsSL'
secretFileFullPath="${HOME}/src/mine/secrets/access_data"

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



mkdir -p $tmpDir

# kali stable iso
echo curl url: $(curl -sS $kaliCurrentSHAUrl -o - | grep -oP 'href=".*"' | tr -d '"' | cut -d '=' -f 2)
$curl $kaliCurrentSHAUrl -o ${tmpDir}/$hashAlg
$curl "${kaliCurrentSHAUrl}.gpg" -o "${tmpDir}/${hashAlg}.gpg"

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

if [[ -f $secretFileFullPath ]] ; then
	hashiName=$(grep vagrant_cloud $secretFileFullPath | cut -d ':' -f 2)
	vagrant_cloud_token=$(grep vagrant_cloud $secretFileFullPath | cut -d ':' -f 3-)
elif [[ $CIRCLECI ]] ; then
	hashiName="${VAGRANT_CLOUD_USER}"
	vagrant_cloud_token="${VAGRANT_CLOUD_TOKEN}"
elif [[ "$(whoami)" == 'vagrant' ]] ; then
  hashiName="${VAGRANT_CLOUD_USER}"
	vagrant_cloud_token="${VAGRANT_CLOUD_TOKEN}"
fi

if [[ ! -z $hashiName ]]; then
	namez="${hashiName}/${namez}"
	vagrantBoxUrl="https://app.vagrantup.com/$namez"
	if curl -sSL $vagrantBoxUrl | grep 'false' 1> /dev/null ; then
		vm_version='0.0.1'
	else
		currentVersion=$($curl $vagrantBoxUrl | jq '{versions}[][0]["version"]' | cut -d '"' -f 2)
		if [[ $CIRCLECI ]] ; then
			patch_release_version=$(( $(echo $currentVersion | cut -d '.' -f 3) + 1 ))
			vm_version="${MAJOR_RELEASE_VERSION}.${MINOR_RELEASE_VERSION}.${patch_release_version}"
		else
			echo -e "The current version is $currentVersion, what version would you like?\nPlease keep similar formatting as the current example."
			read -r vm_version
		fi
	fi
fi

# current
currentKaliISOUrl="${kaliCurrentUrl}${currentKaliISO}"
hashAlgOut=$(echo $hashAlg | rev | cut -d 'S' -f 3- | rev | tr '[:upper:]' '[:lower:]')

if [[ $CIRCLECI ]] ; then
  echo "current iso url: $currentKaliISOUrl"
  echo "current iso $hashAlgOut"
  echo "current iso checksum: $currentHashAlg"
  echo "current version: $vm_version"
	printf '{"iso_url":"%s","iso_checksum_type":"%s","iso_checksum":"%s","vm_name":"%s","vm_version":"%s","vagrant_cloud_token":"%s","headless":"true"}\n' "$currentKaliISOUrl" "$hashAlgOut" "$currentHashAlg" "$namez" "$vm_version" "$vagrant_cloud_token" | jq . > variables.json
else
	printf '{"iso_url":"%s","iso_checksum_type":"%s","iso_checksum":"%s","vm_name":"%s","vm_version":"%s","vagrant_cloud_token":"%s"}\n' "$currentKaliISOUrl" "$hashAlgOut" "$currentHashAlg" "$namez" "$vm_version" "$vagrant_cloud_token" | jq . | tee variables.json
fi
rm -rf $tmpDir
