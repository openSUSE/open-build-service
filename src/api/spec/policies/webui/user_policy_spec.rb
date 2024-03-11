RSpec.describe Webui::UserPolicy do
  subject { described_class }

  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:user_nobody) { build(:user_nobody) }

  permissions :index?, :edit?, :destroy?, :change_password?, :edit_account? do
    it { expect(subject).to permit(user, other_user) }
  end

  it "doesn't permit anonymous user" do
    expect { described_class.new(user_nobody, user) }
      .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :anonymous_user)))
  end

  context 'when the configuration allows to edit accounts' do
    let(:configuration) { Configuration.first }

    before do
      allow(configuration).to receive(:accounts_editable?).and_return(true)
      allow(Configuration).to receive(:first).and_return(configuration)
    end

    context 'for a user with moderator role' do
      let(:moderator) { create(:moderator) }

      permissions :block_commenting? do
        it { is_expected.to permit(moderator, other_user) }
      end

      permissions :update? do
        it { is_expected.not_to permit(moderator, other_user) }
        it { is_expected.to permit(moderator, moderator) }
      end
    end

    context 'for a user with admin role' do
      let(:admin) { create(:admin_user) }

      permissions :block_commenting? do
        it { is_expected.to permit(admin, other_user) }
      end

      permissions :update? do
        it { is_expected.to permit(admin, other_user) }
      end
    end

    context 'for a regular user' do
      permissions :block_commenting? do
        it { is_expected.not_to permit(user, other_user) }
        it { is_expected.not_to permit(user, user) }
      end

      permissions :update? do
        it { is_expected.not_to permit(user, other_user) }
        it { is_expected.to permit(user, user) }
      end
    end
  end

  context 'when the configuration disallows to edit accounts' do
    let(:configuration) { Configuration.first }

    before do
      allow(configuration).to receive(:accounts_editable?).and_return(false)
      allow(Configuration).to receive(:first).and_return(configuration)
    end

    context 'for a user with moderator role' do
      let(:moderator) { create(:moderator) }

      permissions :block_commenting? do
        it { is_expected.to permit(moderator, other_user) }
      end

      permissions :update? do
        it { is_expected.not_to permit(moderator, other_user) }
        it { is_expected.not_to permit(moderator, moderator) }
      end
    end

    context 'for a user with admin role' do
      let(:admin) { create(:admin_user) }

      permissions :block_commenting? do
        it { is_expected.to permit(admin, other_user) }
      end

      permissions :update? do
        it { is_expected.not_to permit(admin, other_user) }
      end
    end

    context 'for a regular user' do
      permissions :block_commenting? do
        it { is_expected.not_to permit(user, other_user) }
        it { is_expected.not_to permit(user, user) }
      end

      permissions :update? do
        it { is_expected.not_to permit(user, other_user) }
        it { is_expected.not_to permit(user, user) }
      end
    end
  end
end
