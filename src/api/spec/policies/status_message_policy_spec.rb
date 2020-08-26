require 'rails_helper'

RSpec.describe StatusMessagePolicy do
  let(:anonymous_user) { create(:user_nobody) }
  let(:user) { create(:confirmed_user) }
  let(:staff_user) { create(:staff_user) }
  let(:admin_user) { create(:admin_user) }
  let(:status_message) { create(:status_message) }

  subject { StatusMessagePolicy }

  # rubocop:disable RSpec/RepeatedExample
  # This cop is currently not recognizing the permissions block as separate test
  permissions :index?, :show? do
    it { is_expected.to permit(anonymous_user, status_message) }
    it { is_expected.to permit(user, status_message) }
    it { is_expected.to permit(staff_user, status_message) }
    it { is_expected.to permit(admin_user, status_message) }
  end

  permissions :new?, :create?, :update?, :destroy? do
    it { is_expected.not_to permit(anonymous_user, status_message) }
    it { is_expected.not_to permit(user, status_message) }
    it { is_expected.to permit(staff_user, status_message) }
    it { is_expected.to permit(admin_user, status_message) }
  end
  # rubocop:enable RSpec/RepeatedExample
end
