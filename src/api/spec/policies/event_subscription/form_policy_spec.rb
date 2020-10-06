require 'rails_helper'

RSpec.describe EventSubscription::FormPolicy do
  let(:user) { create(:user_with_groups) }
  let(:other_user) { create(:user_with_groups) }
  let(:user_nobody) { build(:user_nobody) }
  let(:event_subscription_form) { EventSubscription::Form.new }
  let(:event_subscription_form_user) { EventSubscription::Form.new(user) }

  subject { described_class }

  permissions :index?, :update? do
    it { is_expected.to permit(user, event_subscription_form_user) }
    it { is_expected.to permit(other_user, event_subscription_form) }
    it { is_expected.not_to permit(other_user, event_subscription_form_user) }
  end

  it "doesn't permit anonymous user" do
    expect { described_class.new(user_nobody, event_subscription_form) }
      .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :anonymous_user)))
  end
end
