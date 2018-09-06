#!/usr/bin/env bash

hashiName=''
tmpDir='./tmp'
kaliKeyUrl='https://www.kali.org/archive-key.asc'
hashAlg='SHA256SUMS'
kaliBaseUrl='https://cdimage.kali.org/'
# current
kaliCurrentUrl="${kaliBaseUrl}current/"
kaliCurrentSHAUrl="${kaliCurrentUrl}${hashAlg}"
curl='curl -fsSL'
secretFileFullPath="${HOME}/src/mine/secrets/access_data"

mkdir -p $tmpDir

# kali stable iso
$curl $kaliCurrentSHAUrl -o ${tmpDir}/$hashAlg
$curl "${kaliCurrentSHAUrl}.gpg" -o "${tmpDir}/${hashAlg}.gpg"

kaliKey=$(wget -q -O - $kaliKeyUrl  | gpg --import 2>&1 | grep key | cut -d ' ' -f 3 | cut -d ':' -f 1 )

gpg --fingerprint $kaliKey
gpg --verify ${tmpDir}/${hashAlg}.gpg ${tmpDir}/$hashAlg

# current
currentKaliISO=$(curl -s $kaliCurrentUrl | grep -E 'linux-2018.*amd64' | grep -oE 'href.*' | cut -d '"' -f 2)

currentHashAlg=$(grep $currentKaliISO ${tmpDir}/$hashAlg | cut -d ' ' -f 1)

currentKali=$(curl -s $kaliBaseUrl | grep 'kali-' | grep -oE 'href.*' | cut -d '"' -f 2 | cut -d '/' -f 1 | grep -v 'kali-weekly' | tail -n 1 | cut -d '-' -f 2- )

namez="kali-linux_amd64"

if [[ -f $secretFileFullPath ]]; then
	hashiName=$(grep vagrant_cloud $secretFileFullPath | cut -d ':' -f 2)
	vagrant_cloud_token=$(grep vagrant_cloud $secretFileFullPath | cut -d ':' -f 3-)
fi

if [[ ! -z $hashiName ]]; then
	namez="${hashiName}/${namez}"
	vagrantBoxUrl="https://app.vagrantup.com/$namez"
	getVersion=$(curl -sSL $vagrantBoxUrl | grep 'false')
	getVersionStatus=$?
	if [[ $getVersionStatus  -eq 0 ]] ; then
		vm_version='0.0.1'
	else
		currentVersion=$($curl $vagrantBoxUrl | jq '{versions}[][0]["version"]' | cut -d '"' -f 2)
		echo -e "The current version is $currentVersion, what version would you like?\nPlease keep similar formatting as the current example."
		read vm_version
	fi
fi

# current
currentKaliISOUrl="${kaliCurrentUrl}${currentKaliISO}"
hashAlgOut=$(echo $hashAlg | rev | cut -d 'S' -f 3- | rev | tr '[:upper:]' '[:lower:]')

printf '{"iso_url":"%s","iso_checksum_type":"%s","iso_checksum":"%s","vm_name":"%s","vm_version":"%s","vagrant_cloud_token":"%s"}\n' "$currentKaliISOUrl" "$hashAlgOut" "$currentHashAlg" "$namez" "$vm_version" "$vagrant_cloud_token" | jq . | tee variables.json

rm -rf $tmpDir
