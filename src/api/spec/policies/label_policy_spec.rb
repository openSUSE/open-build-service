RSpec.describe LabelPolicy do
  subject { described_class }

  let(:anonymous_user) { create(:user_nobody) }
  let(:another_user) { create(:confirmed_user) }
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user, :with_home) }
  let(:package) { create(:package_with_maintainer, maintainer: user, project: user.home_project) }
  let(:request) { create(:bs_request_with_submit_action, target_package: package) }
  let(:label_template) { create(:label_template, project: user.home_project) }
  let(:package_label) { create(:label, labelable: package, label_template: label_template) }
  let(:request_label) { create(:label, labelable: request, label_template: label_template) }

  before do
    Flipper.enable(:labels)
  end

  permissions :index? do
    it { is_expected.to permit(anonymous_user, [package_label]) }
    it { is_expected.to permit(another_user, [package_label]) }
    it { is_expected.to permit(user, [package_label]) }
    it { is_expected.to permit(admin, [package_label]) }

    it { is_expected.to permit(anonymous_user, [request_label]) }
    it { is_expected.to permit(another_user, [request_label]) }
    it { is_expected.to permit(user, [request_label]) }
    it { is_expected.to permit(admin, [request_label]) }
  end

  permissions :update? do
    it { is_expected.not_to permit(anonymous_user, package) }
    it { is_expected.not_to permit(another_user, package) }
    it { is_expected.to permit(user, package) }
    it { is_expected.to permit(admin, package) }

    it { is_expected.not_to permit(anonymous_user, request) }
    it { is_expected.not_to permit(another_user, request) }
    it { is_expected.to permit(user, request) }
    it { is_expected.to permit(admin, request) }
  end

  permissions :create? do
    it { is_expected.not_to permit(anonymous_user, package.labels.new) }
    it { is_expected.not_to permit(another_user, package.labels.new) }
    it { is_expected.to permit(user, package.labels.new) }
    it { is_expected.to permit(admin, package.labels.new) }

    it { is_expected.not_to permit(anonymous_user, request.labels.new) }
    it { is_expected.not_to permit(another_user, request.labels.new) }
    it { is_expected.to permit(user, request.labels.new) }
    it { is_expected.to permit(admin, request.labels.new) }
  end

  permissions :destroy? do
    it { is_expected.not_to permit(anonymous_user, package_label) }
    it { is_expected.not_to permit(another_user, package_label) }
    it { is_expected.to permit(user, package_label) }
    it { is_expected.to permit(admin, package_label) }

    it { is_expected.not_to permit(anonymous_user, request_label) }
    it { is_expected.not_to permit(another_user, request_label) }
    it { is_expected.to permit(user, request_label) }
    it { is_expected.to permit(admin, request_label) }
  end
end
