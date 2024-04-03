RSpec.describe Webui::WorkerCapabilitiesController, :vcr do
  let(:worker_arch) { 'x86_64' }
  let(:worker_id) { '26704de63694:1' }

  describe 'GET #show' do
    subject! { get :show, params: { arch: worker_arch, id: worker_id } }

    it { is_expected.to have_http_status(:success) }

    it 'assigns worker capabilities' do
      expect(assigns(:num_of_processors)).to eq('4')
      expect(assigns(:num_of_jobs)).to eq('1')
    end
  end
end
