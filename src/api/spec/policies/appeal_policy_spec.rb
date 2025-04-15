RSpec.describe AppealPolicy do
  subject { described_class }

  let(:anonymous_user) { create(:user_nobody) }
  let(:user) { create(:confirmed_user) }
  let(:moderator) { create(:moderator) }
  let(:staff_user) { create(:staff_user) }
  let(:admin_user) { create(:admin_user) }

  context 'with the content_moderation feature disabled' do
    let(:appeal) { create(:appeal) }

    permissions :new?, :show?, :create? do
      it { is_expected.not_to permit(anonymous_user, appeal) }
      it { is_expected.not_to permit(user, appeal) }
      it { is_expected.not_to permit(appeal.appellant, appeal) }
      it { is_expected.not_to permit(moderator, appeal) }
      it { is_expected.not_to permit(staff_user, appeal) }
      it { is_expected.not_to permit(admin_user, appeal) }
    end
  end

  context 'with the content_moderation feature enabled' do
    let(:appellant) { create(:confirmed_user) }
    let(:appeal) { create(:appeal, appellant: appellant) }

    before do
      Flipper.enable(:content_moderation)
    end

    permissions :show? do
      it { is_expected.not_to permit(anonymous_user, appeal) }
      it { is_expected.not_to permit(user, appeal) }
      it { is_expected.to permit(appellant, appeal) }
      it { is_expected.to permit(moderator, appeal) }
      it { is_expected.to permit(staff_user, appeal) }
      it { is_expected.to permit(admin_user, appeal) }
    end

    context 'when the decision cleared a report created by the reporter' do
      let(:report) { create(:report) }
      let(:reporter) { report.reporter }
      let(:decision) { create(:decision_cleared, reports: [report]) }
      let(:appeal) { create(:appeal, decision: decision, appellant: reporter) }

      permissions :create? do
        it { is_expected.not_to permit(anonymous_user, appeal) }
        it { is_expected.not_to permit(user, appeal) }
        it { is_expected.to permit(reporter, appeal) }
        it { is_expected.not_to permit(moderator, appeal) }
        it { is_expected.to permit(staff_user, appeal) }
        it { is_expected.to permit(admin_user, appeal) }
      end
    end

    context 'when the decision is on reports for a now-deleted reportable' do
      let(:report) { create(:report) }
      let(:reporter) { report.reporter }
      let(:decision) { create(:decision_favored, reports: [report]) }
      let(:appeal) { create(:appeal, decision: decision, appellant: reporter) }

      before do
        report.update!(reportable: nil)
      end

      permissions :create? do
        it { is_expected.not_to permit(anonymous_user, appeal) }
        it { is_expected.not_to permit(user, appeal) }
        it { is_expected.not_to permit(reporter, appeal) }
        it { is_expected.not_to permit(moderator, appeal) }
        it { is_expected.not_to permit(staff_user, appeal) }
        it { is_expected.not_to permit(admin_user, appeal) }
      end
    end

    context 'when the decision favored a report created by the reporter' do
      let(:report) { create(:report) }
      let(:reporter) { report.reporter }
      let(:decision) { create(:decision_favored, reports: [report]) }
      let(:appeal) { create(:appeal, decision: decision, appellant: reporter) }

      permissions :create? do
        it { is_expected.not_to permit(anonymous_user, appeal) }
        it { is_expected.not_to permit(user, appeal) }
        it { is_expected.not_to permit(reporter, appeal) }
        it { is_expected.not_to permit(moderator, appeal) }
        it { is_expected.to permit(staff_user, appeal) }
        it { is_expected.to permit(admin_user, appeal) }
      end
    end

    context 'when the decision cleared a report for something the appellant did' do
      let(:report) { create(:report, reportable: create(:comment_package, user: appellant)) }
      let(:decision) { create(:decision_cleared, reports: [report]) }
      let(:appeal) { create(:appeal, decision: decision, appellant: appellant) }

      permissions :create? do
        it { is_expected.not_to permit(anonymous_user, appeal) }
        it { is_expected.not_to permit(user, appeal) }
        it { is_expected.not_to permit(appellant, appeal) }
        it { is_expected.not_to permit(moderator, appeal) }
        it { is_expected.to permit(staff_user, appeal) }
        it { is_expected.to permit(admin_user, appeal) }
      end
    end

    context 'when the decision favored a report for something the appellant did' do
      let(:report) { create(:report, reportable: create(:comment_package, user: appellant)) }
      let(:decision) { create(:decision_favored, reports: [report]) }
      let(:appeal) { create(:appeal, decision: decision, appellant: appellant) }

      permissions :create? do
        it { is_expected.not_to permit(anonymous_user, appeal) }
        it { is_expected.not_to permit(user, appeal) }
        it { is_expected.to permit(appellant, appeal) }
        it { is_expected.not_to permit(moderator, appeal) }
        it { is_expected.to permit(staff_user, appeal) }
        it { is_expected.to permit(admin_user, appeal) }
      end
    end
  end
end
