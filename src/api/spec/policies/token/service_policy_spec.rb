require 'rails_helper'

RSpec.describe Token::ServicePolicy do
  subject { described_class }

  describe '#create' do
    context 'user inactive' do
      let(:user_token) { create(:service_token, :with_package_from_association_or_param, user: user) }

      include_examples 'non-active users cannot use a token'
    end

    context 'user active' do
      let(:user_token) { create(:service_token, :with_package_from_association_or_param, user: user, package: package) }
      let(:other_user_token) { create(:service_token, :with_package_from_association_or_param, user: other_user) }

      include_examples 'active users token basic tests'
    end
  end
end
