#!/usr/bin/env bash

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingmodifiedscripthardening
set -${-//[sc]/}eu${DEBUG+xv}o pipefail

function setup_env() {
  # debugging: https://www.packer.io/docs/other/debugging.html
  export PACKER_LOG=1
  PACKER_LOG_DIR="${PACKER_LOG_DIR:-/opt/packerAutoKali/}"
  # PACKER_LOG_PATH=./packer_build.log
  export PACKER_LOG_PATH="${PACKER_LOG_PATH:-${PACKER_LOG_DIR}}/packer_build.log"
}

function packer_build() {
  provider="${1}"

  case "${provider}" in
    virtualbox-iso)
      packer_build_cmd+=('-only=virtualbox-iso')
      ;;
    vmware-iso)
      packer_build_cmd+=('-only=vmware-iso')
      ;;
    qemu)
      packer_build_cmd+=('-only=qemu')
      ;;
    *)
      # just a stop gap to prevent automated tasks from happening.
      read -rp 'You are about to try and build all the providers at once...are you sure[N/y]' -n 1
      ;;
  esac

}

main() {
  providers_to_build="${1}"
  packer_build_cmd=(
    'packer' 'build'
    '-var-file' 'variables.json'
  )
  mapfile -t provider_array < <(tr '|' '\n' <<< "${providers_to_build}")

  setup_env

  for provider in "${provider_array[@]}"; do
    packer_build "${provider}"
  done

  # adding the template for the build command
  packer_build_cmd+=('kali-template.json')

  "${packer_build_cmd[@]}"
}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then
  main "${@}"
fi
