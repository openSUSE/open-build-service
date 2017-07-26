require 'rails_helper'

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
end
