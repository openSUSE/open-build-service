RSpec.describe NotificationCommentPolicy do
  subject { described_class }

  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:notification) { create(:notification_for_package, :web_notification, :build_failure, subscriber: user, delivered: false) }

  permissions :update? do
    it { is_expected.not_to permit(other_user, notification) }
    it { is_expected.to permit(user, notification) }
  end
end
