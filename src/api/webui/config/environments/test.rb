CONFIG['frontend_host'] = "localhost"
CONFIG['frontend_port'] = 3203
CONFIG['frontend_protocol'] = 'http'
CONFIG['frontend_ldap_mode'] = :off

CONFIG['proxy_auth_host'] = "https://build.opensuse.org"
CONFIG['proxy_auth_login_page'] = "https://build.opensuse.org/ICSLogin"
CONFIG['proxy_auth_logout_page'] = "/cmd/ICSLogout"
CONFIG['proxy_auth_mode'] = :off

# some defaults enforced
CONFIG['use_static'] = nil

# make sure we have invalid setup for errbit
CONFIG['errbit_api_key'] = 'INVALID'
