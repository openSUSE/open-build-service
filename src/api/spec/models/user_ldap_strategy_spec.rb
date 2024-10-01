RSpec.describe UserLdapStrategy, skip: !Rails.env.test_ldap? do
  let(:dn_string_no_uid)   { 'cn=jsmith,ou=Promotions,dc=noam,dc=com' }
  let(:dn_string_no_dc)    { 'cn=jsmith,ou=Promotions,uid=dister' }
  let(:dn_string_complete) { 'cn=jsmith,ou=Promotions,dc=noam,dc=com,uid=dister' }

  describe '.dn2user_principal_name' do
    context 'when no user id is provided' do
      it 'returns an empty string' do
        expect(UserLdapStrategy.send(:dn2user_principal_name, dn_string_no_uid)).to eq('')
        expect(UserLdapStrategy.send(:dn2user_principal_name, [dn_string_no_uid])).to eq('')
      end
    end

    context 'when no domain componant is provided' do
      it "returns 'dister@'" do
        expect(UserLdapStrategy.send(:dn2user_principal_name, dn_string_no_dc)).to eq('dister@')
        expect(UserLdapStrategy.send(:dn2user_principal_name, [dn_string_no_dc])).to eq('dister@')
      end
    end

    context 'when dc and user id is provided' do
      it 'returns the correct ldap address' do
        expect(UserLdapStrategy.send(:dn2user_principal_name, dn_string_complete)).to eq('dister@noam.com')
        expect(UserLdapStrategy.send(:dn2user_principal_name, [dn_string_complete])).to eq('dister@noam.com')
      end
    end
  end

  describe '.authenticate_with_local' do
    context "with ldap auth method ':cleartext'" do
      before do
        stub_const('CONFIG', CONFIG.merge('ldap_auth_mech' => :cleartext,
                                          'ldap_auth_attr' => 'CLR_userPassword'))
      end

      it 'validates a correct password' do
        expect(UserLdapStrategy.send(:authenticate_with_local,
                                     'cleartext_pw',
                                     'CLR_userPassword' => ['cleartext_pw'])).to be(true)
      end

      it 'does not validate an incorrect password' do
        expect(UserLdapStrategy.send(:authenticate_with_local,
                                     'wrong_pw',
                                     'CLR_userPassword' => ['cleartext_pw'])).to be(false)
      end
    end

    context "with ldap auth method ':md5'" do
      before do
        stub_const('CONFIG', CONFIG.merge('ldap_auth_mech' => :md5,
                                          'ldap_auth_attr' => 'MD5_userPassword'))
      end

      it 'validates a correct password' do
        expect(UserLdapStrategy.send(:authenticate_with_local,
                                     'my_password',
                                     'MD5_userPassword' => ["{MD5}qGWn4N2/NfpvaiMuCJO+pA==\n"])).to be(true)
      end

      it 'does not validate an incorrect password' do
        expect(UserLdapStrategy.send(:authenticate_with_local,
                                     'wrong_pw',
                                     'MD5_userPassword' => ["{MD5}qGWn4N2/NfpvaiMuCJO+pA==\n"])).to be(false)
      end
    end

    context 'with an unknown ldap auth method' do
      it 'does not validate' do
        expect(UserLdapStrategy.send(:authenticate_with_local,
                                     'cleartext_pw',
                                     'CLR_userPassword' => ['cleartext_pw'])).to be(false)
      end
    end

    context "when 'ldap_auth_attr' is empty" do
      before do
        stub_const('CONFIG', CONFIG.merge('ldap_auth_mech' => :cleartext))
      end

      it 'returns false' do
        expect(UserLdapStrategy.send(:authenticate_with_local,
                                     'cleartext_pw',
                                     'CLR_userPassword' => ['cleartext_pw'])).to be(false)
      end
    end
  end

  describe '.initialize_ldap_con' do
    context 'when no ldap_servers are configured' do
      it { expect(UserLdapStrategy.send(:initialize_ldap_con, 'tux', 'tux_password')).to be_nil }
    end

    context 'when ldap servers are configured' do
      context 'for SSL' do
        include_context 'setup ldap mock', for_ssl: true

        before do
          stub_const('CONFIG', CONFIG.merge('ldap_ssl' => :on))
        end

        it_behaves_like 'a mocked ldap connection'
      end

      context 'configured for TSL' do
        include_context 'setup ldap mock', for_ssl: true, start_tls: true

        before do
          stub_const('CONFIG', CONFIG.merge('ldap_start_tls' => :on))
        end

        it_behaves_like 'a mocked ldap connection'
      end

      context 'not configured for TSL or SSL' do
        context 'when a connection can be established' do
          it 'returns the connection object' do
            expect(UserLdapStrategy.send(:initialize_ldap_con, CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])).to be_bound
          end
        end

        context 'when a connection can not be established' do
          it { expect(UserLdapStrategy.send(:initialize_ldap_con, CONFIG['ldap_search_user'], 'WRONG_password')).to be_nil }
        end
      end
    end
  end

  describe '.find_group_with_ldap' do
    after do
      # rspec-mocks doubles are not designed to last longer than for one
      # example. Therefore we have to clear the stored connection.
      UserLdapStrategy.class_variable_set(:@@ldap_search_con, nil)
    end

    context 'when there is no connection' do
      it { expect(UserLdapStrategy.find_group_with_ldap('any_group')).to be_blank }
    end

    context 'when there is a connection' do
      include_context 'setup ldap mock', for_ssl: true

      before do
        stub_const('CONFIG', CONFIG.merge('ldap_search_user' => 'tux',
                                          'ldap_search_auth' => 'tux_password',
                                          'ldap_group_objectclass_attr' => 'groupOfNames',
                                          'ldap_group_search_base' => 'ou=OBSGROUPS,dc=EXAMPLE,dc=COM',
                                          'ldap_group_title_attr' => 'ldap_group',
                                          'ldap_ssl' => :on))

        allow(ldap_mock).to receive(:bind).with('tux', 'tux_password')
        allow(ldap_mock).to receive(:bound?).and_return(true)
      end

      context "with 'ldap_group_objectclass_attr' configured" do
        before do
          allow(ldap_mock).to receive(:search).with(
            'ou=OBSGROUPS,dc=EXAMPLE,dc=COM', LDAP::LDAP_SCOPE_SUBTREE, '(&(ldap_group=any_group)(objectclass=groupOfNames))'
          ).and_yield(double(dn: 'some_dn', attrs: 'some_attr'))
        end

        it { expect(UserLdapStrategy.find_group_with_ldap('any_group')).to eq(%w[some_dn some_attr]) }
      end

      context "without 'ldap_group_objectclass_attr' configured" do
        before do
          stub_const('CONFIG', CONFIG.reject { |key, _| key == 'ldap_group_objectclass_attr' })

          allow(ldap_mock).to receive(:search).with(
            'ou=OBSGROUPS,dc=EXAMPLE,dc=COM', LDAP::LDAP_SCOPE_SUBTREE, '(ldap_group=any_group)'
          ).and_yield(double(dn: 'some_dn', attrs: 'some_attr'))
        end

        it { expect(UserLdapStrategy.find_group_with_ldap('any_group')).to eq(%w[some_dn some_attr]) }
      end

      context 'when there is no result' do
        before do
          allow(ldap_mock).to receive(:search).with(
            'ou=OBSGROUPS,dc=EXAMPLE,dc=COM', LDAP::LDAP_SCOPE_SUBTREE, '(&(ldap_group=any_group)(objectclass=groupOfNames))'
          )
        end

        it { expect(UserLdapStrategy.find_group_with_ldap('any_group')).to eq([]) }
      end
    end
  end

  describe '#find_with_ldap' do
    before do
      stub_const('CONFIG', CONFIG.merge('ldap_search_user' => 'tux',
                                        'ldap_search_auth' => 'tux_password',
                                        'ldap_ssl' => :off,
                                        'ldap_authenticate' => :ldap))
    end

    context 'ldap doesnt connect' do
      subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

      before do
        allow(UserLdapStrategy).to receive(:initialize_ldap_con).and_return(nil)
      end

      after do
        UserLdapStrategy.class_variable_set(:@@ldap_search_con, nil)
      end

      it { is_expected.to be_nil }
    end

    context 'ldap connects' do
      context 'ldap search works' do
        subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

        include_context 'setup ldap mock'
        include_context 'an ldap connection'

        before do
          allow(ldap_mock).to receive(:search)
        end

        it { is_expected.to be_nil } # returns nil because the user was not found
      end

      context 'without ldap_user_filter set' do
        subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

        include_context 'setup ldap mock'
        include_context 'an ldap connection'

        before do
          stub_const('CONFIG', CONFIG.merge('ldap_user_filter' => nil))

          allow(ldap_mock).to receive(:search)
        end

        it { is_expected.to be_nil } # returns nil because the user was not found
      end

      context 'ldap search raises an error' do
        subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

        include_context 'setup ldap mock'
        include_context 'an ldap connection'

        before do
          allow(ldap_mock).to receive(:search).and_raise(ArgumentError)
          allow(ldap_mock).to receive_messages(err: 'something went wrong', err2string: 'something went wrong')
          allow(ldap_mock).to receive(:unbind)
        end

        it { is_expected.to be_nil }
      end

      context 'ldap_authenticate = :local' do
        subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

        include_context 'setup ldap mock'
        include_context 'an ldap connection'

        let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'helloworld' }) }

        before do
          stub_const('CONFIG', CONFIG.merge('ldap_authenticate' => :local))
          allow(ldap_mock).to receive(:search).and_yield(ldap_user)
        end

        it { is_expected.to be_nil }
      end

      context 'ldap_authenticate = nil' do
        subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

        include_context 'setup ldap mock'
        include_context 'an ldap connection'

        let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'helloworld' }) }

        before do
          stub_const('CONFIG', CONFIG.merge('ldap_authenticate' => nil))
          allow(ldap_mock).to receive(:search).and_yield(ldap_user)
        end

        it { is_expected.to be_nil }
      end

      context 'ldap_authenticate = :ldap and password is nil' do
        subject { UserLdapStrategy.find_with_ldap('tux', nil) }

        include_context 'setup ldap mock'
        include_context 'an ldap connection'

        let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'helloworld' }) }

        before do
          allow(ldap_mock).to receive(:search).and_yield(ldap_user)
        end

        it { is_expected.to be_nil }
      end

      context 'ldap_authenticate = :ldap' do
        subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

        include_context 'setup ldap mock with user mock'
        include_context 'an ldap connection'
        include_context 'mock searching a user' do
          let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'tux', 'sn' => %w[John Smith] }) }
        end

        it 'returns name and username' do
          expect(subject).to eq(%w[John tux])
        end
      end

      context 'ldap_authenticate = :ldap and user connection returning nil' do
        subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

        include_context 'setup ldap mock with user mock'
        include_context 'an ldap connection'
        include_context 'mock searching a user' do
          let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'tux', 'sn' => %w[John Smith] }) }
        end

        before do
          allow(ldap_user_mock).to receive(:bound?).and_return(false)
        end

        it { is_expected.to be_nil }
      end

      context 'ldap_authenticate = :ldap and the users ldap_mail_attr is not set' do
        subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

        include_context 'setup ldap mock with user mock'
        include_context 'an ldap connection'
        include_context 'mock searching a user' do
          let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'tux' }) }
        end

        it 'returns empty string and username' do
          expect(subject).to eq(['', 'tux'])
        end
      end

      context 'ldap_authenticate = :ldap and the users ldap_name_attr is set' do
        subject { UserLdapStrategy.find_with_ldap('tux', 'tux_password') }

        include_context 'setup ldap mock with user mock'
        include_context 'an ldap connection'
        include_context 'mock searching a user' do
          let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'tux', 'sn' => %w[John Smith], 'fn' => 'SJ' }) }
        end

        before do
          stub_const('CONFIG', CONFIG.merge('ldap_name_attr' => 'fn'))
        end

        it 'returns the users ldap_name_attr and username' do
          expect(subject).to eq(%w[John S])
        end
      end

      # This particular case occurs when a connection is made to the server, and stored in
      # @@ldap_search_con but then the server closes the connection. UserLdapStrategy has no way of
      # knowing if the connection was closed by the server so we need to make sure that
      # UserLdapStrategy attempts to reconnect.
      context 'when the connection is closed by the server' do
        subject do
          # This attempts to use the LDAP connection which already exists in the class var
          UserLdapStrategy.find_with_ldap('tux', 'tux_password')
        end

        include_context 'setup ldap mock with user mock'
        include_context 'an ldap connection'
        include_context 'mock searching a user' do
          let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'tux', 'sn' => %w[John Smith] }) }
        end

        before do
          times_called = 0
          # First time LDAP works, second time is raises an error, third time it works etc.
          allow(ldap_mock).to receive(:search) do
            raise StandardError if times_called == 1

            times_called += 1
          end
          allow(ldap_mock).to receive_messages(err: 'something went wrong', err2string: 'something went wrong')
          allow(ldap_mock).to receive(:unbind)
          # This connects to LDAP and stores the connection in a class var
          UserLdapStrategy.find_with_ldap('tux', 'tux_password')
        end

        it { is_expected.to eq(%w[John tux]) }
      end
    end
  end
end
