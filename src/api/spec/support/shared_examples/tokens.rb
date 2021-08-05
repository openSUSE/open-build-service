RSpec.shared_examples 'non-active users cannot trigger a token' do
  let(:user) { create(:locked_user, login: 'foo') }

  permissions :trigger? do
    it { expect(subject).not_to permit(user, user_token) }
  end
end

RSpec.shared_examples 'active users can trigger a token' do
  let(:user) { create(:confirmed_user, login: 'foo') }
  let(:project) { create(:project, maintainer: user) }
  let(:package) { create(:package, project: project) }
  let(:other_user) { create(:confirmed_user, login: 'bar') }

  permissions :trigger? do
    it { expect(subject).to permit(user, user_token) }
    it { expect(subject).not_to permit(other_user, user_token) }
  end
end
