# OBS Analytics with goaccess

If you install the package obs-api-analytics we have a couple of
script/crontabs that will generate web analytics with https://goaccess.io in
this directory.

- index.html will include what has happened today so far (refreshed every 15 minutes)
- 7/index.html will include what has happened the last 7 days
- YYYY-MM/index.html will include what has happened in that month

## Authorization

This directory is HTTP Basic Auth protected. You can add users/password via
httpasswd:

```shell
htpasswd -c /srv/www/obs/api/config/public-analytics.htpasswd username
```

## TODO

- [ ] Enable geo location
- [ ] Hide charts for panels where they don't make sense with html-prefs
- [ ] Sort panels with sort-panel
- [ ] Switch weekly/monthly script to use --persist/--restore instead of xzcat
- [ ] --with-output-resolver?
