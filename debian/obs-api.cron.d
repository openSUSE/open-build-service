PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
MAILTO="root@localhost"

* * * * *       www-data    cd /usr/share/obs/api/ && RAILS_ENV=production rake -s jobs:workerstatus > /dev/null
# Disabled: it is apparently used for updating non existing obs bugzilla. SIN: #55
#1 * * * *       www-data    cd /usr/share/obs/api/ && RAILS_ENV=production rake -s jobs:updateissues > /dev/null
