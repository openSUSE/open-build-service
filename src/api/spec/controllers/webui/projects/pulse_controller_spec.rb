RSpec.describe Webui::Projects::PulseController do
  let(:project) { create(:project, name: 'pulse_project') }
  let(:package) { create(:package_with_file, name: 'pulse_package', project: project) }
  let(:first_user) { create(:confirmed_user) }
  let(:second_user) { create(:confirmed_user) }

  describe '#show' do
    render_views

    subject { get :show, format: :html, params: { project_name: project.name } }

    before do
      subject
    end

    it 'assigns the correct default date range' do
      expect(controller.instance_variable_get(:@date_range_from)).to eq(1.week.ago.beginning_of_day)
      expect(controller.instance_variable_get(:@date_range_to)).to eq(0.days.ago.beginning_of_day)
    end

    context 'with date range parameters' do
      subject { get :show, format: :html, params: { project_name: project.name, from: '1899-02-04' } }

      it 'assigns the correct date range' do
        expect(controller.instance_variable_get(:@date_range_from)).to eq(DateTime.parse('1899-02-04'))
        expect(controller.instance_variable_get(:@date_range_to)).to eq(0.days.ago.beginning_of_day)
      end
    end
  end
end
