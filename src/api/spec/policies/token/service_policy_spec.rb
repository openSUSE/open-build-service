RSpec.describe Token::ServicePolicy do
  subject { described_class }

  describe '#trigger' do
    context 'user inactive' do
      let(:user_token) { create(:service_token, executor: user) }

      it_behaves_like 'non-active users cannot trigger a token'
    end

    context 'user active' do
      let(:user_token) { create(:service_token, executor: user, package: package) }
      let(:other_user_token) { create(:service_token, executor: other_user) }

      it_behaves_like 'active users can trigger a token'
    end
  end
end
