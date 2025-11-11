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

  describe 'GET autocomplete' do
    let!(:coolest_label) { create(:label_template, name: 'Coolest') }
    let!(:test_label) { create(:label_template, name: 'Test') }
    let!(:great_label) { create(:label_template, name: 'Great') }

    it 'returns list with one matching result' do
      get :autocomplete, params: { term: 'cool' }
      expect(response.parsed_body).to eq(['Coolest'])
    end

    it 'returns list with more than one matching result' do
      get :autocomplete, params: { term: 'est' }
      expect(response.parsed_body).to eq(%w[Test Coolest])
    end

    it 'returns empty list if no match' do
      get :autocomplete, params: { term: 'no_label' }
      expect(response.parsed_body).to eq([])
    end
  end
end
