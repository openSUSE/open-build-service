require 'rails_helper'
require 'ldap'

RSpec.describe UserLdapStrategy do
  let(:dn_string_no_uid)   { 'cn=jsmith,ou=Promotions,dc=noam,dc=com' }
  let(:dn_string_no_dc)    { 'cn=jsmith,ou=Promotions,uid=dister' }
  let(:dn_string_complete) { 'cn=jsmith,ou=Promotions,dc=noam,dc=com,uid=dister' }

  describe '.dn2user_principal_name' do
    context 'when no user id is provided' do
      it 'returns an empty string' do
        expect(UserLdapStrategy.dn2user_principal_name(dn_string_no_uid)).to eq('')
        expect(UserLdapStrategy.dn2user_principal_name([dn_string_no_uid])).to eq('')
      end
    end

    context 'when no domain componant is provided' do
      it "returns 'dister@'" do
        expect(UserLdapStrategy.dn2user_principal_name(dn_string_no_dc)).to eq('dister@')
        expect(UserLdapStrategy.dn2user_principal_name([dn_string_no_dc])).to eq('dister@')
      end
    end

    context 'when dc and user id is provided' do
      it 'returns the correct ldap address' do
        expect(UserLdapStrategy.dn2user_principal_name(dn_string_complete)).to eq('dister@noam.com')
        expect(UserLdapStrategy.dn2user_principal_name([dn_string_complete])).to eq('dister@noam.com')
      end
    end
  end

  describe '.authenticate_with_local' do
    context "with ldap auth method ':cleartext'" do
      before do
        stub_const('CONFIG', CONFIG.merge({
          'ldap_auth_mech' => :cleartext,
          'ldap_auth_attr' => 'CLR_userPassword'
        }))
      end

      it 'validates a correct password' do
        expect(UserLdapStrategy.authenticate_with_local("cleartext_pw",
                                                        { 'CLR_userPassword' => ['cleartext_pw'] })).to be true
      end

      it 'does not validate an incorrect password' do
        expect(UserLdapStrategy.authenticate_with_local("wrong_pw",
                                                        { 'CLR_userPassword' => ['cleartext_pw'] })).to be false
      end
    end

    context "with ldap auth method ':md5'" do
      before do
        stub_const('CONFIG', CONFIG.merge({
          'ldap_auth_mech' => :md5,
          'ldap_auth_attr' => 'MD5_userPassword'
        }))
      end

      it 'validates a correct password' do
        expect(UserLdapStrategy.authenticate_with_local("my_password",
                                                        { 'MD5_userPassword' => ["{MD5}qGWn4N2/NfpvaiMuCJO+pA==\n"] })).to be true
      end

      it 'does not validate an incorrect password' do
        expect(UserLdapStrategy.authenticate_with_local("wrong_pw",
                                                        { 'MD5_userPassword' => ["{MD5}qGWn4N2/NfpvaiMuCJO+pA==\n"] })).to be false
      end
    end

    context "with an unknown ldap auth method" do
      it 'does not validate' do
        expect(UserLdapStrategy.authenticate_with_local("cleartext_pw",
                                                        { 'CLR_userPassword' => ['cleartext_pw'] })).to be false
      end
    end

    context "when 'ldap_auth_attr' is empty" do
      before do
        stub_const('CONFIG', CONFIG.merge({
          'ldap_auth_mech' => :cleartext
        }))
      end

      it 'returns false' do
        expect(UserLdapStrategy.authenticate_with_local("cleartext_pw",
                                                        { 'CLR_userPassword' => ['cleartext_pw'] })).to be false
      end
    end
  end

  describe '.initialize_ldap_con' do
    context 'when no ldap_servers are configured' do
      it { expect(UserLdapStrategy.initialize_ldap_con('tux', 'tux_password')).to be nil }
    end

    context 'when ldap servers are configured' do
      let(:ldap_mock) { double(:ldap) }

      before do
        stub_const('CONFIG', CONFIG.merge({ 'ldap_servers' => 'my_ldap_server.com' }))

        allow(ldap_mock).to receive(:set_option).with(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_OFF)
        allow(ldap_mock).to receive(:set_option).with(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
      end

      context 'for SSL' do
        before do
          stub_const('CONFIG', CONFIG.merge({ 'ldap_ssl' => :on }))

          allow(LDAP::SSLConn).to receive(:new).with(
            'my_ldap_server.com', 636, false
          ).and_return(ldap_mock)
        end

        it_should_behave_like 'a ldap connection'
      end

      context 'configured for TSL' do
        before do
          stub_const('CONFIG', CONFIG.merge({ 'ldap_start_tls' => :on }))

          allow(LDAP::SSLConn).to receive(:new).with(
            'my_ldap_server.com', 636, true
          ).and_return(ldap_mock)
        end

        it_should_behave_like 'a ldap connection'
      end

      context 'not configured for TSL or SSL' do
        before do
          stub_const('CONFIG', CONFIG.merge({ 'ldap_ssl' => :off }))

          allow(LDAP::Conn).to receive(:new).with(
            'my_ldap_server.com', 389
          ).and_return(ldap_mock)
        end

        it_should_behave_like 'a ldap connection'
      end
    end
  end
end
