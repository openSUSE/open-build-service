#!/bin/bash

export BASH_TAP_ROOT=$(dirname $0)


. $(dirname $0)/bash-tap-bootstrap


plan tests 3


for group in obsrun;do
  result_group=$(getent group $group | cut -f1 -d:)
  is "$result_group" "$group" "Checking group $group"
done

for user in obsrun obsservicerun;do
  result_user=$(getent passwd $user | cut -f1 -d:)
  is "$result_user" "$user" "Checking user $user"
done
