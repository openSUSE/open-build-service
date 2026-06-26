RSpec.describe LabelTemplateGlobalPolicy do
  subject { described_class }

  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }
  let(:label_template_global) { create(:label_template_global) }

  before do
    Flipper.enable(:labels)
  end

  permissions :index?, :create?, :new? do
    it { is_expected.not_to permit(user, LabelTemplateGlobal) }
    it { is_expected.to permit(admin, LabelTemplateGlobal) }
  end

  permissions :update?, :destroy?, :edit? do
    it { is_expected.not_to permit(user, label_template_global) }
    it { is_expected.to permit(admin, label_template_global) }
  end
end
