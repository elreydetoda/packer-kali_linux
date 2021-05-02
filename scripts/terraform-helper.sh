#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[sc]/}eu${DEBUG+xv}o pipefail

function terraform_stuff() {

  terraform_action="${1}"
  # gottent from the bento project
  terraform_provider="${2:-''}"
  terraform_folder='/terraform'
  plan_file="${terraform_folder}/main.plan"
  state_file="${terraform_folder}/main.tfstate"

  case "${terraform_action}" in
    init)
      pre_args=("-chdir=${terraform_folder}/")
      extra_args=()
      ;;
    plan)
      pre_args=("-chdir=${terraform_folder}/")
      extra_args=("-out" "${plan_file}")
      ;;
    apply)
      if [[ -n "${TF_VAR_tc_auth_token:-}" ]]; then
        pre_args=("-chdir=${terraform_folder}/")
        extra_args=("-auto-approve")
      else
        pre_args=()
        extra_args=("-state" "${state_file}")
      fi
      ;;
    apply-plan)
      # gotten from: https://stackoverflow.com/questions/19482123/extract-part-of-a-string-using-bash-cut-split#answer-19482947
      # wbm: https://web.archive.org/web/20161121105825/http://stackoverflow.com/questions/19482123/extract-part-of-a-string-using-bash-cut-split#answer-19482947
      terraform_action="${terraform_action%-*}"
      extra_args=("-state" "${state_file}" "${plan_file}")
      pre_args=()
      ;;
    output)
      if [[ -n "${TF_VAR_tc_auth_token:-}" ]]; then
        extra_args=()
      else
        extra_args=("-state" "${state_file}")
      fi
      set +u
      if [[ -z "${2}" ]]; then
        extra_args+=()
      elif [[ -n "${2}" ]]; then
        extra_args+=("${2}")
      fi
      set -u
      pre_args=()
      terraform_provider='none'
      ;;
    destroy)
      if [[ -n "${TF_VAR_tc_auth_token:-}" ]]; then
        extra_args=("-auto-approve")
      else
        extra_args=("-auto-approve" "-state" "${state_file}")
      fi
      pre_args=("-chdir=${terraform_folder}/")
      ;;
    *)
      IFS=" " read -r -a extra_args <<< "${@:2}"
      if [[ -z "${extra_args[*]}" ]]; then
        extra_args=()
        pre_args=()
      fi
      ;;

  esac

  case "${terraform_provider}" in
    packet)
      provider_array=('-e' 'TF_VAR_project_id' '-e' 'TF_VAR_packet_auth_token')
      ;;
    aws)
      provider_array=('-e' 'TF_VAR_aws_access_key' '-e' 'TF_VAR_aws_secret_key' '-e' 'TF_VAR_aws_region')
      ;;
    none)
      provider_array=()
      ;;
    *)
      provider_array=('-e' 'TF_VAR_project_id' '-e' 'TF_VAR_packet_auth_token')
      provider_array+=('-e' 'TF_VAR_aws_access_key' '-e' 'TF_VAR_aws_secret_key' '-e' 'TF_VAR_aws_region')
      ;;
  esac

  if [[ -n "${TF_VAR_tc_auth_token:-}" ]] && [[ ! -f '.terraform.d/credentials.tfrc.json' ]]; then
    mkdir -p .terraform.d
    printf '{"credentials":{"app.terraform.io":{"token":"%s"}}}' "${TF_VAR_tc_auth_token}" | jq '.' > .terraform.d/credentials.tfrc.json
  fi

  if [[ -n "${TF_VAR_tc_auth_token:-}" ]]; then
    # shellcheck disable=SC2140
    # the disable is for the terraform folder bind mount
    docker container run \
      -it --rm -w '/terraform' \
      "${provider_array[@]}" \
      -v "$(pwd)/.terraform.d":/root/.terraform.d/ \
      -v "$(pwd)/.terraform":/.terraform/ \
      -v "$(pwd)":"${terraform_folder}/" \
      hashicorp/terraform:light "${pre_args[@]}"  "${terraform_action}" "${extra_args[@]}"
  else

    # shellcheck disable=SC2140
    # the disable is for the terraform folder bind mount
    docker container run \
      -it --rm -w '/terraform' \
      "${provider_array[@]}" \
      -v "$(pwd)/.terraform":/.terraform/ \
      -v "$(pwd)":"${terraform_folder}/" \
      hashicorp/terraform:light "${pre_args[@]}" "${terraform_action}" "${extra_args[@]}"
  fi

}

function cleanup() {

  # removing stuff that was created w/verbose
  sudo rm -rfv .terraform{,.d}/ main.tfstate* main.plan

}

function main() {

  if [[ $# -lt 1 ]]; then
    printf 'Please enter at one terraform directive: %s %s [aws|packet|]\n' "${0}" "<init|plan|apply|destroy>|<auto-build|auto-destroy|cleanup>"
    exit 1
  fi

  if [[ "${1}" == "clean" ]] || [[ "${1}" == "cleanup" ]]; then

    cleanup

  elif [[ "${1}" == "auto-build" ]]; then

    steps_array=('init' 'plan' 'apply-plan')

    for step in "${steps_array[@]}"; do

      if [[ -n "${TF_VAR_tc_auth_token:-}" ]] && [[ "${step}" == 'plan' ]]; then
        terraform_stuff apply "${2}"
        break
      fi

      terraform_stuff "${step}" "${2}"

    done

  elif [[ "${1}" == "auto-destroy" ]]; then

    terraform_stuff "destroy" "${2}"
    cleanup

  else

    terraform_stuff "${@}"

  fi
}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" = "${BASH_SOURCE[0]}" ]]; then
  main "${@}"
fi
