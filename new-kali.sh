#!/usr/bin/env bash

hashiName=''
tmpDir='./tmp'
kaliKeyUrl='https://www.kali.org/archive-key.asc'
SHASUM='SHA256SUMS'
kaliBaseUrl='https://cdimage.kali.org/'
kaliWeeklyUrl="${kaliBaseUrl}kali-weekly/"
kaliWeeklySHAUrl="${kaliWeeklyUrl}${SHASUM}"
curl='curl -fsSL'
secretFileFullPath="${HOME}/src/mine/secrets/access_data"

mkdir -p $tmpDir

$curl $kaliWeeklySHAUrl -o ${tmpDir}/$SHASUM
$curl "${kaliWeeklySHAUrl}.gpg" -o "${tmpDir}/${SHASUM}.gpg"

kaliKey=$(wget -q -O - $kaliKeyUrl  | gpg --import 2>&1 | grep key | cut -d ' ' -f 3 | cut -d ':' -f 1 )

gpg --fingerprint $kaliKey

gpg --verify ${tmpDir}/${SHASUM}.gpg ${tmpDir}/$SHASUM

currentKaliISO=$(curl -s $kaliWeeklyUrl | grep -E 'linux-2018-W.*amd64' | grep -oE 'href.*' | cut -d '"' -f 2)

currentSHASUM=$(grep $currentKaliISO ${tmpDir}/$SHASUM | cut -d ' ' -f 1)

currentKali=$(curl -s $kaliBaseUrl | grep 'kali-' | grep -oE 'href.*' | cut -d '"' -f 2 | cut -d '/' -f 1 | grep -v 'kali-weekly' | tail -n 1 | cut -d '-' -f 2- )

namez="kali-linux-${currentKali}-amd64"

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

currentKaliISOUrl="${kaliWeeklyUrl}${currentKaliISO}"

printf '{"iso_url":"%s","iso_checksum":"%s","vm_name":"%s","vm_version":"%s","vagrant_cloud_token":"%s"}\n' "$currentKaliISOUrl" "$currentSHASUM" "$namez" "$vm_version" "$vagrant_cloud_token" | jq . | tee variables.json

rm -rf $tmpDir
