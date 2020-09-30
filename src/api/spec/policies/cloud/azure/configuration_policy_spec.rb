require 'rails_helper'

RSpec.describe Cloud::Azure::ConfigurationPolicy do
  let(:user) { create(:user) }
  let(:other_user) { build(:user) }
  let(:user_nobody) { build(:user_nobody) }
  let(:azure_configuration) { create(:azure_configuration, :skip_encrypt_credentials, user: user) }

  subject { described_class }

  permissions :show?, :update?, :destroy? do
    it { is_expected.to permit(user, azure_configuration) }
    it { is_expected.not_to permit(other_user, azure_configuration) }
  end

  it "doesn't permit anonymous user" do
    expect { described_class.new(user_nobody, azure_configuration) }
      .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :anonymous_user)))
  end
end
