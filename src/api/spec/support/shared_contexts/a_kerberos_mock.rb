# frozen_string_literal: true

RSpec.shared_context 'a kerberos mock for' do
  let(:gssapi_mock) { double(:gssapi) }
  let(:ticket) { SecureRandom.hex }
  let(:realm) { 'test_realm.com' }
  let(:login) { 'tux' }

  before do
    allow(GSSAPI::Simple).to receive(:new).with(
      'obs.test.com', 'HTTP', '/etc/krb5.keytab'
    ).and_return(gssapi_mock)

    allow(gssapi_mock).to receive(:acquire_credentials)
    allow(gssapi_mock).to receive(:accept_context).
      with(ticket).and_return(true)
    allow(gssapi_mock).to receive(:display_name).
      and_return("#{login}@#{realm}")
  end
end
