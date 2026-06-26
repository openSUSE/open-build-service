RSpec.describe ReportPolicy, type: :policy do
  subject { ReportPolicy }

  let(:admin_user) { create(:admin_user) }
  let(:moderator_user) { create(:moderator) }
  let(:staff_user) { create(:staff_user) }
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:report) { create(:report, reporter: user) }

  before do
    Flipper.enable(:content_moderation)
  end

  permissions :show? do
    context 'when the current user is the owner of the report' do
      it { is_expected.to permit(user, report) }
    end

    context 'when the current user is an admin' do
      it { is_expected.to permit(admin_user, report) }
    end

    context 'when the current user is not the owner of the report' do
      it { is_expected.not_to permit(other_user, report) }
    end
  end

  permissions :create? do
    context 'when the current user has already reported it' do
      let(:reported_comment) { create(:comment_package) }
      let(:report) { build(:report, reporter: user, reportable: reported_comment) }

      before do
        create(:report, reporter: user, reportable: reported_comment)
      end

      it { is_expected.not_to(permit(user, report)) }
    end

    context 'when the current user can change the reportable' do
      context 'when reporting a comment' do
        let(:reported_comment) { create(:comment_package, user: user) }
        let(:report) { build(:report, reporter: user, reportable: reported_comment) }

        it { is_expected.not_to(permit(user, report)) }
      end

      context 'when reporting a package' do
        let(:reported_package) { create(:package_with_maintainer, maintainer: user) }
        let(:report) { build(:report, reporter: user, reportable: reported_package) }

        it { is_expected.not_to(permit(user, report)) }
      end

      context 'when reporting a project' do
        let(:reported_project) { create(:project, maintainer: user) }
        let(:report) { build(:report, reporter: user, reportable: reported_project) }

        it { is_expected.not_to(permit(user, report)) }
      end

      context 'when reporting a user' do
        let(:report) { build(:report, reporter: user, reportable: user) }

        it { is_expected.not_to(permit(user, report)) }
      end

      context "when trying to report a report's comment" do
        let(:report_on_package_comment) { create(:report, reporter: user) }
        let(:report_comment) { create(:comment_report, commentable: report_on_package_comment) }
        let(:report) { build(:report, reporter: moderator_user, reportable: report_comment) }

        it { is_expected.not_to(permit(moderator_user, report)) }
      end
    end

    context 'when the current user can not change the reportable' do
      context 'when reporting a comment' do
        let(:comment) { create(:comment_package) }
        let(:report) { build(:report, reporter: user, reportable: comment) }

        it { is_expected.to permit(user, report) }
      end

      context 'when reporting a package' do
        let(:reported_package) { create(:package) }
        let(:report) { build(:report, reporter: user, reportable: reported_package) }

        it { is_expected.to permit(user, report) }
      end

      context 'when reporting a project' do
        let(:reported_project) { create(:project) }
        let(:report) { build(:report, reporter: user, reportable: reported_project) }

        it { is_expected.to permit(user, report) }
      end

      context 'when reporting a user' do
        let(:reported_user) { create(:confirmed_user) }
        let(:report) { build(:report, reporter: user, reportable: reported_user) }

        it { is_expected.to permit(user, report) }
      end
    end
  end

  permissions :notify? do
    it 'notifies the moderator' do
      expect(subject).to permit(moderator_user, report)
    end

    it 'notifies admin users' do
      expect(subject).to permit(admin_user, report)
    end

    it 'notifies staff users' do
      expect(subject).to permit(staff_user, report)
    end

    it 'does not notify the reporter' do
      expect(subject).not_to permit(user, report)
    end

    it 'does not notify users not being the reporter' do
      expect(subject).not_to permit(other_user, report)
    end
  end

  permissions :update? do
    it 'allows admin users to update' do
      expect(subject).to permit(admin_user, report)
    end

    it 'allows moderator to update' do
      expect(subject).to permit(moderator_user, report)
    end

    it 'allows staff users to update' do
      expect(subject).to permit(staff_user, report)
    end

    it 'allows the current user when being the owner of the report to update' do
      expect(subject).to permit(user, report)
    end

    it 'does not allow the current user when not being the owner of the report to update' do
      expect(subject).not_to permit(other_user, report)
    end
  end

  permissions :destroy? do
    it 'allows admin users to delete' do
      expect(subject).to permit(admin_user, report)
    end

    it 'allows moderator to delete' do
      expect(subject).to permit(moderator_user, report)
    end

    it 'allows staff users to delete' do
      expect(subject).to permit(staff_user, report)
    end

    it 'allows the current user when being the owner of the report' do
      expect(subject).to permit(user, report)
    end

    it 'does not allow the current user when not being the owner of the report' do
      expect(subject).not_to permit(other_user, report)
    end
  end
end
