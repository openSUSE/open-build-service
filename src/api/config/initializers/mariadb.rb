# This fixes mysql2 client crashes with the following error:
# TLS/SSL error: SSL is required, but the server does not support it
ENV['MARIADB_TLS_DISABLE_PEER_VERIFICATION'] = '1'
