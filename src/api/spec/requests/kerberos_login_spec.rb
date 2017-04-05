require 'rails_helper'
require 'gssapi'

RSpec.describe 'Kerberos login', vcr: false, type: :request do
  describe 'authentication in kerberos mode' do
    let(:gssapi_mock) { double }
    let(:user) { create(:confirmed_user) }

    before do
      @before = {
        kerberos_service_principal: CONFIG['kerberos_service_principal'],
        kerberos_realm:             CONFIG['kerberos_realm']
      }
      CONFIG['kerberos_service_principal'] = 'HTTP/obs.test.com@test_realm.com'
      CONFIG['kerberos_realm']             = 'test_realm.com'
    end

    after do
      CONFIG['kerberos_service_principal'] = @before[:kerberos_service_principal]
      CONFIG['kerberos_realm'] = @before[:kerberos_realm]
    end

    context 'with valid ticket' do
      before do
        allow(gssapi_mock).to receive(:acquire_credentials)
        allow(gssapi_mock).to receive(:accept_context).
          with('fake_ticket').and_return(true)
        allow(gssapi_mock).to receive(:display_name).
          and_return("#{user.login}@test_realm.com")

        allow(GSSAPI::Simple).to receive(:new).with(
          'obs.test.com', 'HTTP', '/etc/krb5.keytab'
        ).and_return(gssapi_mock)
      end

      context 'and confirmed user' do
        it 'authenticates the user' do
          get "/source.xml", headers: { 'X-HTTP_AUTHORIZATION' => "Negotiate #{Base64.strict_encode64('fake_ticket')}" }
          expect(response).to have_http_status(:success)
        end
      end

      context 'but user is unconfirmed' do
        before do
          user.update(state: 'unconfirmed')
        end

        it 'does not authenticate the user' do
          get "/source.xml", headers: { 'X-HTTP_AUTHORIZATION' => "Negotiate #{Base64.strict_encode64('fake_ticket')}" }
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match('User is registered but not yet approved. Your account is a registered account, ' +
            'but it is not yet approved for the OBS by admin.')
        end
      end

      context 'but for a diferent realm' do
        before do
          allow(gssapi_mock).to receive(:display_name).
            and_return("#{user.login}@my_other_realm.com")

          allow(GSSAPI::Simple).to receive(:new).with(
            'obs.test.com', 'HTTP', '/etc/krb5.keytab'
          ).and_return(gssapi_mock)
        end

        it 'does not authenticate the user' do
          get "/source.xml", headers: { 'X-HTTP_AUTHORIZATION' => "Negotiate #{Base64.strict_encode64('fake_ticket')}" }
          expect(response).to have_http_status(:unauthorized)
          expect(response.body).to match('User authenticated in wrong Kerberos realm.')
        end
      end
    end

    context 'with invalid ticket' do
      before do
        allow(gssapi_mock).to receive(:acquire_credentials).and_raise(GSSAPI::GssApiError)
        allow(GSSAPI::Simple).to receive(:new).with(
          'obs.test.com', 'HTTP', '/etc/krb5.keytab'
        ).and_return(gssapi_mock)
      end

      it 'does not authenticate the user' do
        get "/source.xml", headers: { 'X-HTTP_AUTHORIZATION' => "Negotiate #{Base64.strict_encode64('fake_ticket')}" }
        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to match('Received a GSSAPI exception')
      end
    end
  end
end
