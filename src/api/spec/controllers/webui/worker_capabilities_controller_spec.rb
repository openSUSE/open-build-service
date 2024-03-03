RSpec.describe Webui::WorkerCapabilitiesController do
  let(:worker_arch) { 'x86_64' }
  let(:worker_id) { '2e3ebc78bc90:1' }
  let(:xml_data) do
    <<~XML
      <worker hostarch="x86_64" registerserver="http://backend:5252" workerid="2e3ebc78bc90:1">
        <hostlabel>OBS_WORKER_SECURITY_LEVEL_</hostlabel>
        <sandbox>chroot</sandbox>
        <linux>
          <version>6.6.12</version>
          <flavor>linuxkit</flavor>
        </linux>
        <hardware>
          <cpu>
            <flag>fp</flag>
          </cpu>
          <processors>10</processors>
          <jobs>1</jobs>
        </hardware>
      </worker>
    XML
  end

  describe 'GET #show' do
    context 'when capabilities exist' do
      before do
        allow(Backend::Api::BuildResults::Worker).to receive(:capabilities).and_return(xml_data)
      end

      it 'renders correctly' do
        get :show, params: { arch: worker_arch, id: worker_id }

        expect(response).to have_http_status(:success)
        expect(response).to render_template('show')
      end

      it 'calls the worker connection correctly' do
        get :show, params: { arch: worker_arch, id: worker_id }

        expect(Backend::Api::BuildResults::Worker).to have_received(:capabilities).with(worker_arch, worker_id)
      end

      it 'assigns worker capabilities' do
        get :show, params: { arch: worker_arch, id: worker_id }

        expect(assigns(:num_of_processors)).to eq('10')
        expect(assigns(:num_of_jobs)).to eq('1')
      end
    end

    context 'when no capabilities exist' do
      before do
        allow(Backend::Api::BuildResults::Worker).to receive(:capabilities).and_return(nil)
      end

      it 'renders a page with no data' do
        get :show, params: { arch: worker_arch, id: worker_id }

        expect(response).to have_http_status(:success)
        expect(response).to render_template('show')
      end

      it 'calls the worker connection correctly' do
        get :show, params: { arch: worker_arch, id: worker_id }

        expect(Backend::Api::BuildResults::Worker).to have_received(:capabilities).with(worker_arch, worker_id)
      end

      it 'assigns worker capabilities' do
        get :show, params: { arch: worker_arch, id: worker_id }

        expect(assigns(:num_of_processors)).to be_nil
        expect(assigns(:num_of_jobs)).to be_nil
      end
    end
  end
end
