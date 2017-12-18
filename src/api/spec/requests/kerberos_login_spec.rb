require 'rails_helper'
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

      context "authorization header contains 'Negotiate' with a valid ticket" do
        include_context 'a kerberos mock for' do
          let(:login) { user.login }
        end

        before do
          get "/source.xml", headers: { 'X-HTTP_AUTHORIZATION' => "Negotiate #{Base64.strict_encode64(ticket)}" }
        end

        it { expect(response).to have_http_status(:success) }
      end

      context "authorization header contains 'Negotiate' with an invalid ticket" do
        include_context 'a kerberos mock for' do
          let(:login) { user.login }
        end

        before do
          get "/source.xml", headers: { 'X-HTTP_AUTHORIZATION' => "Negotiate INVALID_TICKET" }
        end

        it { expect(response).to have_http_status(:unauthorized) }
        it { expect(response.body).to match('Received invalid GSSAPI context') }
      end
    end
  end
end
