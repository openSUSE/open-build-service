require 'rails_helper'
require 'authenticator'
require 'gssapi'

RSpec.describe 'Kerberos login', vcr: false, type: :request do
  describe 'authentication in kerberos mode' do
    let(:user) { create(:confirmed_user) }

    before do
      stub_const('CONFIG', CONFIG.merge({
        'kerberos_service_principal' => 'HTTP/obs.test.com@test_realm.com',
        'kerberos_realm'             => 'test_realm.com',
        'kerberos_mode'              => true
      }))
    end

    context "calling a controller with 'extract_user' before filter" do
      context "authorization header does not contain 'Negotiate'" do
        before do
          get "/source.xml"
        end

        it { expect(response).to have_http_status(:unauthorized) }
        it { expect(response.header["WWW-Authenticate"]).to eq('Negotiate') }
      end

      context "authorization header contains 'Negotiate' with a ticket" do
        let(:gssapi_mock) { double(:gssapi) }

        before do
          allow(gssapi_mock).to receive(:acquire_credentials)
          allow(gssapi_mock).to receive(:accept_context).
            with('ticket').and_return(true)
          allow(gssapi_mock).to receive(:display_name).
            and_return("#{user.login}@test_realm.com")

          allow(GSSAPI::Simple).to receive(:new).with(
            'obs.test.com', 'HTTP', '/etc/krb5.keytab'
          ).and_return(gssapi_mock)
        end

        it 'authenticates the user' do
          get "/source.xml", headers: { 'X-HTTP_AUTHORIZATION' => "Negotiate #{Base64.strict_encode64('ticket')}" }
          expect(response).to have_http_status(:success)
        end
      end

      context 'authenticator raises an error while fetching user' do
        let(:auth_header) { "Negotiate #{Base64.strict_encode64('ticket')}" }

        before do
          allow_any_instance_of(Authenticator).to receive(:extract_krb_user).
            with(auth_header.to_s.split).
            and_raise(Authenticator::AuthenticationRequiredError, 'something happened')
        end

        it 'does not authenticate the user' do
          get "/source.xml", headers: { 'X-HTTP_AUTHORIZATION' => auth_header }
          expect(response).to have_http_status(:unauthorized)
          expect(response.body).to match('something happened')
        end
      end
    end
  end
end
