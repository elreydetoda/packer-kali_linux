#!/bin/sh -eux

case "$PACKER_BUILDER_TYPE" in
  amazon-*)
    userz='ec2-user'
  ;;
  *)
    userz='vagrant'
  ;;
esac

# Only add the secure path line if it is not already present
grep -q 'secure_path' /etc/sudoers \
  || sed -i -e '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers;

# Set up password-less sudo for the user
echo "${userz} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/99_${userz}";
chmod 440 "/etc/sudoers.d/99_${userz}";
