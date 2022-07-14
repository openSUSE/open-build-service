require 'rails_helper'

RSpec.describe Token::ServicePolicy do
  subject { described_class }

  describe '#trigger' do
    context 'user inactive' do
      let(:user_token) { create(:service_token, executor: user) }

      include_examples 'non-active users cannot trigger a token'
    end

    context 'user active' do
      let(:user_token) { create(:service_token, executor: user, package: package) }
      let(:other_user_token) { create(:service_token, executor: other_user) }

      include_examples 'active users can trigger a token'
    end
  end
end
