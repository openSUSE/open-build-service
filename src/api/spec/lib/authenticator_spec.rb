require 'rails_helper'
require 'authenticator'
require 'gssapi'

RSpec.describe Authenticator do
  describe '#extract_user' do
    let(:session_mock) { double(:session) }
    let(:response_mock) { double(:response, headers: {}) }

    before do
      allow(session_mock).to receive(:[]).with(:login)
    end

    context 'in proxy mode' do
      it_behaves_like 'a confirmed user logs in' do
        let(:request_mock) { double(:request, env: { 'HTTP_X_USERNAME' => user.login }) }

        before { stub_const('CONFIG', CONFIG.merge({ 'proxy_auth_mode' => :on })) }
      end
    end

    context 'in ldap mode' do
      it_behaves_like 'a confirmed user logs in' do
        let(:request_mock) { double(:request, env: { 'Authorization' => "Basic #{Base64.encode64("#{user.login}:buildservice")}" }) }

        before do
          stub_const('CONFIG', CONFIG.merge({ 'ldap_mode' => :on }))
          allow(UserLdapStrategy).to receive(:find_with_ldap).and_return([user.email, user.realname])
        end
      end
    end

    context 'in basic authentication mode' do
      it_behaves_like 'a confirmed user logs in' do
        let(:request_mock) { double(:request, env: { 'Authorization' => "Basic #{Base64.encode64("#{user.login}:buildservice")}" }) }
      end
    end

    context 'in kerberos mode' do
      let(:request_mock) { double(:request, env: { 'Authorization' => 'Negotiate' }) }

      before do
        stub_const('CONFIG', CONFIG.merge({
          'kerberos_service_principal' => 'HTTP/obs.test.com@test_realm.com',
          'kerberos_realm'             => 'test_realm.com',
          'kerberos_mode'              => true,
          'kerberos_keytab'            => '/etc/krb5.keytab'
        }))
      end

      context 'with an invalid ticket' do
        let(:authenticator) { Authenticator.new(request_mock, session_mock, response_mock) }

        it 'raises an error' do
          expect { authenticator.extract_user }.to raise_error(Authenticator::AuthenticationRequiredError,
                                                               'GSSAPI negotiation failed.')
        end
      end

      context 'with a valid ticket' do
        let(:user) { create(:confirmed_user, login: 'kerberos_user') }
        let(:request_mock) { double(:request, env: { 'Authorization' => "Negotiate #{Base64.strict_encode64('krb_ticket')}" }) }
        let(:authenticator) { Authenticator.new(request_mock, session_mock, response_mock) }

        include_context 'a kerberos mock for' do
          let(:ticket) { 'krb_ticket' }
          let(:login) { user.login }
        end

        it_behaves_like 'a confirmed user logs in'

        context 'and the user does not exist yet' do
          before do
            user.destroy
            authenticator.extract_user
          end

          it 'creates a new account' do
            new_user = User.where(login: user.login)
            expect(new_user).to exist
            expect(authenticator.http_user).to eq(new_user.first)
          end

          it { expect(authenticator.http_user.last_logged_in_at).to be_within(30.seconds).of(Time.now) }
        end

        context 'but user is unconfirmed' do
          before do
            user.update(state: 'unconfirmed')
          end

          it 'does not authenticate the user' do
            expect { authenticator.extract_user }.to raise_error(Authenticator::UnconfirmedUserError,
                                                                 'User is registered but not yet approved. Your account is a registered account, ' +
                                                                 'but it is not yet approved for the OBS by admin.')
          end
        end

        context 'without kerberos_realm being set' do
          before do
            stub_const('CONFIG', CONFIG.merge({ 'kerberos_realm' => nil }))
            authenticator.extract_user
          end

          it { expect(CONFIG['kerberos_realm']).to eq('test_realm.com') }
        end

        context 'without kerberos_service_principal being set' do
          it 'without kerberos_service_principal key' do
            stub_const('CONFIG', CONFIG.merge({ 'kerberos_service_principal' => nil }))
            expect { authenticator.extract_user }.to raise_error(Authenticator::AuthenticationRequiredError,
                                                                 'Kerberos configuration is broken. Principal is empty.')
          end

          it 'with kerberos_service_principal being set to empty string' do
            stub_const('CONFIG', CONFIG.merge({ 'kerberos_service_principal' => '' }))
            expect { authenticator.extract_user }.to raise_error(Authenticator::AuthenticationRequiredError,
                                                                 'Kerberos configuration is broken. Principal is empty.')
          end
        end

        context 'with a user authenticated in wrong Kerberos realm' do
          before { allow(gssapi_mock).to receive(:display_name).and_return("tux@fake_realm") }

          it 'trows an exception' do
            expect { authenticator.extract_user }.to raise_error(Authenticator::AuthenticationRequiredError,
                                                                 'User authenticated in wrong Kerberos realm.')
          end
        end

        context 'the token is part of a continuation' do
          before do
            allow(gssapi_mock).to receive(:accept_context).and_return(SecureRandom.hex)
            authenticator.extract_user
          end

          it 'sets the according response header' do
            expect(response_mock.headers).to include('WWW-Authenticate')
          end
        end
      end
    end
  end
end
