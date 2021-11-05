#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[s]/}eu${DEBUG+xv}o pipefail

# dependencies
function deps_install() {

  install_cmd=()

  if [[ "${EUID}" -ne 0 ]]; then
    install_cmd+=('sudo')
  fi
  OS_VERSION="$(grep '^ID=' /etc/os-release | cut -d '=' -f 2)"
  case "${OS_VERSION}" in
    debian | ubuntu)
      packages=("gpg" "curl" "jq" "git")
      package_manager='apt'
      package_manager_install_cmd=('install' '-y')
      ;;
    alpine)
      packages=("gnupg" "curl" "jq" "git")
      package_manager='apk'
      package_manager_install_cmd=('--update' '--no-cache' 'add')
      ;;
  esac

  need_to_install=''
  needs=()
  for package in "${packages[@]}"; do
    if ! command -v "${package}" > /dev/null; then
      needs+=("${package}")
      need_to_install='true'
    fi
  done

  install_cmd=("${install_cmd[@]}" "${package_manager}" "${package_manager_install_cmd[@]}")

  if [[ "${OS_VERSION}" == 'alpine' ]]; then
    # installing GNU grep, instead of busybox built in
    packages+=('grep')
  fi

  if [[ -n "${need_to_install}" ]]; then
    printf 'need to install: %s\n' "${needs[@]}"
    "${install_cmd[@]}" "${packages[@]}"
  fi
}

function packer_out() {

  packer_var_json_string+=",$(printf '"vagrant_cloud_token":"%s"' "${vagrant_cloud_token}")"
  packer_var_json_string+=",$(printf '"build_directory":"%s"' "${install_type_print}")"

  if [[ -z "${CIRCLECI}" ]]; then
    read -n 1 -r -p 'Would you like this to be headless?[Y/n] ' set_headless
    # creating newline after read
    echo
    set_headless="${set_headless:-y}"
  else
    set_headless=''
  fi

  set_headless="$(printf '%s' "${set_headless}" | tr '[:upper:]' '[:lower:]')"

  if [[ -n "${CIRCLECI}" ]] || [[ "${set_headless}" == 'y' ]]; then
    packer_var_json_string+=",$(printf '"headless":"%s"' "true")"
  fi

  packer_var_json_string+='}'

  printf '%s' "${packer_var_json_string}" | jq '.' | tee "${variables_out_file}"
}

function hashicorp_setup_env() {

  if [[ -n "${hashiName}" ]]; then
    namez="${hashiName}/${namez}"
    vagrantBoxUrl="https://app.vagrantup.com/${namez}"
    if curl -sSL "${vagrantBoxUrl}" | grep 'false' 1> /dev/null; then
      vm_version='0.0.0'
    else
      currentVersion="$($curl "${vagrantBoxUrl}" | jq '{versions}[][0]["version"]' | cut -d '"' -f 2)"
      if [[ "${CIRCLECI}" ]]; then
        patch_release_version=$(($(echo "${currentVersion}" | cut -d '.' -f 3) + 1))
        vm_version="${MAJOR_RELEASE_VERSION}.${MINOR_RELEASE_VERSION}.${patch_release_version}"
      else
        printf '\n\nThe current version is %s, what version would you like?\nPlease keep similar formatting as the current example.\n' "${currentVersion}"
        read -r vm_version
      fi
    fi
  fi

  vm_version="${vm_version:-0.0.0}"

}

function cryptographical_verification() {

  # showing the hash signature url
  printf '\ncurrent url for hash algorithm for the %s version is:\n%s\n\n' "${kaliInstallVersion}" "${kaliCurrentHashUrl}"
  # show mirror where retrieved from
  #   showing possible mirrors
  printf '\npotential mirrors for hash algorithm:\n%s\n\nselected mirror: %s\n\n' \
    "$(curl -I "${kaliCurrentHashUrl}")" \
    "$(curl -sw '%{redirect_url}' -o /dev/null "${kaliCurrentHashUrl}")"

  echo "Starting ISO signature validation process."
  # downloading the hash algorithm file contents
  $curl "${kaliCurrentHashUrl}" -o "${tmpDir}/$hashAlg"
  # downloading the hash algorithms signature file contents
  $curl "${kaliCurrentHashUrl}.gpg" -o "${tmpDir}/${hashAlg}.gpg"
  # import gpg key to system keys
  $curl "${kaliKeyUrl}" | gpg --import

  # printing out the fingerprint for the key
  echo "showing gpg key info"
  gpg --fingerprint

  # checking the hash for it's integrity
  echo "verifying hash signature "
  gpg --verify "${tmpDir}/${hashAlg}.gpg" "${tmpDir}/${hashAlg}"

}

