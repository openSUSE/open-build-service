RSpec.describe Webui::Projects::PulseController do
  let(:project) { create(:project, name: 'pulse_project') }
  let(:package) { create(:package_with_file, name: 'pulse_package', project: project) }
  let(:first_user) { create(:confirmed_user) }
  let(:second_user) { create(:confirmed_user) }

  describe '#show' do
    render_views

    before do
      get :show, format: :html, params: { project_name: project.name }
    end

    it 'load the whole page' do
      expect(response.body).to have_css('#range-header')
      expect(response.body).to have_css('#pulse')
    end

    it 'assigns the correct instance variables' do
      expect(controller.instance_variable_get(:@range)).to eq('week')
      expect(controller.instance_variable_get(:@builds)).to be_nil
    end
  end
end
