RSpec.describe EventSubscription::FormPolicy do
  subject { described_class }

  let(:user) { create(:user_with_groups) }
  let(:other_user) { create(:user_with_groups) }
  let(:event_subscription_form_user) { EventSubscription::Form.new(user) }

  permissions :update? do
    it { is_expected.to permit(user, event_subscription_form_user) }
    it { is_expected.not_to permit(other_user, event_subscription_form_user) }
  end
end
