require 'ldap'

RSpec.shared_context 'setup ldap conn' do |opts|
  let(:ldap_conn) do
    opts ||= {}
    expected_port = (opts[:for_ssl] ? 636 : 389)

    ldap_conn = if opts[:for_ssl]
                  LDAP::SSLConn.new('openldap', expected_port, CONFIG['ldap_start_tls'] == :on)
                else
                  LDAP::Conn.new('openldap', expected_port)
                end
    ldap_conn.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
    ldap_conn.set_option(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_OFF) if CONFIG['ldap_referrals'] == :off
    ldap_conn
  end
end
