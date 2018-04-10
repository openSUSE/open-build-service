# frozen_string_literal: true

RSpec.shared_examples 'a confirmed user logs in' do
  let(:user) { create(:confirmed_user) }
  let(:authenticator) { Authenticator.new(request_mock, session_mock, response_mock) }

  context 'with a confirmed user' do
    before do
      authenticator.extract_user
    end

    it { expect(authenticator.http_user).to eq(user) }
    it { expect(authenticator.http_user.last_logged_in_at).to be_within(30.seconds).of(Time.now) }
  end
end
