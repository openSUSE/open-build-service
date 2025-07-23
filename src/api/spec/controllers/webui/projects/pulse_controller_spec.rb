RSpec.describe Webui::Projects::PulseController do
  let(:project) { create(:project, name: 'pulse_project') }
  let(:package) { create(:package_with_file, name: 'pulse_package', project: project) }
  let(:first_user) { create(:confirmed_user) }
  let(:second_user) { create(:confirmed_user) }

  describe '#show' do
    render_views

    subject { get :show, format: :html, params: { project_name: project.name } }

    let(:default_from) { 1.week.ago.beginning_of_day }
    let(:default_to) { 0.days.ago.end_of_day }

    before do
      subject
    end

    it 'assigns the correct default date range' do
      expect(controller.instance_variable_get(:@date_range_from)).to eq(default_from)
      expect(controller.instance_variable_get(:@date_range_to)).to eq(default_to)
    end

    context 'with date range parameters' do
      subject { get :show, format: :html, params: { project_name: project.name, from: '1899-02-04', to: '2004-05-08' } }

      it 'assigns the correct date range' do
        expect(controller.instance_variable_get(:@date_range_from)).to eq(DateTime.parse('1899-02-04').beginning_of_day)
        expect(controller.instance_variable_get(:@date_range_to)).to eq(DateTime.parse('2004-05-08').end_of_day)
      end
    end

    context 'with non-sensical date range parameters' do
      subject { get :show, format: :html, params: { project_name: project.name, from: '2025-07-08', to: '1899-02-04' } }

      it { expect(flash[:error]).to eq('From newer than To, using default time range') }

      it 'assigns the default date range' do
        expect(controller.instance_variable_get(:@date_range_from)).to eq(default_from)
        expect(controller.instance_variable_get(:@date_range_to)).to eq(default_to)
      end
    end

    context 'show an error message if From|To dates are not in a valid format' do
      subject { get :show, format: :html, params: { project_name: project.name, from: '2025-07-08', to: '5358-30-46' } }

      it { expect(flash[:error]).to eq('From or To dates are not in a valid format, using default time range') }

      it 'assigns the default date range' do
        expect(controller.instance_variable_get(:@date_range_from)).to eq(default_from)
        expect(controller.instance_variable_get(:@date_range_to)).to eq(default_to)
      end
    end
  end
end
