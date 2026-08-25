RSpec.describe Webui::VendorsController do
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:project) { create(:project, maintainer: user) }
  let(:vendor) { create(:vendor, project: project) }

  before do
    Flipper.enable(:enhanced_distribution_support)
  end

  it { is_expected.to use_after_action(:verify_authorized) }

  describe 'feature toggle' do
    before do
      Flipper.disable(:enhanced_distribution_support)
      login user
      get :new, params: { project_name: project.name }
    end

    it { expect(response).to have_http_status(302) }
  end

  describe 'GET #show' do
    before do
      get :show, params: { project_name: project.name, id: vendor.id }
    end

    it { expect(response).to have_http_status(:success) }
  end

  describe 'GET #new' do
    context 'as a project maintainer' do
      before do
        login user
        get :new, params: { project_name: project.name }
      end

      it { expect(assigns(:vendor).project).to eq(project) }
    end

    context 'as a user without permission' do
      before do
        login other_user
        get :new, params: { project_name: project.name }
      end

      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).to eq('Sorry, you are not authorized to create this vendor.') }
    end
  end

  describe 'GET #edit' do
    context 'as a user without permission' do
      before do
        login other_user
        get :edit, params: { project_name: project.name, id: vendor.id }
      end

      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).to eq('Sorry, you are not authorized to edit this vendor.') }
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { project_name: project.name, vendor: vendor_params } }

    let!(:vendor_params) { { name: 'openSUSE', url: 'https://opensuse.org' } }

    context 'as a project maintainer' do
      before do
        login user
      end

      context 'with valid parameters' do
        it { expect { subject }.to change(Vendor, :count).by(1) }

        it 'assigns the vendor to the project from the URL' do
          subject
          expect(Vendor.last.project).to eq(project)
        end

        it 'redirects to the new vendor' do
          subject
          expect(response).to redirect_to(project_vendor_path(project, Vendor.last))
        end

        it 'sets a success flash' do
          subject
          expect(flash[:success]).to eq('Vendor was successfully created.')
        end
      end

      context 'when the project already has a vendor' do
        let!(:vendor) { create(:vendor, project: project) }

        it { expect { subject }.not_to change(Vendor, :count) }

        it 'renders the new template again' do
          subject
          expect(response).to render_template(:new)
        end
      end
    end

    context 'as a user without permission' do
      before do
        login other_user
      end

      it { expect { subject }.not_to change(Vendor, :count) }

      it 'redirects to the root path' do
        subject
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: { project_name: project.name, id: vendor.id, vendor: vendor_params } }

    context 'as a project maintainer' do
      before do
        login user
      end

      context 'with valid parameters' do
        let(:vendor_params) { { name: 'SUSE' } }

        it 'updates the vendor' do
          subject
          expect(vendor.reload.name).to eq('SUSE')
        end

        it 'sets a success flash' do
          subject
          expect(flash[:success]).to eq('Vendor was successfully updated.')
        end
      end

      context 'with a name exceeding the maximum length' do
        let(:vendor_params) { { name: 'a' * 256 } }

        it { expect { subject }.not_to(change { vendor.reload.name }) }

        it 'renders the edit template again' do
          subject
          expect(response).to render_template(:edit)
        end
      end
    end

    context 'as a user without permission' do
      let(:vendor_params) { { name: 'SUSE' } }

      before do
        login other_user
      end

      it { expect { subject }.not_to(change { vendor.reload.name }) }

      it 'sets an error flash' do
        subject
        expect(flash[:error]).to eq('Sorry, you are not authorized to update this vendor.')
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { project_name: project.name, id: vendor.id } }

    before do
      vendor
    end

    context 'as a project maintainer' do
      before do
        login user
      end

      it { expect { subject }.to change(Vendor, :count).by(-1) }

      it 'redirects to the project' do
        subject
        expect(response).to redirect_to(project_show_path(project))
      end
    end

    context 'as a user without permission' do
      before do
        login other_user
      end

      it { expect { subject }.not_to change(Vendor, :count) }

      it 'sets an error flash' do
        subject
        expect(flash[:error]).to eq('Sorry, you are not authorized to delete this vendor.')
      end
    end
  end
end
