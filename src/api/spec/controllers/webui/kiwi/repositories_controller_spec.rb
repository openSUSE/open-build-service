require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::Kiwi::RepositoriesController, type: :controller, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:kiwi_image_with_package_with_kiwi_file) do
    create(:kiwi_image_with_package, name: 'package_with_valid_kiwi_file', project: user.home_project, with_kiwi_file: true)
  end

  before do
    login user
  end

  describe 'GET #index' do
    subject { get :index, params: { kiwi_image_id: kiwi_image_with_package_with_kiwi_file.id } }

    it { expect(subject).to have_http_status(:success) }
    it { expect(subject).to render_template(:index) }
  end

  describe 'GET #edit' do
    subject { get :edit, params: { kiwi_image_id: kiwi_image_with_package_with_kiwi_file.id } }

    it { expect(subject).to have_http_status(:success) }
    it { expect(subject).to render_template(:edit) }
  end

  describe 'POST #update' do
    let(:kiwi_repository) { create(:kiwi_repository, image: kiwi_image_with_package_with_kiwi_file) }

    context 'with invalid repositories data' do
      let(:invalid_repositories_update_params) do
        {
          kiwi_image_id: kiwi_image_with_package_with_kiwi_file.id,
          image:         {
            repositories_attributes: {
              '0' => {
                id:        kiwi_repository.id,
                repo_type: 'apt2-deb'
                }
            }
          }
        }
      end

      subject { post :update, params: invalid_repositories_update_params }

      it do
        expect(subject.request.flash[:error]).to(
          start_with('Cannot update repositories for kiwi image: Repositories[0] repo type is not included in the list')
        )
      end
      it { expect(subject).to redirect_to(root_path) }
    end

    context 'with valid repositories data' do
      let(:update_params) do
        {
          kiwi_image_id: kiwi_image_with_package_with_kiwi_file.id,
          image:         { repositories_attributes: { '0' => {
            id:             kiwi_repository.id,
            repo_type:      'apt-deb',
            priority:       '',
            alias:          '',
            source_path:    'http://',
            username:       '',
            password:       '',
            prefer_license: 0,
            imageinclude:   0,
            replaceable:    0
          }}}
        }
      end

      before do
        post :update, params: update_params
      end

      it { expect(response).to redirect_to(action: :index) }
      it { expect(flash[:error]).to be_nil }
    end
  end
end
