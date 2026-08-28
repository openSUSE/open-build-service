RSpec.describe Webui::DistrosController do
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:project) { create(:project, maintainer: user) }
  let(:vendor) { create(:vendor, project: project) }
  let(:distro) { create(:distro, vendor: vendor, name: 'Leap') }

  before do
    Flipper.enable(:enhanced_distribution_support)
  end

  it { is_expected.to use_after_action(:verify_authorized) }

  describe 'feature toggle' do
    before do
      Flipper.disable(:enhanced_distribution_support)
      login user
      post :create, params: { vendor_id: vendor.id, distro: { name: 'Tumbleweed' } }
    end

    it { expect(response).to have_http_status(:redirect) }
  end

  describe 'POST #create' do
    subject { post :create, params: { vendor_id: vendor.id, distro: distro_params } }

    let!(:distro_params) { { name: 'Tumbleweed', description: 'A rolling release', url: 'https://get.opensuse.org' } }

    context 'as a project maintainer' do
      before do
        login user
      end

      context 'with valid parameters' do
        it { expect { subject }.to change(Distro, :count).by(1) }

        it 'assigns the distro to the vendor from the URL' do
          subject
          expect(Distro.last.vendor).to eq(vendor)
        end

        it 'redirects to the vendor' do
          subject
          expect(response).to redirect_to(project_vendor_path(project))
        end

        it 'sets a success flash' do
          subject
          expect(flash[:success]).to eq('Distro was successfully created.')
        end
      end

      context 'with a vendor_id pointing at another vendor' do
        let(:other_vendor) { create(:vendor, project: create(:project, maintainer: user)) }
        let(:distro_params) { { vendor_id: other_vendor.id, name: 'Tumbleweed' } }

        it 'ignores the vendor_id from the request body' do
          subject
          expect(Distro.last.vendor).to eq(vendor)
        end
      end

      context 'with a name already taken within the same vendor' do
        before do
          create(:distro, vendor: vendor, name: 'Tumbleweed')
        end

        it { expect { subject }.not_to change(Distro, :count) }

        it 'redirects to the vendor' do
          subject
          expect(response).to redirect_to(project_vendor_path(project))
        end

        it 'sets a human readable error flash' do
          subject
          expect(flash[:error]).to include('Distro failed to create.')
        end
      end
    end

    context 'as a user without permission' do
      before do
        login other_user
      end

      it { expect { subject }.not_to change(Distro, :count) }

      it 'sets an error flash' do
        subject
        expect(flash[:error]).to eq('Sorry, you are not authorized to create this distro.')
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: { vendor_id: vendor.id, id: distro.id, distro: distro_params } }

    let(:distro_params) { { name: 'Slowroll' } }

    context 'as a project maintainer' do
      before do
        login user
      end

      context 'with valid parameters' do
        it 'updates the distro' do
          subject
          expect(distro.reload.name).to eq('Slowroll')
        end

        it 'sets a success flash' do
          subject
          expect(flash[:success]).to eq('Distro was successfully updated.')
        end
      end

      context 'with a name already taken within the same vendor' do
        let(:distro_params) { { name: 'Tumbleweed' } }

        before do
          create(:distro, vendor: vendor, name: 'Tumbleweed')
        end

        it 'redirects to the vendor' do
          subject
          expect(response).to redirect_to(project_vendor_path(project))
        end

        it 'sets a human readable error flash' do
          subject
          expect(flash[:error]).to include('Distro failed to update.')
        end
      end

      context 'when the distro belongs to another vendor' do
        subject { patch :update, params: { vendor_id: vendor.id, id: foreign_distro.id, distro: distro_params } }

        let(:other_vendor) { create(:vendor, project: create(:project, maintainer: user)) }
        let(:foreign_distro) { create(:distro, vendor: other_vendor, name: 'Leap') }

        it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }

        it 'leaves the distro untouched' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
          expect(foreign_distro.reload.name).to eq('Leap')
        end
      end
    end

    context 'as a user without permission' do
      before do
        login other_user
      end

      it { expect { subject }.not_to(change { distro.reload.name }) }

      it 'sets an error flash' do
        subject
        expect(flash[:error]).to eq('Sorry, you are not authorized to update this distro.')
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { vendor_id: vendor.id, id: distro.id } }

    before do
      distro
    end

    context 'as a project maintainer' do
      before do
        login user
      end

      it { expect { subject }.to change(Distro, :count).by(-1) }

      it 'redirects to the vendor' do
        subject
        expect(response).to redirect_to(project_vendor_path(project))
      end
    end

    context 'when the distro belongs to another vendor' do
      subject { delete :destroy, params: { vendor_id: vendor.id, id: foreign_distro.id } }

      let(:other_vendor) { create(:vendor, project: create(:project, maintainer: user)) }
      let!(:foreign_distro) { create(:distro, vendor: other_vendor) }

      before do
        login user
      end

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'as a user without permission' do
      before do
        login other_user
      end

      it { expect { subject }.not_to change(Distro, :count) }

      it 'sets an error flash' do
        subject
        expect(flash[:error]).to eq('Sorry, you are not authorized to delete this distro.')
      end
    end
  end
end
