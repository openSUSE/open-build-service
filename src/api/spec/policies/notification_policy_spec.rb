require 'rails_helper'

RSpec.describe NotificationPolicy do
  describe NotificationPolicy::Scope do
    let(:user_nobody) { build(:user_nobody) }

    it "doesn't permit anonymous user" do
      expect { described_class.new(user_nobody, Notification.none) }
        .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :anonymous_user)))
    end
  end
end
