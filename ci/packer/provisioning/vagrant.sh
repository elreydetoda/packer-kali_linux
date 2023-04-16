#!/bin/sh -eux

case "$PACKER_BUILDER_TYPE" in
  amazon-*) : ;;
  *) exit 0 ;;
esac

adduser --disabled-password --gecos '' vagrant
