require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::Kiwi::ImagesController, type: :controller, vcr: true do
  let(:project) { create(:project, name: 'fake_project') }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:kiwi_image_with_package_with_kiwi_file) do
    create(:kiwi_image_with_package, name: 'package_with_valid_kiwi_file', project: user.home_project, with_kiwi_file: true)
  end

  describe 'GET #import_from_package' do
    context 'without a kiwi file' do
      let(:package) { create(:package, name: 'package_without_kiwi_file', project: project) }

      before do
        get :import_from_package, params: { package_id: package.id }
      end

      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).to eq('There is no KIWI file') }
    end

    context 'with a kiwi file' do
      context 'that is a valid kiwi file' do
        let(:kiwi_image) do
          create(:kiwi_image_with_package, name: 'package_with_valid_kiwi_file', project: project, with_kiwi_file: true)
        end

        before do
          get :import_from_package, params: { package_id: kiwi_image.package.id }
        end

        it { expect(response).to redirect_to(kiwi_image_path(kiwi_image)) }
      end

      context 'that is an invalid kiwi file' do
        include_context 'an invalid kiwi image xml'

        let(:package_with_kiwi_file) do
          create(:package_with_kiwi_file, name: 'package_with_invalid_kiwi_file', project: project, kiwi_file_content: invalid_kiwi_xml)
        end

        before do
          get :import_from_package, params: { package_id: package_with_kiwi_file.id }
        end

        it { expect(response).to redirect_to(root_path) }
        it { expect(flash[:error]).not_to be_nil }
      end
    end
  end

  describe 'GET #show' do
    before do
      login user
    end

    context "json" do
      subject { get :show, params: { format: :json, id: kiwi_image_with_package_with_kiwi_file.id } }

      it { expect(subject.content_type).to eq("application/json") }
      it { expect(subject).to have_http_status(:success) }
    end

    context "html" do
      subject { get :show, params: { id: kiwi_image_with_package_with_kiwi_file.id } }

      it { expect(subject).to have_http_status(:success) }
      it { expect(subject).to render_template(:show) }
    end
  end

  describe 'GET #edit' do
    subject { get :edit, params: { id: kiwi_image_with_package_with_kiwi_file.id } }

    it { expect(subject).to have_http_status(:success) }
    it { expect(subject).to render_template(:edit) }
  end

  describe 'POST #update' do
    let(:kiwi_repository) { create(:kiwi_repository, image: kiwi_image_with_package_with_kiwi_file) }

    before do
      login user
    end

    context 'with invalid repositories data' do
      let(:invalid_repositories_update_params) do
        {
          id:         kiwi_image_with_package_with_kiwi_file.id,
          kiwi_image: {
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
          start_with('Cannot update kiwi image: Repositories[0] repo type is not included in the list')
        )
      end
      it { expect(subject).to redirect_to(root_path) }
    end

    context 'with valid repositories data' do
      let(:update_params) do
        {
          id:         kiwi_image_with_package_with_kiwi_file.id,
          kiwi_image: { repositories_attributes: { '0' => {
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

      it { expect(response).to redirect_to(action: :show) }
      it { expect(flash[:error]).to be_nil }
    end
  end
end
