require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::Kiwi::RepositoriesController, type: :controller, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { create(:project, name: 'fake_project') }
  let(:kiwi_image) { create(:kiwi_image) }
  let(:package_with_kiwi_file) { create(:package_with_kiwi_file, name: 'fake_package', project: project, kiwi_image: kiwi_image) }

  before do
    login user
  end

  describe 'GET #index' do
    subject { get :index, params: { kiwi_image_id: package_with_kiwi_file.kiwi_image_id } }

    it { expect(subject).to have_http_status(:success) }
    it { expect(subject).to render_template(:index) }
  end

  describe 'GET #edit' do
    subject { get :edit, params: { kiwi_image_id: package_with_kiwi_file.kiwi_image_id } }

    it { expect(subject).to have_http_status(:success) }
    it { expect(subject).to render_template(:edit) }
  end

  describe 'POST #update' do
    context 'with invalid repositories data' do
      subject { post :update, params: { kiwi_image_id: package_with_kiwi_file.kiwi_image_id } }

      it { expect(subject).to have_http_status(:redirect) }
      it do
        expect(subject.request.flash[:error]).to eq('Cannot update repositories for kiwi image:  param is missing or the value is empty: image')
      end
      it { expect(subject).to redirect_to(root_path) }
    end

    context 'with valid repositories data' do
      include_context 'a kiwi image xml'

      let(:package_with_kiwi_file) do
        create(:package_with_kiwi_file,
               name: 'package_with_kiwi_file', project: user.home_project, kiwi_image_id: kiwi_image.id, kiwi_file_content: kiwi_xml)
      end
      let(:kiwi_repository) { create(:kiwi_repository, image: kiwi_image) }
      let(:update_params) do
        {
          kiwi_image_id: package_with_kiwi_file.kiwi_image_id,
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
        allow_any_instance_of(Package).to receive(:kiwi_image_outdated?) { false }
        post :update, params: update_params
      end

      it { expect(response).to have_http_status(:redirect) }
      it { expect(response).to redirect_to(action: :index) }
      it { expect(flash[:error]).to be_nil }
    end
  end
end
