require 'rails_helper'

RSpec.describe Users::PatchinfosPolicy do
  let(:user) { create(:user) }
  let(:user_nobody) { build(:user_nobody) }

  subject { described_class }

  permissions :index? do
    it { is_expected.to permit(user, [:users, :patchinfos]) }
  end

  it "doesn't permit anonymous user" do
    expect { described_class.new(user_nobody, [:users, :patchinfos]) }
      .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :anonymous_user)))
  end
end
