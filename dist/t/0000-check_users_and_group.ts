#!/bin/bash

BASH_TAP_ROOT=$(dirname "$0")


# shellcheck source=/dev/null
. "$BASH_TAP_ROOT"/bash-tap-bootstrap


plan tests 3


group='obsrun'
result_group=$(getent group $group | cut -f1 -d:)
is "$result_group" "$group" "Checking group $group"

for user in obsrun obsservicerun; do
  result_user=$(getent passwd $user | cut -f1 -d:)
  is "$result_user" "$user" "Checking user $user"
done
