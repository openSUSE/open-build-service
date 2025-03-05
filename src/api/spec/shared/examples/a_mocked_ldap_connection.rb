RSpec.shared_examples 'a mocked ldap connection' do
  context 'when a connection can be established' do
    before do
      allow(ldap_mock).to receive(:bind).with('tux', 'tux_password')
      allow(ldap_mock).to receive(:bound?).and_return(true)
    end

    it 'returns the connection object' do
      expect(UserLdapStrategy.send(:initialize_ldap_con, 'tux', 'tux_password')).to be_bound
    end
  end

  context 'when no connection can be established' do
    before do
      allow(ldap_mock).to receive(:bind).with('tux', 'tux_password')
      allow(ldap_mock).to receive(:bound?).and_return(false)
    end

    it { expect(UserLdapStrategy.send(:initialize_ldap_con, 'tux', 'tux_password')).to be_nil }
  end

  context 'when establishing a connection fails with an error' do
    let(:err_object) { double(error: 'something happened') }

    before do
      allow(ldap_mock).to receive(:bound?)
      allow(ldap_mock).to receive(:bind).with('tux', 'tux_password').and_raise(LDAP::ResultError)
      allow(ldap_mock).to receive(:err).and_return(err_object)
      allow(ldap_mock).to receive(:err2string).with(err_object).and_return('something happened')
    end

    it { expect(UserLdapStrategy.send(:initialize_ldap_con, 'tux', 'tux_password')).to be_nil }
  end
end
