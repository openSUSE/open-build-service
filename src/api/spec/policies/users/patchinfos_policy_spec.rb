RSpec.describe Users::PatchinfosPolicy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:user_nobody) { build(:user_nobody) }

  permissions :index? do
    it { is_expected.to permit(user, %i[users patchinfos]) }
  end

  it "doesn't permit anonymous user" do
    expect { described_class.new(user_nobody, %i[users patchinfos]) }
      .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :anonymous_user)))
  end
end
