RSpec.describe Webui::ArchitecturesController, :js do
  let(:admin_user) { create(:admin_user) }

  before do
    login(admin_user)
  end

  it { is_expected.to use_before_action(:require_admin) }

  describe 'GET #index' do
    before do
      get :index
    end

    it { expect(assigns(:architectures)).to match_array(Architecture.all) }
  end

  describe 'PATCH #update' do
    let(:arch) { Architecture.find_by(name: 'x86_64') }

    context 'enabling availability' do
      before do
        arch.update!(available: false)

        patch :update, params: { id: arch.id, available: 'true', format: :js }
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(flash[:success]).to eq("Updated architecture 'x86_64'") }
      it { expect(arch.reload).to have_attributes(available: true) }
    end

    context 'disabling availability' do
      before do
        arch.update!(available: true)

        patch :update, params: { id: arch.id, available: 'false', format: :js }
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(flash[:success]).to eq("Updated architecture 'x86_64'") }
      it { expect(arch.reload).to have_attributes(available: false) }
    end
  end

  describe 'POST #bulk_update_availability' do
    context 'with valid data' do
      before do
        post :bulk_update_availability, params: { archs: { i586: '0', s390x: '1' } }
      end

      it { expect(response).to redirect_to(architectures_path) }
      it { expect(flash[:success]).to eq('Architectures successfully updated.') }
      it { expect(Architecture.find_by_name('i586').available).to be_falsey }
      it { expect(Architecture.find_by_name('s390x').available).to be_truthy }
    end

    context 'with valid data but failing to save' do
      before do
        allow_any_instance_of(Architecture).to receive(:valid?).and_return(false)
        request.env['HTTP_REFERER'] = root_url # Needed for the redirect_to :back
        post :bulk_update_availability, params: { archs: { i586: '1', s390x: '1' } }
      end

      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).to eq('Not all architectures could be saved') }
    end
  end
end
