require 'rails_helper'

RSpec.describe ReportPolicy, type: :policy do
  subject { ReportPolicy }

  let(:user) { create(:confirmed_user) }

  permissions :show? do
    context 'when the current user is the owner of the report' do
      let(:report) { create(:report, user: user) }

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
    before do
      Flipper.enable(:content_moderation, user)
    end

    context 'when the current user has already reported it' do
      let(:reported_comment) { create(:comment_package) }
      let(:report) { build(:report, user: user, reportable: reported_comment) }

      before do
        create(:report, user: user, reportable: reported_comment)
      end

      it { is_expected.not_to(permit(user, report)) }
    end

    context 'when the current user can change the reportable' do
      context 'when reporting a comment' do
        let(:reported_comment) { create(:comment_package, user: user) }
        let(:report) { build(:report, user: user, reportable: reported_comment) }

        it { is_expected.not_to(permit(user, report)) }
      end

      context 'when reporting a package' do
        let(:reported_package) { create(:package_with_maintainer, maintainer: user) }
        let(:report) { build(:report, user: user, reportable: reported_package) }

        it { is_expected.not_to(permit(user, report)) }
      end

      context 'when reporting a project' do
        let(:reported_project) { create(:project, maintainer: user) }
        let(:report) { build(:report, user: user, reportable: reported_project) }

        it { is_expected.not_to(permit(user, report)) }
      end

      context 'when reporting a user' do
        let(:report) { build(:report, user: user, reportable: user) }

        it { is_expected.not_to(permit(user, report)) }
      end
    end

    context 'when the current user can not change the reportable' do
      context 'when reporting a comment' do
        let(:comment) { create(:comment_package) }
        let(:report) { build(:report, user: user, reportable: comment) }

        it { is_expected.to permit(user, report) }
      end

      context 'when reporting a package' do
        let(:reported_package) { create(:package) }
        let(:report) { build(:report, user: user, reportable: reported_package) }

        it { is_expected.to permit(user, report) }
      end

      context 'when reporting a project' do
        let(:reported_project) { create(:project) }
        let(:report) { build(:report, user: user, reportable: reported_project) }

        it { is_expected.to permit(user, report) }
      end

      context 'when reporting a user' do
        let(:reported_user) { create(:confirmed_user) }
        let(:report) { build(:report, user: user, reportable: reported_user) }

        it { is_expected.to permit(user, report) }
      end
    end
  end
end
