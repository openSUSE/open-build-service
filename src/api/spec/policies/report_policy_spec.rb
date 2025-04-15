RSpec.describe ReportPolicy, type: :policy do
  subject { ReportPolicy }

  let(:user) { create(:confirmed_user) }

  before do
    Flipper.enable(:content_moderation)
  end

  permissions :show? do
    context 'when the current user is the owner of the report' do
      let(:report) { create(:report, reporter: user) }

      it { is_expected.to permit(user, report) }
    end

    context 'when the current user is an admin' do
      let(:admin) { create(:admin_user) }
      let(:report) { create(:report) }

      it { is_expected.to permit(admin, report) }
    end

    context 'when the current user is not the owner of the report' do
      let(:report) { create(:report) }

      it { is_expected.not_to permit(user, report) }
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
        let(:moderator) { create(:moderator) }
        let(:report) { build(:report, reporter: moderator, reportable: report_comment) }

        it { is_expected.not_to(permit(moderator, report)) }
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
    let(:staff_user) { create(:staff_user) }
    let(:admin_user) { create(:admin_user) }

    context 'when there is no user with moderator role' do
      it 'notifies admin users' do
        expect(subject).to permit(admin_user, Report)
      end

      it 'notifies staff users' do
        expect(subject).to permit(staff_user, Report)
      end
    end

    context 'when there is a user with moderator role' do
      let!(:moderator_user) { create(:moderator) }

      it 'does not notify admin users' do
        expect(subject).not_to(permit(admin_user, Report))
      end

      it 'does not notify staff users' do
        expect(subject).not_to(permit(staff_user, Report))
      end

      it 'notifies the moderator' do
        expect(subject).to permit(moderator_user, Report)
      end
    end
  end
end
