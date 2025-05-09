require 'webmock/rspec'

RSpec.describe Webui::LabelsController do
  let(:tom) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_tom) { tom.home_project }
  let(:toms_package) { create(:package, name: 'my_package', project: home_tom) }
  let!(:label_one) { create(:label_template, project: home_tom) }
  let!(:label_two) { create(:label_template, project: home_tom) }
  let!(:label_three) { create(:label_template, project: home_tom) }

  before do
    Flipper.enable(:labels)
    login(tom)
  end

  describe 'PUT update' do
    context 'when creating templates succeeds' do
      before do
        put :update,
            params: { project: home_tom.name, labelable_id: toms_package.id, labelable_type: 'Package',
                      labels: { labels_attributes: [{ label_template_id: label_one.id, _destroy: false },
                                                    { label_template_id: label_two.id, _destroy: true },
                                                    { label_template_id: label_three.id, _destroy: false }] } }
      end

      it 'creates two labels' do
        expect(toms_package.labels.pluck(:label_template_id)).to eq([label_one.id, label_three.id])
      end
    end

    context 'when creating a template with no labels' do
      it 'creates no labels' do
        put :update,
            params: { project: home_tom.name, labelable_id: toms_package.id, labelable_type: 'Package' }

        expect(toms_package.labels.pluck(:label_template_id)).to eq([])
      end
    end
  end
end
