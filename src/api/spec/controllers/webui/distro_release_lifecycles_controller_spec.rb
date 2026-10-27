RSpec.describe Webui::DistroReleaseLifecyclesController do
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:project) { create(:project, maintainer: user) }
  let(:vendor) { create(:vendor, project: project) }
  let(:distro) { create(:distro, vendor: vendor, name: 'Leap') }
  let(:distro_release) { create(:distro_release, distro: distro, name: '16.0') }
  let(:release_path) { project_distro_release_path(project.name, distro.name, distro_release.name) }
  let(:route_params) { { project_name: project.name, distro_name: distro.name, distro_release_name: distro_release.name } }

  it { is_expected.to use_after_action(:verify_authorized) }

  describe 'POST #create' do
    subject { post :create, params: route_params.merge(distro_release_lifecycle: lifecycle_params) }

    let(:lifecycle_params) { { name: 'GA', date: '2026-06-01', status: 'general_availability' } }

    context 'as a project maintainer' do
      before do
        login user
      end

      context 'with valid parameters' do
        it { expect { subject }.to change(DistroReleaseLifecycle, :count).by(1) }

        it 'assigns the lifecycle to the release from the URL' do
          subject
          expect(DistroReleaseLifecycle.last).to have_attributes(distro_release: distro_release, name: 'GA',
                                                                 date: Date.new(2026, 6, 1), status: 'general_availability')
        end

        it 'redirects to the release' do
          subject
          expect(response).to redirect_to(release_path)
        end

        it 'sets a success flash' do
          subject
          expect(flash[:success]).to eq('Lifecycle was successfully created.')
        end
      end

      context 'with a name already taken within the same release' do
        before do
          create(:distro_release_lifecycle, distro_release: distro_release, name: 'GA')
        end

        it { expect { subject }.not_to change(DistroReleaseLifecycle, :count) }

        it 'sets a human readable error flash' do
          subject
          expect(flash[:error]).to eq('Lifecycle failed to create. Name has already been taken')
        end
      end

      context 'without a date' do
        let(:lifecycle_params) { { name: 'GA', date: '', status: 'general_availability' } }

        it { expect { subject }.not_to change(DistroReleaseLifecycle, :count) }

        it 'redirects to the release' do
          subject
          expect(response).to redirect_to(release_path)
        end
      end
    end

    context 'as a user without permission' do
      before do
        login other_user
      end

      it { expect { subject }.not_to change(DistroReleaseLifecycle, :count) }

      it 'responds with a found status and sets an error flash' do
        subject
        expect(response).to have_http_status(:found)
        expect(flash[:error]).to eq('Sorry, you are not authorized to create this distro release lifecycle.')
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: route_params.merge(lifecycle_name: lifecycle.name, distro_release_lifecycle: lifecycle_params) }

    let!(:lifecycle) { create(:distro_release_lifecycle, distro_release: distro_release, name: 'Beta', status: :beta) }
    let(:lifecycle_params) { { status: 'release_candidate' } }

    context 'as a project maintainer' do
      before do
        login user
      end

      it 'updates the lifecycle' do
        subject
        expect(lifecycle.reload.status).to eq('release_candidate')
      end

      it 'sets a success flash' do
        subject
        expect(flash[:success]).to eq('Lifecycle was successfully updated.')
      end
    end

    context 'as a user without permission' do
      before do
        login other_user
      end

      it { expect { subject }.not_to(change { lifecycle.reload.status }) }

      it 'responds with a found status and sets an error flash' do
        subject
        expect(response).to have_http_status(:found)
        expect(flash[:error]).to eq('Sorry, you are not authorized to update this distro release lifecycle.')
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: route_params.merge(lifecycle_name: lifecycle.name) }

    let!(:lifecycle) { create(:distro_release_lifecycle, distro_release: distro_release) }

    context 'as a project maintainer' do
      before do
        login user
      end

      it { expect { subject }.to change(DistroReleaseLifecycle, :count).by(-1) }

      it 'redirects to the release' do
        subject
        expect(response).to redirect_to(release_path)
      end
    end

    context 'as a user without permission' do
      before do
        login other_user
      end

      it { expect { subject }.not_to change(DistroReleaseLifecycle, :count) }

      it 'responds with a found status and sets an error flash' do
        subject
        expect(response).to have_http_status(:found)
        expect(flash[:error]).to eq('Sorry, you are not authorized to delete this distro release lifecycle.')
      end
    end
  end
end
