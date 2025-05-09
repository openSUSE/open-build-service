RSpec.describe Label do
  let(:source_package) { create(:package) }
  let(:target_package) { create(:package) }
  let(:bs_request) { create(:bs_request_with_submit_action, source_project: source_package.project, source_package: source_package, target_project: target_package.project, target_package: target_package) }
  let(:package) { create(:package) }
  let(:label_template) { create(:label_template, project: package.project) }

  describe '#validate_labelable_label_template_association' do
    context 'when labelable and label_template are not associated' do
      let!(:label) { build(:label, labelable: bs_request, label_template: label_template) }

      it 'adds an error' do
        expect(label.valid?).to be(false)
        expect(label.errors.messages[:base].include?('Labelable and LabelTemplate are not associated')).to be(true)
      end
    end

    context 'when labelable and label_template are associated' do
      let(:label) { build(:label, labelable: package, label_template: label_template) }

      it 'creates the label' do
        expect(label.valid?).to be(true)
      end
    end
  end
end
