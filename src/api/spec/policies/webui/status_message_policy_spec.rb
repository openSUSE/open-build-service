require 'rails_helper'

RSpec.describe Webui::StatusMessagePolicy do
  let(:user_nobody) { create(:user_nobody) }
  let(:user) { create(:confirmed_user) }
  let(:staff_user) { create(:staff_user) }
  let(:admin_user) { create(:admin_user) }
  let(:status_message) { create(:status_message) }

  subject { described_class }

  # rubocop:disable RSpec/RepeatedExample
  # This cop is currently not recognizing the permissions block as separate test
  permissions :acknowledge? do
    it { is_expected.to permit(user, status_message) }
    it { is_expected.to permit(staff_user, status_message) }
    it { is_expected.to permit(admin_user, status_message) }
  end

  permissions :new?, :create?, :edit?, :update?, :destroy? do
    it { is_expected.not_to permit(user, status_message) }
    it { is_expected.to permit(staff_user, status_message) }
    it { is_expected.to permit(admin_user, status_message) }
  end
  # rubocop:enable RSpec/RepeatedExample

  it "doesn't permit anonymous user" do
    expect { described_class.new(user_nobody, status_message) }
      .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: ApplicationPolicy::ANONYMOUS_USER)))
  end
end
