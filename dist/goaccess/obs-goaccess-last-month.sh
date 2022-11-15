#!/usr/bin/bash
# Generates goaccess HTML data from last months rotated apache access logs
# Runs from cron.d on every first of the month

NOW_MONTH=$(date +%Y-%m)
PREVIOUS_MONTH=$(date -d "$nowmonth-15 last month" '+%Y%m')

mkdir -p /srv/www/obs/api/public/analytics/$PREVIOUS_MONTH/
xzcat -q -c -T 0 /srv/www/obs/api/log/access.log-$PREVIOUS_MONTH*.xz | goaccess -p /etc/goaccess/obs-goaccess.conf -o /srv/www/obs/api/public/analytics/$PREVIOUS_MONTH/index.html
