#!/bin/bash
set -e
echo "1..1"

cat <<EOF > $HOME/.oscrc
[general]
apiurl = https://localhost

[https://localhost]
user=Admin
pass=opensuse

EOF

echo "ok - configuring osc"

exit 0
