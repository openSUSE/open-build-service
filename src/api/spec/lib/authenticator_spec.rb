require 'rails_helper'
require 'authenticator'
require 'gssapi'

RSpec.describe Authenticator do
  let(:gssapi_mock) { double(:gssapi) }

  before do
    stub_const('CONFIG', CONFIG.merge({
      'kerberos_service_principal' => 'HTTP/obs.test.com@test_realm.com',
      'kerberos_realm'             => 'test_realm.com',
      'kerberos_mode'              => true,
      'kerberos_keytab'            => '/etc/keytab'
    }))
  end

  describe '#extract_user' do
    context 'in kerberos mode' do
      let(:request_mock) { double(:request, env: { 'Authorization' => 'Negotiate'}) }
      let(:session_mock) { double(:session) }
      let(:response_mock) { double(:response, headers: {} ) }

      before do
        allow(session_mock).to receive(:[]).with(:login)
      end

      context 'with an invalid ticket' do
        let(:authenticator) { Authenticator.new(request_mock, session_mock, response_mock) }

        it 'raises an error' do
          expect { authenticator.extract_user }.to raise_error(Authenticator::AuthenticationRequiredError,
                                                               'GSSAPI negotiation failed.')
        end
      end

      context 'with a valid ticket' do
        let(:user) { create(:confirmed_user) }
        let(:request_mock) { double(:request, env: { 'Authorization' => "Negotiate #{Base64.strict_encode64('krb_ticket')}" }) }
        let(:authenticator) { Authenticator.new(request_mock, session_mock, response_mock) }

        before do
          allow(gssapi_mock).to receive(:acquire_credentials)
          allow(gssapi_mock).to receive(:accept_context).
            with('krb_ticket').and_return(true)
          allow(gssapi_mock).to receive(:display_name).
            and_return("#{user.login}@test_realm.com")

          allow(GSSAPI::Simple).to receive(:new).with(
            'obs.test.com', 'HTTP', '/etc/keytab'
          ).and_return(gssapi_mock)
        end

        context 'and confirmed user' do
          it 'authenticates the user' do
            authenticator.extract_user
            expect(authenticator.http_user).to eq(user)
          end
        end

        context 'and the user does not exist yet' do
          before do
            user.destroy
          end

          it 'creates a new account' do
            authenticator.extract_user

            new_user = User.where(login: user.login)
            expect(new_user).to exist
            expect(authenticator.http_user).to eq(new_user.first)
          end
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
      end
    end
  end
end
