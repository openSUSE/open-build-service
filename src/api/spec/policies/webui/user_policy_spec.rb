require 'rails_helper'

RSpec.describe Webui::UserPolicy do
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:user_nobody) { build(:user_nobody) }

  subject { described_class }

  permissions :index?, :edit?, :destroy?, :update?, :change_password?, :edit_account? do
    it { expect(subject).to permit(user, other_user) }
  end

  it "doesn't permit anonymous user" do
    expect { described_class.new(user_nobody, user) }
      .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :anonymous_user)))
  end
end
