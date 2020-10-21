#!/usr/bin/env bash

# https://elrey.casa/bash/scripting/harden
set -${-//[s]/}eu${DEBUG+xv}o pipefail

function check_not_amazon() {

  case "$PACKER_BUILDER_TYPE" in
    amazon-*)
        exit 0
        ;;
  esac

}

function check_amazon() {

  case "$PACKER_BUILDER_TYPE" in
    amazon-*)
        # this does nothing so the script proceeds
        :
        ;;
    *)
        pass
        ;;
  esac

}