function info_enum() {

  printf '\nthe current version of the box is: %s\n' "${namez}"
  packer_var_json_string+="$(printf '"vm_name":"%s",' "${namez}")"

  # getting the current kali iso filename
  #   sed command, came from here: https://github.com/SamuraiWTF/samuraiwtf/pull/103#commitcomment-35941962
  #   NOTE: this is only compatible for >= 2020.1
  currentKaliISO=$(
    $curl "${kaliCurrentUrl}" |
      # parses the html and only grabs the lines with iso and version info
      sed -n "/href=\".*${kaliInstallISOVersion}.iso\"/p" |
      # specifically grabs the iso names
      awk -F'["]' '{print $8}' |
      # sort by '-' as a separator and sort on the 2'nd field ( starts at zero I guess ) with a version sort
      sort -t '-' -k2,2V |
      # select the top result ( should be the highest semver)
      head -n 1
  )
  printf '\ngetting filename of the kali iso: %s\n' "${currentKaliISO}"

  currentKaliISOUrl="${kaliCurrentUrl}/${currentKaliISO}"
  printf '\nthe selected release url is: %s\n' "${currentKaliISOUrl}"
  packer_var_json_string+="$(printf '"iso_url":"%s",' "${currentKaliISOUrl}")"

  printf '\nthe current hash alg chosen: %s\n' "${hashAlgOut}"
  # packer_var_json_string+="$(printf '"iso_checksum_type":"%s",' "${hashAlgOut}")"

  if ! grep "${currentKaliISO}" "${tmpDir}/${hashAlg}" &> /dev/null; then
    cat "${tmpDir}/${hashAlg}"
    exit 1
  fi

  currentHashSum=$(grep "${currentKaliISO}" "${tmpDir}/${hashAlg}" | cut -d ' ' -f 1)
  printf '\nthe current hash for that file is: %s\n' "${currentHashSum}"
  packer_var_json_string+="$(printf '"iso_checksum":"%s",' "${currentHashSum}")"

  currentKaliReleaseVersion=$(grep -oP '\d{4}\.\w' <<< "${currentKaliISO}")
  printf '\nthe selected release for kali is: %s\n' "${currentKaliReleaseVersion}"

  preseed_path="kali-linux-rolling${kaliInstallType}-preseed.cfg"
  printf '\nthe current install type is : %s\n' "${install_type_print}"
  printf '\nwhich means preseed file chosen is this : %s\n' "${preseed_path}"
  packer_var_json_string+="$(printf '"preseed_path":"%s",' "${preseed_path}")"

  printf '\nthe current version of the box is: %s\n\n' "${vm_version}"
  packer_var_json_string+="$(printf '"vm_version":"%s"' "${vm_version}")"

}

function cleanup() {
  rm -rf "${tmpDir}"
}

function aws_env() {

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
  kali_terraform_folder="${script_dir}/../ci/kali_aws_info"

  aws_secret_env_var="${TF_VAR_aws_secret_key:-}"
  packer_var_json_string+=",$(printf '"aws_secret_key":"%s",' "${aws_secret_env_var}")"

  aws_access_env_var="${TF_VAR_aws_access_key:-}"
  packer_var_json_string+="$(printf '"aws_access_key":"%s",' "${aws_access_env_var}")"

  aws_region_env_var="${TF_VAR_aws_region:-}"
  packer_var_json_string+="$(printf '"aws_region":"%s",' "${aws_region_env_var}")"

  pushd "${kali_terraform_folder}"
  "${script_dir}"/terraform-helper.sh auto-build aws

  source_ami_id="$("${script_dir}"/terraform-helper.sh output kali_ami_id)"

  "${script_dir}"/terraform-helper.sh auto-destroy aws

  popd

  remove_carriage_return="$(printf '%s' "${source_ami_id}" | tr -d '\r')"
  packer_var_json_string+="$(printf '"kali_aws_ami":"%s",' "${remove_carriage_return}")"

  read -rp 'Please enter in your aws account comma delimited ( if multiple ), you want to access the AMI: ' ami_users_list

  packer_var_json_string+="$(printf '"ami_users":"%s"' "${ami_users_list}")"
  echo "${ami_users_list}" "${remove_carriage_return}" "${aws_region_env_var}" "${aws_access_env_var}" "${aws_secret_env_var}"
}

