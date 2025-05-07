RSpec.describe LabelTemplatePolicy do
  subject { described_class }

  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project, maintainer: user) }
  let(:label_template) { create(:label_template, project: project) }
  let(:another_user) { create(:confirmed_user) }

  before do
    Flipper.enable(:labels)
  end

  permissions :index?, :create?, :new?, :update?, :destroy?, :edit? do
    it { is_expected.to permit(user, label_template) }
    it { is_expected.not_to permit(another_user, label_template) }
  end
end
