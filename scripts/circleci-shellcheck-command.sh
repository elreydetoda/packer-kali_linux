#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[s]/}eu${DEBUG+xv}o pipefail

# TODO: functionalize all the different parts

function check_empty() {
  if [[ -z "${1}" ]]; then
    return 1
  fi
}

function param_check() {

  case "$#" in
    1)
      shellcheck_args="${1}"
      path_to_check="${PWD}"
      ;;
    2)
      shellcheck_args="${1}"
      path_to_check="${2}"
      ;;
    0)
      path_to_check="${PWD}"
      ;;
    *)
      printf 'There where an unexpected amount of arguments, specifically: %d\n' "$#"
      echo "Please set the correct amount of arguments."
      exit 2
      ;;
  esac

}

function parse_args() {

  # params for shellcheck arguments associative array
  counterz=0
  mapfile -t shellcheck_args_array < <(tr '|' '\n' <<< "${shellcheck_args}")

  for argz in "${shellcheck_args_array[@]}"; do

    case "${counterz}" in

      ## comments below are formatted as follows
      ##  ARG<argument_position>: <small_description>

      0)
        # ARG0: setting the severity that shellcheck should check with
        shellcheck_args_organized[sev]="${argz}"
        ;;
      1)
        # ARG1: the optional extra checks shellcheck can do
        shellcheck_args_organized[optional]="${argz}"
        ;;
      2)
        # ARG1: the optional extra checks shellcheck can do
        shellcheck_args_organized[format]="${argz}"
        ;;

    esac

    counterz=$((counterz + 1))

  done

}

function args_construct() {

  constructed_params=()

  for ((param = 0; param < counterz; param++)); do

    case "${param}" in
      0)
        check_empty "${shellcheck_args_organized[sev]}" || break
        constructed_params+=('-S' "${shellcheck_args_organized[sev]}")
        ;;
      1)
        check_empty "${shellcheck_args_organized[optional]}" || break
        constructed_params+=('-o' "${shellcheck_args_organized[optional]}")
        ;;
      2)
        check_empty "${shellcheck_args_organized[format]}" || break
        constructed_params+=('-f' "${shellcheck_args_organized[format]}")
        ;;
    esac

  done

}

function main() {

  declare -A shellcheck_args_organized
  param_check "${@}"
  parse_args
  args_construct

  # for debug
  # echo "${constructed_params[@]}"

  # cmd for shellcheck
  find "${path_to_check}" -not \( -path "${path_to_check}/.git/*" \
    -o -path "${path_to_check}/prov_packer/bento/*" \) -type f -exec file {} \; |
    grep 'shell script' |
    cut -d ':' -f 1 |
    xargs -t shellcheck --external-sources "${constructed_params[@]}"
}

# https://blog.elreydetoda.site/cool-shell-tricks/#bashscriptingbashsmain
if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then
  main "${@}"
fi
