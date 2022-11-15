#!/usr/bin/bash
# Generates goaccess HTML data from the rotated access logs of the last 7 days
# Runs each night after logrotate

last_7_days=()
for i in `seq 1 7`; do
 day=$(date -d "-$i day" '+%Y%m%d')
 last_7_days+=("/srv/www/obs/api/log/access.log-$day.xz")
done

# check for file existance
for i in `seq 0 6`; do
  test -f ${last_7_days[i]} || unset last_7_days[i]
done

# generate the HTML
mkdir -p /srv/www/obs/api/public/analytics/7/
if [ ${#last_7_days[@]} -gt 0 ]; then
  xzcat -q -c -T 0 ${last_7_days[*]} | goaccess -p /etc/goaccess/obs-goaccess.conf -o /srv/www/obs/api/public/analytics/7/index.html
fi
