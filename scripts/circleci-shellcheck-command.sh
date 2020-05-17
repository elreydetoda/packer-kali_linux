#!/bin/sh

# circleci deps
apk add --update-cache --no-progress git
# shell_check cmd deps
apk add --update-cache --no-progress file
# shell check cmd
find /root/project -not -path "/root/project/.git/*" \
  -type f -exec file {} \; |
  grep 'shell script' |
  cut -d ':' -f 1 |
  xargs shellcheck --external-sources 