function main() {

  ## all initial variables needed for script
  # creating a temporary directory
  tmpDir="$(mktemp -d)"

  ## relevant kali information necessary
  # base url for where to download the kali isos
  #kaliBaseUrl='https://cdimage.kali.org'
  # overriding till fixed: https://github.com/elreydetoda/packer-kali_linux/issues/125
  kaliBaseUrl='https://mirrors.ocf.berkeley.edu/kali-images'
  # this is the version in the web path for the folder that has the kali ISOs in it
  #   i.e. https://cdimage.kali.org/kali-weekly/ or https://cdimage.kali.org/kali-2020.3/
  # TODO: perscribed by offsec patch for #85 in github
  # KALIVERSION="kali-weekly"
  kaliInstallVersion="${KALIVERSION:-current}"
  # this is the iso version you would like to install
  #   i.e. installer-amd64.iso or netinst-amd64.iso
  kaliInstallISOVersion='netinst-amd64'
  # this is the install type ( i.e. default, light, min)
  #   so, this will limit how many tools will get installed with your kali installation
  kaliInstallType="${KALITYPE:-}"
  # the hash algorithm wanted for the kali version
  #   NOTE: try and always make this the best it can be
  hashAlg='SHA256SUMS'
  # doing this because if hash alg changes it should still get everything except the SUMS
  hashAlgOut=$(printf '%s' "${hashAlg}" | rev | cut -d 'S' -f 3- | rev | tr '[:upper:]' '[:lower:]')
  # the url for the gpg key that is used to sign the hashes for the ISOs
  kaliKeyUrl='https://archive.kali.org/archive-key.asc'

  ## vagrant box information
  # name of the vagrant box
  if [[ "$(git branch --show-current)" == dev* ]] || [[ "$(git branch --show-current)" == feat/* ]] || [[ "${CIRCLE_BRANCH:-}" == dev* ]]; then
    dev_branch='-dev'
  fi

  # type of install
  if [[ -z "${kaliInstallType}" ]]; then
    install_type_print='default'
  else
    install_type_print="${kaliInstallType}"
    kaliInstallType="-${kaliInstallType}"
  fi

  # name of the vagrant box
  namez="kali${kaliInstallType}-linux_amd64${dev_branch:-}"

  ## commands and combined variables
  # current version of kali's url combined with the base path
  #   convenient, because it will allow you to switch versions quickly (i.e. 2020.3, current release, 2020.1, etc...)
  kaliCurrentUrl="${kaliBaseUrl}/${kaliInstallVersion}"
  # url for the current hash algorithm
  kaliCurrentHashUrl="${kaliCurrentUrl}/${hashAlg}"
  # re-defining curl to have some extra flags by default (essentially a bash alias)
  curl='curl -fsSL'
  CIRCLECI="${CIRCLECI:-}"
  hashiName="${VAGRANT_CLOUD_USER:-}"
  vagrant_cloud_token="${VAGRANT_CLOUD_TOKEN:-}"

  if [[ -n "${CIRCLECI}" ]]; then
    variables_out_file="variables${kaliInstallType}.json"
  else
    variables_out_file='variables.json'
  fi

  packer_var_json_string='{'

  deps_install
  cryptographical_verification
  hashicorp_setup_env
  info_enum
  # if [[ -z "${CIRCLECI}" ]] && command -v docker; then
  #   aws_env
  # fi
  packer_out
  cleanup

}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then
  main "${@}"
fi
