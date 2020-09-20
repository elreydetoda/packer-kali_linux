#!/usr/bin/env bash

## thank you for this script ladar:
##   https://github.com/hashicorp/packer/issues/6615#issuecomment-424422764
## had to fix something, because they were either uncessary or possibly not
##   applicable any more in 2.2.4 of vagrant. All my comments are indicated by
##   the ##, and the original comments are only a single #

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingmodifiedscripthardening
set -${-//[sc]/}eu${DEBUG+xv}o pipefail

# Cross platform scripting directory plus munchie madness.
BASE="$(pwd -P)"
pushd "$(dirname "$0")" > /dev/null
popd > /dev/null


printf '\n\n'



function help(){

  ## outputing help text
  printf 'Argument Description:,Script Name,Org Name,Name of box,Provider,Version,File Path\nExample execution:,./%s,double16,linux-dev-workstation,virtualbox,201809.1,box/virtualbox/linux-dev-workstation-201809.1.box\n' "$(basename "${0}")" | column -s ',' -tn 
  printf '\nOther Arguments/flags:\n'
  printf '\t%s) print this help section\n' '-h|--help'
  exit 1

}

function ci_get_vars(){
  if [[ -f "${variables_file}" ]] ; then
    vm_name="$( grep '"vm_name"' "${variables_file}" | cut -d '"' -f 4 )"
    ORG="$(cut -d '/' -f 1 <<< "${vm_name}")"
    NAME="$(cut -d '/' -f 2 <<< "${vm_name}")"
    VERSION="$( grep '"vm_version"' "${variables_file}" | cut -d '"' -f 4 )"
    FILE="${1}"
    PROVIDER="$(printf '%s' "${FILE}" | rev | cut -d '.' -f 2 | rev)"

  fi
}

function release_uploaded_version(){

  # Release the version, and watch the party rage.
  ${CURL} \
    --silent \
    --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
    "${base_url}/$ORG/$NAME/version/$VERSION/release" \
    --request PUT | jq '.status,.version,.providers[]' | grep -vE 'hosted|hosted_token|original_url|created_at|updated_at|\}|\{'

  printf '\n\n'

}

function upload_box(){

  # Perform the upload, and see the bits boil.
  if ! ${CURL} --tlsv1.2 --include --max-time 7200 --expect100-timeout 7200 --request PUT --output "$FILE.upload.log.txt" --upload-file "$FILE" "$UPLOAD_PATH" ; then
    echo 'This probably "failed", but it mostly actually succeeded and did not get closed properly.'
  fi
  
  printf '\n-----------------------------------------------------\n'
  tput setaf 5
  cat "$FILE.upload.log.txt"
  tput sgr0
  printf -- '-----------------------------------------------------\n\n'

}

function vagrant_cloud_prep_upload(){

  # Prepare an upload path, and then extract that upload path from the JSON
  # response using the jq command.
  UPLOAD_PATH=$(${CURL} \
    --silent \
    --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
    "${base_url}/$ORG/$NAME/version/$VERSION/provider/$PROVIDER/upload" | jq -r .upload_path)

}

function vagrant_cloud_deps(){
  ## create the box
  box_creation_status=$(
  ${CURL} \
    --silent \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
    "${base_url}es" \
    --data "
      {
        \"box\": {
          \"username\": \"${ORG}\",
          \"name\": \"${NAME}\",
          \"short_description\": \"${DESC}\",
          \"description\": \"${DESC}\",
          \"is_private\": \"false\"
        }
      }")

  if printf '%s' "${box_creation_status}" | grep 'tag' 1>/dev/null ; then
    printf 'Congrats on creating the vagrant box %s!' "$(printf "%s" "${box_creation_status}" | jq -r '.tag')"
  else
    printf 'Box %s has already been created' "$(printf "%s" "${box_creation_status}" | jq -r '.tag')"
  fi

  printf '\n\n'

  # Assume the position, while you create the version.
  ${CURL} \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
    "${base_url}/$ORG/$NAME/versions" \
    --data "
      {
        \"version\": {
          \"version\": \"$VERSION\",
          \"description\": \"A build environment for use in cross platform development.\"
        }
      }"

  printf '\n\n'

  # Create the provider, while become one with your inner child.
  ${CURL} \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
    "${base_url}/$ORG/$NAME/version/$VERSION/providers" \
    --data "
      {
        \"provider\": {
          \"name\": \"$PROVIDER\"
        }
      }"

  printf '\n\n'

}

function deps_check(){

  # The jq tool is needed to parse JSON responses.
  ## adjusted to be more bash compliant
  if ! command -v jq 1>/dev/null ; then
    tput setaf 1; printf '\n\nThe jq utility is not installed.\n\n\n'; tput sgr0
    exit 1
  fi
  
  # Ensure the credentials file is available.
  if [ -f "$BASE/.credentialsrc" ]; then
    ## added for shellcheck to ignore
    # shellcheck source=/dev/null
    . "$BASE/.credentialsrc"
  ## if no credential file check if variables.json file
  elif [[ -f "${variables_file_path}" ]] ; then
    ## check if vagrant_cloud_token exists
    if grep vagrant_cloud_token "${variables_file_path}" 1>/dev/null ; then
      ## pull token from there
      VAGRANT_CLOUD_TOKEN="$(grep vagrant_cloud_token ${variables_file_path} | cut -d '"' -f 4)"
    fi
  else
    tput setaf 1; printf '\nError. The credentials file is missing.\n\n'; tput sgr0
    exit 1
  fi
  
  if [ -z "${VAGRANT_CLOUD_TOKEN}" ]; then
    tput setaf 1; printf '\nError. The vagrant cloud token is missing. Add it to the credentials file.\n\n'; tput sgr0
  fi
    
  printf '\n\n'
  
  ## validating the token
  status=$(${CURL} \
    --silent \
    --header "Authorization: Bearer ${VAGRANT_CLOUD_TOKEN}" \
    https://app.vagrantup.com/api/v1/authenticate)
  
  ## checking if there was an error
  if printf '%s\n'  "${status}"  | grep error &>/dev/null ; then
    ## printing error message
    printf '%s\n'  "${status}"  | jq -r '.errors[].message'
  else
    ## output that it is valid
    printf 'You have a valid token, congrats.\n'
  fi

}

function main(){

  variables_file='variables.json'
  variables_file_path="${PWD}/${variables_file}"

  if [[ $# -eq 5 ]] ; then
    help
  elif [[ -n "${CIRCLECI:-}" ]] ; then
    # this is an alternative logic path for specifically the CI
    #   this will only take 1 arg ( the path to the box ) as an arg
    #   for file upload
    ci_get_vars "${@}"
  else
    case $1 in
      -h|--help)
          help
        ;;
    esac
  fi

  ORG="${ORG:-$1}"
  NAME="${NAME:-$2}"
  PROVIDER="${PROVIDER:-$3}"
  VERSION="${VERSION:-$4}"
  FILE="${FILE:-$5}"
  DESC='dev box'

  base_url='https://app.vagrantup.com/api/v1/box'

  CURL='curl'


  deps_check
  vagrant_cloud_deps
  vagrant_cloud_prep_upload
  upload_box
  release_uploaded_version
}

if [[ "${0}" = "${BASH_SOURCE[0]}" ]] ; then
  main "${@}"
fi
